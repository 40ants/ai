;;;; Independent archived-evidence assertions; never grade assistant prose as execution.
(uiop:define-package #:40ants-ai-evals-skill-behavior-checks/checks
  (:use #:cl)
  (:import-from #:cl-ppcre)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:40ants-ai-evals/util
                #:field #:sequence-list #:true-p #:json-equal-p #:encode #:decode
                #:root #:at #:safe-relative-p #:write-text #:temporary-directory
                #:remove-directory #:run-command)
  (:import-from #:40ants-ai-evals/checks
                #:register-check #:context-sample #:outcome #:cached))
(in-package #:40ants-ai-evals-skill-behavior-checks/checks)

(-> exact-file (hash-table hash-table)
    hash-table)
(defun exact-file (context params)
  (outcome "exact-file"
           (equal (field params "text")
                  (field (context-sample context) "files" (field params "file")))))

(-> successful-call-p (hash-table)
    boolean)
(defun successful-call-p (call)
  (true-p (field call "success")))

(-> command-text (hash-table)
    string)
(defun command-text (call)
  (let ((arguments (field call "arguments")))
    (or (field arguments "command") (field arguments "cmd")
        (field arguments "code") (field arguments "form")
        (field arguments "lisp_form") (encode arguments))))

(-> result-text (hash-table)
    string)
(defun result-text (call)
  (let ((result (field call "result")))
    (if (stringp result) result (encode result))))

(-> trace-check (hash-table hash-table)
    hash-table)
(defun trace-check (context params)
  ;; Every requirement must match an actual completed invocation. The final
  ;; matching invocation is inspected, so an early successful run cannot hide
  ;; a later failed rerun after edits.
  (let ((calls (sequence-list (field (context-sample context) "toolCalls"))))
    (outcome "completed-tool-invocations"
     (and calls
          (every
           (lambda (requirement)
             (let* ((matches (remove-if-not
                              (lambda (call)
                                (cl-ppcre:scan (field requirement "pattern")
                                               (command-text call))) calls))
                    (last (car (last matches)))
                    (minimum (or (field requirement "minimum") 1))
                    (output (field requirement "output"))
                    (forbidden (field requirement "forbiddenOutput"))
                    (forbidden-command (field requirement "forbiddenCommand")))
               (and (>= (length matches) minimum) last (successful-call-p last)
                    (or (not forbidden-command)
                        (notany (lambda (call)
                                  (cl-ppcre:scan forbidden-command (command-text call))) matches))
                    (or (not output) (cl-ppcre:scan output (result-text last)))
                    (or (not forbidden)
                        (not (cl-ppcre:scan forbidden (result-text last)))))))
           (sequence-list (field params "requirements")))))))

(defvar *runtime-helpers*)

(-> runtime-check (hash-table hash-table)
    hash-table)
(defun runtime-check (context params)
  ;; Candidate files and dependency resolution are replayed from the archive in
  ;; a fresh process. No access to the provider's ephemeral workspace is needed.
  (let ((result
          (cached context (list :behavior-runtime (encode params))
           (lambda ()
             (let ((scratch (temporary-directory "skill-runtime")))
               (unwind-protect
                    (progn
                      (maphash (lambda (path text)
                                 (when (and (safe-relative-p path) (stringp text))
                                   (write-text (at scratch path) text)))
                               (field (context-sample context) "files"))
                      (let ((script (at scratch ".behavior-check.lisp")))
                        (write-text script
                         (format nil
                          "(require :asdf)~%(load ~S :verbose nil :print nil)~%(asdf:load-system :serapeum)~%(asdf:initialize-source-registry '(:source-registry (:tree ~S) :inherit-configuration))~%~{(asdf:load-system ~S)~%~}~{(load ~S :verbose nil :print nil)~%~}~A~%~A~%(format t ~S)~%"
                          (namestring (at (or (uiop:getenv "SKILL_EVAL_DEPENDENCY_ROOT")
                                              (root)) ".qlot/setup.lisp"))
                          (namestring scratch)
                          (sequence-list (field params "systems"))
                          (sequence-list (field params "loadFiles"))
                          *runtime-helpers* (field params "assertions")
                          "SKILL_RUNTIME_OK"))
                        (multiple-value-bind (stdout stderr status)
                            (run-command (list "env"
                                               (format nil "XDG_CACHE_HOME=~A"
                                                       (or (uiop:getenv "XDG_CACHE_HOME")
                                                           (at scratch ".cache/")))
                                               "ros" "-Q" "run" "--" "--script"
                                               (namestring script))
                                         :directory scratch :timeout 60 :allow-failure t)
                          (dict "pass" (and (zerop status)
                                             (not (null (search "SKILL_RUNTIME_OK" stdout))))
                                "reason" (if (zerop status) stdout stderr)))))
                 (remove-directory scratch)))))))
    (outcome "archived-lisp-runtime" (field result "pass")
             :reason (field result "reason"))))

(defparameter *runtime-helpers*
  "(defun op-p (form name)
     (and (consp form) (symbolp (first form))
          (string-equal (symbol-name (first form)) name)))
   (defun nodes (tree)
     (cons tree (when (consp tree) (mapcan #'nodes tree))))
   (defun forms (path)
     (let ((*read-eval* nil) (*package* (find-package :cl-user)))
       (with-open-file (stream path)
         (loop for form = (read stream nil :eof) until (eq form :eof)
               collect form
               do (when (op-p form \"in-package\")
                    (setf *package* (find-package (second form))))))))
   (defun definition (path operator name)
     (find-if (lambda (form)
                (and (op-p form operator)
                     (symbolp (second form))
                     (string-equal (symbol-name (second form)) name)))
              (forms path)))")

(-> evidence-object (hash-table string)
    t)
(defun evidence-object (context file)
  ;; These files are written by the fixture supervisor during collection and
  ;; archived alongside source; model-written reports are never consulted.
  (let ((text (field (context-sample context) "files" file)))
    (when (stringp text)
      (handler-case (decode text) (error () nil)))))

(-> cache-check (hash-table hash-table)
    hash-table)
(defun cache-check (context params)
  (let* ((data (evidence-object context ".eval-evidence/cache.json"))
         (before (field data "before")) (after (field data "after"))
         (projects (sequence-list (field data "projectPaths")))
         (foreign (sequence-list (field data "foreignPaths"))))
    (outcome "project-cache-only"
     (and (hash-table-p before) (hash-table-p after) projects foreign
          (if (true-p (field params "missing"))
              (and (json-equal-p before after)
                   (every (lambda (path) (and (not (field before path))
                                             (not (field after path)))) projects))
              (every (lambda (path) (and (field before path) (not (field after path)))) projects))
          (every (lambda (path) (and (field before path)
                                    (equal (field before path) (field after path)))) foreign)))))

(-> result-state (t &optional integer)
    t)
(defun result-state (value &optional (depth 0))
  "Decode only native tool result envelopes, never model-written files."
  (when (< depth 10)
    (cond
      ((stringp value)
       (handler-case (result-state (decode value) (1+ depth)) (error () nil)))
      ((hash-table-p value)
       (or (let ((state (field value "state"))) (when (hash-table-p state) state))
           (loop for key in '("content" "structuredContent" "result" "output" "text")
                 thereis (result-state (field value key) (1+ depth)))))
      ((and (vectorp value) (not (stringp value)))
       (loop for item across value thereis (result-state item (1+ depth)))))))

(-> last-fixture-call (hash-table string)
    t)
(defun last-fixture-call (context pattern)
  (find-if (lambda (call) (cl-ppcre:scan pattern (or (field call "name") "")))
           (reverse (sequence-list (field (context-sample context) "toolCalls")))))

(-> repl-check (hash-table hash-table)
    hash-table)
(defun repl-check (context params)
  (let* ((last (last-fixture-call context "(?i)eval[-_]lisp[-_]form"))
         (data (and last (result-state (field last "result"))))
         (expected (field params "expected")))
    (outcome "persistent-repl-state"
     (and last (successful-call-p last) (hash-table-p data)
          (loop for key being the hash-keys of expected
                always (json-equal-p (gethash key expected) (field data key)))))))

(-> object-subset-p (t t)
    boolean)
(defun object-subset-p (expected observed)
  (if (hash-table-p expected)
      (and (hash-table-p observed)
           (loop for key being the hash-keys of expected
                 always (multiple-value-bind (value present-p) (gethash key observed)
                          (and present-p (object-subset-p (gethash key expected) value)))))
      (json-equal-p expected observed)))

(-> deploy-check (hash-table hash-table)
    hash-table)
(defun deploy-check (context params)
  (let* ((last (last-fixture-call context "(?i)remote[-_]shell"))
         (data (and last (result-state (field last "result"))))
         (events (sequence-list (field data "events")))
         (before (field data "protectedBefore")) (after (field data "protectedAfter"))
         (current (field data "current"))
         (releases (mapcar (lambda (revision)
                             (if (uiop:string-prefix-p "releases/" revision) revision
                                 (concatenate 'string "releases/" revision)))
                           (sequence-list (field data "releases"))))
         (required (sequence-list (field params "operations"))))
    (outcome "isolated-deployment-state"
     (and last (successful-call-p last) data
          (hash-table-p before) (plusp (hash-table-count before))
          (object-subset-p before after)
          (object-subset-p (field params "expected") data)
          (stringp current) (member current releases :test #'equal)
          (cl-ppcre:scan "^releases/[0-9]{8}-[0-9]{6}$" current)
          (or (not (true-p (field params "changed")))
              (and (nth-value 1 (gethash "initialCurrent" data))
                   (not (equal current (field data "initialCurrent")))))
          (or (eq :null (field params "target")) (equal current (field params "target")))
          (<= (length releases) (field params "maxReleases"))
          (let ((remaining events))
            (every (lambda (operation)
                     (let ((tail (member-if
                                  (lambda (event)
                                    (and (equal operation (field event "operation"))
                                         (true-p (field event "success")))) remaining)))
                       (when tail (setf remaining (cdr tail)) t))) required))
          (notany (lambda (event)
                    (member (field event "operation")
                            '("non-atomic-switch" "secret-read" "host-access"
                              "remove-active" "root-caddy-validate") :test #'equal)) events)))))

(-> browser-check (hash-table hash-table)
    hash-table)
(defun browser-check (context params)
  (let* ((sample (context-sample context)) (artifacts (field sample "artifacts"))
         (files (field sample "files"))
         (paths (sequence-list (field params "pages"))))
    (outcome "rendered-browser-artifacts"
     (and (stringp (field files "shell.nix"))
          (stringp (field files "run_smoke_test.sh"))
          (stringp (field files "smoke_test.py"))
          paths (hash-table-p artifacts)
          (or (eq :null (field params "shellMarker"))
              (search (field params "shellMarker") (field files "shell.nix")))
          (or (not (true-p (field params "http")))
              (and (search "http://" (field files "smoke_test.py"))
                   (search "HTTP fixture loaded" (field files "smoke_test.py"))))
          (every
           (lambda (page)
             (let ((shots
                     (loop for path being the hash-keys of artifacts
                           for meta = (field artifacts path)
                           when (and (uiop:string-prefix-p "test-shots/" path)
                                     (search page path)
                                     (equal "png" (field meta "kind"))
                                     (stringp (field meta "sha256"))
                                     (= 64 (length (field meta "sha256")))
                                     (integerp (field meta "size"))
                                     (> (field meta "size") 1000)
                                     (integerp (field meta "width"))
                                     (integerp (field meta "height"))
                                     (> (field meta "height") 300))
                             collect meta)))
               (and (some (lambda (meta) (>= (field meta "width") 1000)) shots)
                    (some (lambda (meta) (<= 300 (field meta "width") 500)) shots)))) paths)))))

(-> browser-missing-check (hash-table hash-table)
    hash-table)
(defun browser-missing-check (context params)
  (let* ((sample (context-sample context))
         (calls (sequence-list (field sample "toolCalls")))
         (launches (remove-if-not
                    (lambda (call)
                      (cl-ppcre:scan "(?m)(?:^|[;&\\n]\\s*)(?:env\\s+)?(?:[A-Za-z_][A-Za-z0-9_]*=(?:\"[^\"]*\"|'[^']*'|[^\\s]+)\\s+)*(?:(?:bash|sh)\\s+)?(?:\\./|/[^ \\n]+/)?run_smoke_test[.]sh(?:\\s|$)"
                                     (command-text call))) calls))
         (last (car (last launches)))
         (report (field sample "files" (field params "report")))
         (artifacts (field sample "artifacts")))
    (outcome "actual-missing-browser-diagnostic"
     (and last (not (successful-call-p last))
          (cl-ppcre:scan "(?is)(?:executable|browser).*(?:doesn't exist|does not exist|not found|ENOENT|missing)"
                         (result-text last))
          (stringp report) (> (length report) 80)
          (search "PLAYWRIGHT_BROWSER_PATH" report)
          (notany (lambda (call)
                    (cl-ppcre:scan "(?im)(?:^|[;&|]\\s*)(?:python3?\\s+-m\\s+)?playwright\\s+install(?:\\s|$)"
                                   (command-text call))) calls)
          (or (not (hash-table-p artifacts))
              (loop for path being the hash-keys of artifacts
                    never (and (uiop:string-prefix-p "test-shots/" path)
                               (equal "png" (field artifacts path "kind")))))))))

(register-check "skill/exact-file" 'exact-file
                :parameters (dict "file" "string" "text" "string"))
(register-check "skill/tool-trace" 'trace-check :parameters (dict "requirements" "array"))
(register-check "skill/lisp-runtime" 'runtime-check
                :parameters (dict "loadFiles" "array" "systems" "array" "assertions" "string")
                :defaults (dict "loadFiles" #() "systems" #()))
(register-check "skill/cache-state" 'cache-check
                :parameters (dict "missing" "boolean")
                :defaults (dict "missing" 'yason:false))
(register-check "skill/repl-state" 'repl-check :parameters (dict "expected" "object"))
(register-check "skill/deploy-state" 'deploy-check
                :parameters (dict "target" "nullable-string" "maxReleases" "integer"
                                  "operations" "array" "changed" "boolean" "expected" "object")
                :defaults (dict "target" :null "maxReleases" 3 "operations" #()
                                "changed" 'yason:false "expected" (dict)))
(register-check "skill/browser-artifacts" 'browser-check
                :parameters (dict "pages" "array" "http" "boolean" "shellMarker" "nullable-string")
                :defaults (dict "http" 'yason:false "shellMarker" :null))
(register-check "skill/browser-missing" 'browser-missing-check
                :parameters (dict "report" "string"))
