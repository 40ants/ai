;;;; Individually registered Common Lisp checks share one isolated reader/runtime call.
(uiop:define-package #:40ants-ai-evals-common-lisp-checks/checks
  (:use #:cl)
  (:import-from #:cl-ppcre)
  (:import-from #:yason)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:40ants-ai-evals/util
                #:field #:true-p #:decode #:sequence-list #:root #:at
                #:temporary-directory #:remove-directory #:write-text #:run-command)
  (:import-from #:40ants-ai-evals/checks
                #:register-check #:register-profile #:cached #:context-sample #:outcome))
(in-package #:40ants-ai-evals-common-lisp-checks/checks)

(-> symbol-text (t)
    t)
(defun symbol-text (node)
  (field node "s"))

(-> form-p (t string)
    boolean)
(defun form-p (node name)
  (and (vectorp node) (not (stringp node)) (plusp (length node))
       (equal (symbol-text (aref node 0)) name)))

(-> element (t integer)
    t)
(defun element (node index)
  (when (and (vectorp node) (not (stringp node)) (< index (length node)))
    (aref node index)))

(-> named-form (list string &optional t)
    t)
(defun named-form (forms operator &optional name)
  (find-if (lambda (form)
             (and (form-p form operator)
                  (or (not name) (equal name (symbol-text (element form 1))))))
           forms))

(-> nodes (t)
    list)
(defun nodes (tree)
  (cons tree (when (and (vectorp tree) (not (stringp tree)))
               (loop for child across tree append (nodes child)))))

(-> evidence (string hash-table)
    hash-table)
(defun evidence (source vars)
  (let ((scratch (temporary-directory "cl-grader")))
    (unwind-protect
         (let* ((candidate (write-text (at scratch "candidate.lisp") source))
                (stdout (run-command
                         (list "ros" "-Q" "--" (namestring (at (root) "roswell/check-lisp.ros"))
                               (namestring candidate) (field vars "package")
                               (field vars "runtime"))
                         :directory scratch :timeout 20))
                (line (find-if (lambda (text) (uiop:string-prefix-p "EVAL_JSON:" text))
                               (uiop:split-string stdout :separator '(#\Newline)))))
           (unless line (error "SBCL grader infrastructure: missing evidence: ~A" stdout))
           (decode (subseq line 10)))
      (remove-directory scratch))))

(-> analysis (hash-table hash-table)
    t)
(defun analysis (context params)
  (let ((source (field (context-sample context) "files" (field params "file"))))
    (when (and (stringp source) (plusp (length source)))
      (cached context (list :lisp-analysis (field params "file") (field params "package")
                            (field params "function") (field params "runtime")
                            (field params "override"))
       (lambda ()
         (let* ((data (evidence source params))
                (forms (sequence-list (field data "forms")))
                (package-form (named-form forms (if (true-p (field params "override"))
                                                    "defpackage" "define-package")))
                (options (cddr (sequence-list package-form))))
           (dict "data" data "forms" forms "package-form" package-form "options" options
                 "all" (nodes (coerce forms 'vector))
                 "exports" (loop for form in options when (form-p form "export")
                                   append (mapcar #'symbol-text (cdr (sequence-list form))))
                 "definition" (named-form forms "defun" (field params "function")))))))))

(defparameter *source-parameters*
  (dict "file" "string" "package" "string" "function" "string" "runtime" "string"
        "override" "boolean" "argument" "nullable-string" "hook" "nullable-string"))

(defmacro define-source-check (name id label &body body)
  ;; Internal convenience macro: BODY sees the shared reader analysis below.
  `(progn
     (serapeum:-> ,name (hash-table hash-table)
         t)
     (defun ,name (context params)
       (let ((analysis (analysis context params)))
         (when analysis
           (let ((data (field analysis "data")) (forms (field analysis "forms"))
                 (package-form (field analysis "package-form"))
                 (options (field analysis "options")) (all (field analysis "all"))
                 (exports (field analysis "exports")) (definition (field analysis "definition")))
             (declare (ignorable data forms package-form options all exports definition))
             (multiple-value-bind (pass reason) (progn ,@body)
               (outcome ,label pass :reason (and (not pass) reason)))))))
     (register-check ,id ',name :parameters *source-parameters*
                     :defaults (dict "override" 'yason:false "argument" :null "hook" :null))))

(define-source-check readable "cl/reader" "lisp-reader"
  (let ((error (field data "readError")))
    (values (eq error :null) (unless (eq error :null) error))))

(define-source-check functional "cl/functional" "functional"
  (let ((error (field data "runtimeError")))
    (values (and (eq :null (field data "readError")) (eq error :null))
            (unless (eq error :null) error))))

(define-source-check package-declaration "cl/package-declaration" "package-declaration"
  package-form)

(define-source-check package-path "cl/full-package-path" "full-package-path"
  (equal (symbol-text (element package-form 1)) (field params "package")))

(define-source-check uninterned-name "cl/uninterned-package-name" "uninterned-package-name"
  (eq :null (field (element package-form 1) "p")))

(define-source-check in-package-form "cl/in-package" "in-package"
  (equal (symbol-text (element (named-form forms "in-package") 1)) (field params "package")))

(define-source-check namespace-hygiene "cl/namespace-hygiene" "namespace-hygiene"
  (let ((uses (remove-if-not (lambda (form) (form-p form "use")) options)))
    (and (= 1 (length uses)) (= 2 (length (first uses)))
         (equal "cl" (symbol-text (element (first uses) 1))))))

(define-source-check public-export "cl/public-export" "public-export"
  (member (field params "function") exports :test #'equal))

(define-source-check public-docstring "cl/public-docstring" "public-docstring"
  (let ((text (element definition 3)))
    (and (stringp text)
         (plusp (length (string-trim '(#\Space #\Tab #\Newline #\Return) text))))))

(define-source-check signature "cl/type-signature"
    (if (true-p (field params "override")) "override:no-signature" "type-signature")
  (let ((signatures (remove-if-not
                     (lambda (form)
                       (and (form-p form "->")
                            (equal (symbol-text (element form 1)) (field params "function"))))
                     forms)))
    (if (true-p (field params "override")) (null signatures) signatures)))

(define-source-check signature-layout "cl/return-type-layout" "return-type-layout"
  (let ((layouts (sequence-list (field data "signatureLayouts"))))
    (and (eq :null (field data "readError")) layouts
         (every (lambda (item) (eql item 1)) layouts))))

(define-source-check no-runtime-eval "cl/no-runtime-eval" "no-runtime-eval-intern-unintern"
  (notany (lambda (node)
            (member (symbol-text node) '("eval" "intern" "unintern") :test #'equal)) all))

(define-source-check loop-style "cl/loop-keyword-style" "loop-keyword-style"
  (let ((clauses '("for" "as" "in" "on" "from" "to" "below" "above" "by" "while" "until"
                   "do" "doing" "collect" "collecting" "sum" "summing" "count" "counting"
                   "append" "nconc" "when" "unless" "if" "else" "finally" "initially" "return"
                   "with" "repeat" "thereis" "always" "never")))
    (every (lambda (form)
             (notany (lambda (node)
                       (and (equal (field node "p") "KEYWORD")
                            (member (symbol-text node) clauses :test #'equal)))
                     (cdr (sequence-list form))))
           (remove-if-not (lambda (node) (form-p node "loop")) all))))

(define-source-check loop-present "cl/loop-present" "loop-present"
  (some (lambda (node) (form-p node "loop")) all))

(define-source-check exhaustive-dispatch "cl/exhaustive-dispatch" "exhaustive-dispatch"
  (some (lambda (node) (or (form-p node "ecase") (form-p node "etypecase"))) all))

(define-source-check ignore-declaration "cl/ignore-declaration" "ignore-declaration"
  (some (lambda (node)
          (and (form-p node "ignore")
               (some (lambda (item) (equal (symbol-text item) (field params "argument")))
                     (cdr (sequence-list node))))) all))

(define-source-check error-format "cl/error-format-arguments" "error-format-arguments"
  (every (lambda (form) (>= (length form) 3))
         (remove-if-not
          (lambda (node) (and (form-p node "error") (stringp (element node 1)))) all)))

(define-source-check formatted-error "cl/formatted-error-present" "formatted-error-present"
  (some (lambda (node)
          (and (form-p node "error") (stringp (element node 1)) (>= (length node) 3))) all))

(define-source-check hook-export "cl/hook-export" "hook-export"
  (member (field params "hook") exports :test #'equal))

(define-source-check hook-docstring "cl/hook-docstring" "hook-docstring"
  (let* ((variable (or (named-form forms "defvar" (field params "hook"))
                       (named-form forms "defparameter" (field params "hook"))))
         (text (element variable 3)))
    (not (null (and (stringp text) (cl-ppcre:scan "(?i)ignor|skip" text)
                    (cl-ppcre:scan "(?i)function|funcall" text))))))

(-> source-spec (string &key (:when t) (:unless t) (:argument t) (:hook t))
    hash-table)
(defun source-spec (id &key when unless argument hook)
  (let* ((params (dict "file" (dict "$var" "file") "package" (dict "$var" "package")
                       "function" (dict "$var" "function") "runtime" (dict "$var" "runtime")
                       "override" (dict "$var" "override" "default" 'yason:false)))
         (spec (dict "check" id "params" params)))
    (when when (setf (gethash "when" spec) when))
    (when unless (setf (gethash "unless" spec) unless))
    (when argument (setf (gethash "argument" params) (dict "$var" argument)))
    (when hook (setf (gethash "hook" params) (dict "$var" hook)))
    spec))

(register-profile "common-lisp/source"
 (vector
  (source-spec "cl/reader")
  (source-spec "cl/functional")
  (source-spec "cl/package-declaration")
  (source-spec "cl/full-package-path")
  (source-spec "cl/uninterned-package-name")
  (source-spec "cl/in-package")
  (source-spec "cl/namespace-hygiene")
  (source-spec "cl/public-export")
  (source-spec "cl/public-docstring")
  (source-spec "cl/type-signature")
  (source-spec "cl/return-type-layout" :unless "override")
  (source-spec "cl/no-runtime-eval")
  (source-spec "cl/loop-keyword-style")
  (source-spec "cl/loop-present" :when "requireLoop")
  (source-spec "cl/exhaustive-dispatch" :when "requireExhaustive")
  (source-spec "cl/ignore-declaration" :when "requireIgnore" :argument "requireIgnore")
  (source-spec "cl/error-format-arguments")
  (source-spec "cl/formatted-error-present" :when "requireFormattedError")
  (source-spec "cl/hook-export" :when "hook" :hook "hook")
  (source-spec "cl/hook-docstring" :when "hook" :hook "hook")))

