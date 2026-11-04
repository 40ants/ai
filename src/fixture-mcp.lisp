;;;; MCP fixtures for live Lisp, virtual deployment, and bounded local browser tests.
(uiop:define-package #:40ants-ai-evals/fixture-mcp
  (:use #:cl)
  (:import-from #:serapeum #:dict #:->)
  (:import-from #:40ants-ai-evals/util
                #:field #:at #:decode #:encode #:write-json #:read-json
                #:write-text #:digest-file #:bool #:now #:sequence-list)
  (:export #:main #:initialize-fixture #:dispatch #:evaluate-form #:remote-operation #:run-browser-smoke
))
(in-package #:40ants-ai-evals/fixture-mcp)

(defvar *workspace* nil "Actual copied sample directory for this MCP connection.")
(defvar *fixture* nil "Configuration loaded when this MCP connection starts.")
(defvar *deploy* nil)
(defvar *events* nil)
(defvar *repl-value* nil)
(defvar *deadline-expired* nil)
(defvar *observing-deadline* nil)
(defvar *original-package* nil)
(defvar *browser-smoke-timeout* 60 "Fixed browser runner deadline; bound shorter only by offline tests.")

(-> journal (hash-table)
    hash-table)
(defun journal (event)
  "Append a completed operation to the copied sample's own evidence."
  (setf (gethash "timestamp" event) (now))
  (let ((file (at *workspace* ".eval-evidence/journal.jsonl")))
    (ensure-directories-exist file)
    (with-open-file (out file :direction :output :if-exists :append
                             :if-does-not-exist :create :external-format :utf-8)
      (write-line (encode event) out)))
  event)

(-> deploy-snapshot ()
    hash-table)
(defun deploy-snapshot ()
  (let ((snapshot (dict "initialCurrent" (field *deploy* "initialCurrent")
                        "current" (field *deploy* "current")
                        "releases" (field *deploy* "releases")
                        "protectedBefore" (field *deploy* "protectedBefore")
                        "protectedAfter" (field *deploy* "protectedAfter")
                        "unit" (field *deploy* "unit")
                        "serviceExists" (field *deploy* "serviceExists")
                        "serviceUser" (field *deploy* "serviceUser")
                        "dataMode" (field *deploy* "dataMode")
                        "envMode" (field *deploy* "envMode")
                        "envOwner" (field *deploy* "envOwner")
                        "dataOwner" (field *deploy* "dataOwner")
                        "caddyRoot" (field *deploy* "caddyRoot")
                        "upstream" (field *deploy* "upstream")
                        "caddyValidated" (field *deploy* "caddyValidated")
                        "caddyReloaded" (field *deploy* "caddyReloaded")
                        "events" (coerce (reverse *events*) 'vector))))
    (write-json (at *workspace* ".eval-evidence/deploy.json") snapshot)
    snapshot))

(-> repl-snapshot ()
    hash-table)
(defun repl-snapshot ()
  "Capture supervised live state; bound calls into candidate function definitions."
  (let* ((state (find-package "DEMO/STATE"))
         (counter (when state (find-symbol "*COUNTER*" state)))
         (package (find-package "DEMO/SRC/COUNTER"))
         (value-symbol (when package (find-symbol "VALUE" package)))
         (value (if (and value-symbol (fboundp value-symbol))
                    (handler-case (sb-ext:with-timeout 1 (funcall value-symbol))
                      (sb-ext:timeout () :snapshot-timeout)
                      (error () :snapshot-error))
                    *repl-value*))
         (snapshot
           (dict "counter" (if (and counter (boundp counter)) (symbol-value counter) :null)
                 "value" (if (typep value '(or null number string)) value
                             (if (symbolp value) (symbol-name value) "<non-scalar>"))
                 "deadlineExpired" (bool *deadline-expired*)
                 "packageRecreated" (bool (and *original-package* package
                                                (not (eq package *original-package*)))))))
    (write-json (at *workspace* ".eval-evidence/repl.json") snapshot)
    snapshot))

(-> observe-deadline-signals ()
    t)
(defun observe-deadline-signals ()
  "Record real SBCL deadline signals even when candidate handlers recover."
  (unless (sb-int:encapsulated-p 'sb-sys:signal-deadline 'eval-deadline-observer)
    (sb-int:encapsulate
     'sb-sys:signal-deadline 'eval-deadline-observer
     (lambda (original &rest arguments)
       (when *observing-deadline* (setf *deadline-expired* t))
       (apply original arguments)))))

(-> initialize-fixture (&optional t)
    hash-table)
(defun initialize-fixture (&optional (workspace (uiop:getcwd)))
  "Initialize once per MCP connection, always from its actual copied workspace."
  (setf *workspace* (uiop:ensure-directory-pathname workspace)
        *fixture* (read-json (at *workspace* ".eval-fixture.json"))
        *events* nil *deploy* nil *repl-value* nil *deadline-expired* nil
        *original-package* nil)
  (setf *default-pathname-defaults* *workspace*)
  (if (fboundp 'cl-user::skill-eval-initialize-output-translations)
      (funcall (symbol-function 'cl-user::skill-eval-initialize-output-translations) *workspace*)
      (asdf:initialize-output-translations
       `(:output-translations (t (,(at *workspace* ".eval-cache/common-lisp/") :implementation))
         :ignore-inherited-configuration)))
  (pushnew *workspace* asdf:*central-registry* :test #'equal)
  (cond
    ((equal (field *fixture* "profile") "repl")
     (observe-deadline-signals)
     (unless (find-package "DEMO/STATE")
       (make-package "DEMO/STATE" :use '("CL")))
     (let ((*package* (find-package "DEMO/STATE")))
       (eval (read-from-string "(progn (defparameter *counter* 41) (defun read-counter () *counter*) (defun inc-counter () (incf *counter*)) (export '(*counter* read-counter inc-counter)))")))
     ;; A real package-inferred fixture can be force-reloaded in this same image.
     (let ((system (at *workspace* "demo.asd")))
       (when (probe-file system)
         (asdf:load-asd system)
         (asdf:load-system "demo")))
     (setf *original-package* (find-package "DEMO/SRC/COUNTER"))
     (repl-snapshot))
    ((equal (field *fixture* "profile") "deploy")
     (let ((protected (dict "config/service.env" "fixture-secret-sha256"
                            "data/state.sqlite" "fixture-data-sha256"
                            "certificateState" "fixture-certificate-sha256")))
       (setf *deploy*
             (dict "current" "releases/20261030-100000"
                   "releases" (vector "20261028-100000" "20261029-100000" "20261030-100000")
                   "protectedBefore" protected "protectedAfter" (copy-hash-table* protected)
                   "built" (bool nil) "running" (bool t) "unitDirty" (bool nil)
                   "serviceExists" (bool t) "serviceUser" "demo" "dataMode" "0700" "envMode" "0600"
                   "envOwner" "root:root" "dataOwner" "demo:demo"
                   "caddyRoot" "/srv/services/demo/current/public" "upstream" "127.0.0.1:8081"
                   "caddyValidated" (bool nil) "caddyReloaded" (bool nil)
                   "unit" (dict "ProtectHome" "read-only" "ProtectSystem" "strict"
                                "PrivateTmp" "true" "NoNewPrivileges" "true"
                                "ReadWritePaths" "/srv/services/demo/data"))))
     (when (equal (field *fixture* "scenario" "name") "heldout-cleanup")
       (setf (gethash "current" *deploy*) "releases/20261028-100000"
             (gethash "releases" *deploy*)
             (vector "20261028-100000" "20261029-100000" "20261030-100000"
                     "20261031-100000" "20261101-100000")))
     (when (equal (field *fixture* "scenario" "name") "heldout-config-changes")
       (setf (gethash "ProtectHome" (field *deploy* "unit")) "true"
             (gethash "ReadWritePaths" (field *deploy* "unit")) "/home/art/projects/demo"
             (gethash "caddyRoot" *deploy*) "/home/art/projects/demo/public"
             (gethash "upstream" *deploy*) "127.0.0.1:8080"))
     (when (equal (field *fixture* "scenario" "name") "first-service")
       (let ((protected (dict "certificateState" "fixture-certificate-sha256")))
         (setf (gethash "serviceExists" *deploy*) (bool nil)
               (gethash "current" *deploy*) nil (gethash "releases" *deploy*) #()
               (gethash "running" *deploy*) (bool nil)
               (gethash "protectedBefore" *deploy*) protected
               (gethash "protectedAfter" *deploy*) (copy-hash-table* protected))))
     (setf (gethash "initialCurrent" *deploy*) (field *deploy* "current"))
     (deploy-snapshot)))
  (journal (dict "type" "initialize" "profile" (field *fixture* "profile")))
  *fixture*)

(-> copy-hash-table* (hash-table)
    hash-table)
(defun copy-hash-table* (table)
  (let ((copy (make-hash-table :test (hash-table-test table))))
    (maphash (lambda (key value) (setf (gethash key copy) value)) table)
    copy))

(-> evaluate-form (t)
    (values hash-table boolean &optional))
(defun evaluate-form (arguments)
  "Evaluate forms in this persistent image with deadline and hard timeout guards."
  (let* ((text (or (field arguments "form") (field arguments "code")))
         (seconds (or (field arguments "deadline_seconds") 10))
         (stdout (make-string-output-stream))
         (values nil) (failure nil) (timed-out nil))
    (unless (stringp text) (error "form must be a Lisp string"))
    (unless (and (realp seconds) (< 0 seconds) (<= seconds 20))
      (error "deadline_seconds must be greater than zero and at most 20"))
    (handler-case
        (let ((*standard-output* stdout) (*error-output* stdout)
              (*trace-output* stdout) (*package* (find-package "CL-USER"))
              (*read-eval* nil) (*observing-deadline* t))
          ;; SB-SYS deadline propagates through blocking I/O; WITH-TIMEOUT also
          ;; interrupts CPU loops which never enter an SBCL deadline safe point.
          (sb-ext:with-timeout seconds
            (sb-sys:with-deadline (:seconds seconds)
              (handler-bind ((sb-sys:deadline-timeout (lambda (condition)
                                                       (declare (ignore condition))
                                                       (setf *deadline-expired* t))))
                (with-input-from-string (in text)
                  (loop for form = (read in nil in)
                        until (eq form in)
                        do (setf values (multiple-value-list (eval form))))))))
          (setf *repl-value* (first values)))
      (sb-sys:deadline-timeout (condition)
        (setf *deadline-expired* t timed-out t failure (princ-to-string condition)))
      (sb-ext:timeout (condition)
        (setf *deadline-expired* t timed-out t failure (princ-to-string condition)))
      (error (condition) (setf failure (princ-to-string condition))))
    (let ((result (dict "values" (map 'vector #'prin1-to-string values)
                        "stdout" (get-output-stream-string stdout)
                        "error" (or failure :null)
                        "deadlineExpired" (bool *deadline-expired*)
                        "timedOut" (bool timed-out))))
      (journal (dict "type" "eval_lisp_form" "form" text "result" result))
      (repl-snapshot)
      (values result (not (null failure))))))

(defun valid-revision-p (revision)
  (and (stringp revision) (= (length revision) 15)
       (char= #\- (char revision 8))
       (loop for char across revision for index from 0
             always (or (= index 8) (digit-char-p char)))))

(defun required-revision (args)
  (let ((revision (or (field args "revision") (field args "release"))))
    (when (and (stringp revision) (uiop:string-prefix-p "releases/" revision))
      (setf revision (subseq revision 9)))
    (unless (valid-revision-p revision) (error "revision must be YYYYMMDD-HHMMSS"))
    revision))

(defun command-operation (command)
  "Recognize a small command vocabulary without invoking any shell interpreter."
  (unless (stringp command) (error "Provide operation or a modeled command"))
  (let ((words (remove "" (uiop:split-string command :separator '(#\Space #\Tab)) :test #'equal)))
    (when (equal (first words) "sudo") (setf words (rest words)))
    (cond
      ((or (equal words '("pwd")) (equal words '("ls"))
           (equal words '("readlink" "/srv/services/demo/current")))
       (dict "operation" "inspect"))
      ((or (equal words '("systemctl" "restart" "demo"))
           (equal words '("systemctl" "restart" "demo.service")))
       (dict "operation" "restart"))
      ((equal words '("systemctl" "daemon-reload")) (dict "operation" "daemon-reload"))
      ((or (equal words '("systemctl" "is-active" "demo"))
           (equal words '("curl" "-fsS" "http://127.0.0.1:8081/")))
       (dict "operation" "health"))
      ((equal words '("qlot" "exec" "ros" "run" "--" "--non-interactive" "--load" "build.lisp"))
       (dict "operation" "build"))
      (t (error "Command is outside this virtual host's modeled vocabulary; use structured operation fields.")))))

(-> remote-operation (t)
    (values t boolean &optional))
(defun remote-operation (arguments)
  "Advance only the virtual deployment model. Never calls ssh/sudo/systemctl."
  (unless *deploy* (error "Virtual deploy fixture is not active"))
  (let* ((args (if (field arguments "operation") arguments
                   (command-operation (field arguments "command"))))
         (operation (field args "operation"))
         (event (dict "operation" operation "arguments" args "success" (bool nil)))
         (result nil) (failure nil))
    (handler-case
        (setf result
              (cond
                ((equal operation "inspect") (copy-hash-table* *deploy*))
                ((member operation '("create-service" "configure-service") :test #'equal)
                 (unless (and (equal (field args "serviceUser") "demo")
                              (equal (field args "dataMode") "0700")
                              (equal (field args "envMode") "0600")
                              (eq (field args "noRealSecrets") 'yason:true))
                   (error "Require serviceUser=demo, dataMode=0700, envMode=0600, noRealSecrets=true"))
                 (setf (gethash "serviceExists" *deploy*) (bool t)
                       (gethash "serviceUser" *deploy*) "demo"
                       (gethash "dataMode" *deploy*) "0700"
                       (gethash "envMode" *deploy*) "0600"
                       (gethash "envOwner" *deploy*) "root:root"
                       (gethash "dataOwner" *deploy*) "demo:demo"
                       (gethash "config/service.env" (field *deploy* "protectedAfter")) "fixture-secret-sha256"
                       (gethash "data/state.sqlite" (field *deploy* "protectedAfter")) "fixture-data-sha256")
                 (dict "created" (bool t)))
                ((equal operation "build")
                 (setf (gethash "built" *deploy*) (bool t))
                 (dict "binary" "bin/demo" "bundledLibraries" (vector "bin/libdemo.so")))
                ((equal operation "install-release")
                 (unless (eq (field *deploy* "serviceExists") 'yason:true) (error "Create the service first"))
                 (unless (eq (field *deploy* "built") 'yason:true) (error "Build before installing a release"))
                 (let ((revision (required-revision args)))
                   (when (find revision (field *deploy* "releases") :test #'equal)
                     (error "Release is immutable and already exists"))
                   (setf (gethash "releases" *deploy*)
                         (concatenate 'vector (field *deploy* "releases") (vector revision)))
                   (dict "installed" revision "includes" (vector "bin/" "public/" "REVISION"))))
                ((equal operation "switch-current")
                 (let ((revision (required-revision args)))
                   (unless (find revision (field *deploy* "releases") :test #'equal)
                     (error "Cannot activate an uninstalled release"))
                   (unless (eq (field args "atomic") 'yason:true)
                     (error "Switch requires atomic=true (current.tmp plus rename)"))
                   (setf (gethash "current" *deploy*) (concatenate 'string "releases/" revision))
                   (dict "initialCurrent" (field *deploy* "initialCurrent")
                        "current" (field *deploy* "current"))))
                ((equal operation "update-unit")
                 (let* ((unit (or (field args "unit") (dict)))
                        (required (dict "ProtectHome" "read-only" "ProtectSystem" "strict"
                                        "PrivateTmp" "true" "NoNewPrivileges" "true"
                                        "ReadWritePaths" "/srv/services/demo/data")))
                   (maphash (lambda (key value)
                              (unless (equal (field unit key) value)
                                (error "Unit requires ~A=~A" key value))) required)
                   (setf (gethash "unit" *deploy*) unit (gethash "unitDirty" *deploy*) (bool t))
                   (dict "updated" (bool t))))
                ((equal operation "daemon-reload")
                 (setf (gethash "unitDirty" *deploy*) (bool nil)) (dict "reloaded" (bool t)))
                ((equal operation "restart")
                 (unless (and (eq (field *deploy* "serviceExists") 'yason:true)
                              (field *deploy* "current"))
                   (error "Service and active release are required"))
                 (when (eq (field *deploy* "unitDirty") 'yason:true)
                   (error "daemon-reload is required after changing the unit"))
                 (setf (gethash "running" *deploy*) (bool t))
                 (dict "active" (bool t) "NRestarts" 0))
                ((equal operation "health")
                 (unless (eq (field *deploy* "running") 'yason:true) (error "Service is not running"))
                 (dict "active" (field *deploy* "running") "localStatus" 200 "publicStatus" 200 "NRestarts" 0))
                ((equal operation "cleanup")
                 (let* ((keep (or (field args "keep") 3))
                        (current (subseq (field *deploy* "current") 9))
                        (releases (sort (coerce (field *deploy* "releases") 'list) #'string>)))
                   (unless (and (integerp keep) (<= 1 keep 100)) (error "keep must be 1..100"))
                   (let* ((others (remove current releases :test #'equal))
                          (retained (cons current (subseq others 0 (min (1- keep) (length others))))))
                     (setf (gethash "releases" *deploy*) (coerce retained 'vector)))
                   (dict "retained" (field *deploy* "releases"))))
                ((equal operation "update-caddy")
                 (unless (and (equal (field args "root") "/srv/services/demo/current/public")
                              (equal (field args "upstream") "127.0.0.1:8081"))
                   (error "Caddy route must use current/public and upstream 127.0.0.1:8081"))
                 (setf (gethash "caddyRoot" *deploy*) (field args "root")
                       (gethash "upstream" *deploy*) (field args "upstream")
                       (gethash "caddyValidated" *deploy*) (bool nil)
                       (gethash "caddyReloaded" *deploy*) (bool nil))
                 (dict "updated" (bool t)))
                ((equal operation "caddy-reload")
                 (unless (eq (field *deploy* "caddyValidated") 'yason:true)
                   (error "Validate as caddy before reload"))
                 (setf (gethash "caddyReloaded" *deploy*) (bool t))
                 (dict "reloaded" (bool t)))
                ((equal operation "validate-caddy")
                 (unless (equal (field args "user") "caddy") (error "Validate Caddy as user caddy"))
                 (setf (gethash "caddyValidated" *deploy*) (bool t))
                 (dict "valid" (bool t)))
                (t (error "Unmodeled operation: ~A" operation))))
      (error (condition) (setf failure (princ-to-string condition))))
    (setf (gethash "success" event) (bool (null failure))
          (gethash "result" event) (or failure result))
    (push event *events*)
    (journal (dict "type" "remote_shell" "event" event))
    (deploy-snapshot)
    (values (or failure result) (not (null failure)))))

(defun owned-descendant-pids (parent)
  "Inspect process ancestry while the owned runner is alive, before terminating it."
  (let* ((output (uiop:run-program '("/bin/ps" "-axo" "pid=,ppid=")
                                    :output :string :ignore-error-status t))
         (pairs (loop for line in (uiop:split-string output :separator '(#\Newline))
                      for words = (remove "" (uiop:split-string line :separator '(#\Space #\Tab)) :test #'equal)
                      when (= 2 (length words))
                        collect (cons (parse-integer (first words)) (parse-integer (second words)))))
         (frontier (list parent)) (owned nil))
    (loop while frontier
          for pid = (pop frontier)
          do (dolist (pair pairs)
               (when (and (= (cdr pair) pid) (not (member (car pair) owned)))
                 (push (car pair) owned) (push (car pair) frontier))))
    owned))

(defun terminate-browser-runner (process)
  "Kill only the runner's process group and descendants, including browser helpers."
  (when process
    (let* ((pid (uiop:process-info-pid process))
           (descendants (when (uiop:process-alive-p process) (owned-descendant-pids pid))))
      (dolist (child descendants)
        (handler-case (sb-posix:kill child sb-posix:sigkill)
          (sb-posix:syscall-error () nil)))
      (handler-case (sb-posix:kill (- pid) sb-posix:sigkill)
        (sb-posix:syscall-error () nil))
      (when (uiop:process-alive-p process)
        (uiop:terminate-process process :urgent t))
      (uiop:wait-process process))))

(-> run-browser-smoke (t)
    (values hash-table boolean &optional))
(defun run-browser-smoke (arguments)
  "Run only ./run_smoke_test.sh through the prepared browser environment, for at most sixty seconds."
  (unless (and (hash-table-p arguments) (= 1 (hash-table-count arguments))
               (equal (field arguments "command") "./run_smoke_test.sh"))
    (error "Only command=./run_smoke_test.sh is accepted by this browser fixture"))
  (let* ((script (at *workspace* "run_smoke_test.sh"))
         (python (or (uiop:getenv "SKILL_EVAL_PYTHON") (error "Pinned browser Python is unavailable")))
         (shell (or (uiop:getenv "SKILL_EVAL_SHELL") (error "Pinned browser shell is unavailable")))
         (stdout-file (at *workspace* ".eval-evidence/browser.stdout.log"))
         (stderr-file (at *workspace* ".eval-evidence/browser.stderr.log"))
         (process nil) (timed-out nil) (status -1))
    (unless (probe-file script) (error "Generate run_smoke_test.sh in this sample first"))
    (when (sb-posix:s-islnk (sb-posix:stat-mode (sb-posix:lstat (namestring script))))
      (error "The smoke wrapper must be a regular sample file"))
    (ensure-directories-exist stdout-file)
    (unwind-protect
         (progn
           ;; SBCL may already create a child process group; otherwise create
           ;; a session so this runner never shares the harness process group.
           ;; No caller-provided program, arguments, or shell expression is used.
           (setf process (uiop:launch-program
                          (list python "-c"
                                "import os,sys
if os.getpgrp() != os.getpid():
    os.setsid()
os.execv(sys.argv[1], [sys.argv[1], './run_smoke_test.sh'])"
                                shell)
                          :directory *workspace* :input nil
                          :output stdout-file :error-output stderr-file
                          :if-output-exists :supersede :if-error-output-exists :supersede))
           (setf status
                 (handler-case (sb-ext:with-timeout *browser-smoke-timeout* (uiop:wait-process process))
                   (sb-ext:timeout () (setf timed-out t) -1))))
      (terminate-browser-runner process))
    (let* ((state (dict "command" "./run_smoke_test.sh" "exitCode" status "timedOut" (bool timed-out)))
           (result (dict "command" "./run_smoke_test.sh" "exitCode" status "timedOut" (bool timed-out)
                         "stdout" (uiop:read-file-string stdout-file :external-format :utf-8)
                         "stderr" (uiop:read-file-string stderr-file :external-format :utf-8)
                         "state" state)))
      (write-json (at *workspace* ".eval-evidence/browser.json") result)
      (journal (dict "type" "run_browser_smoke" "result" result))
      (values result (or timed-out (not (zerop status)))))))

(-> tool-definition (string string hash-table vector)
    hash-table)
(defun tool-definition (name description properties required)
  (dict "name" name "description" description
        "inputSchema" (dict "type" "object" "properties" properties "required" required)))

(-> tools ()
    vector)
(defun tools ()
  (cond
    ((equal (field *fixture* "profile") "repl")
     (vector (tool-definition "eval_lisp_form" "Evaluate Lisp forms in the connected persistent SBCL image; state survives calls. Every call has a deadline and captures printed output."
                              (dict "form" (dict "type" "string")
                                    "deadline_seconds" (dict "type" "number" "minimum" 0.01 "maximum" 20))
                              (vector "form"))))
    ((equal (field *fixture* "profile") "deploy")
     (vector (tool-definition "remote_shell" "Virtual dev3 host for demo service. No real shell/SSH executes. Use operation: inspect, create-service(serviceUser=demo,dataMode=0700,envMode=0600,noRealSecrets=true), build, install-release(revision), switch-current(revision,atomic=true), update-unit(unit object), daemon-reload, restart, health, cleanup(keep), update-caddy(root,upstream), validate-caddy(user=caddy), caddy-reload. Releases are immutable; config and data are protected."
                              (dict "operation" (dict "type" "string") "command" (dict "type" "string")
                                    "revision" (dict "type" "string") "atomic" (dict "type" "boolean")
                                    "keep" (dict "type" "integer") "unit" (dict "type" "object")
                                    "serviceUser" (dict "type" "string") "dataMode" (dict "type" "string")
                                    "envMode" (dict "type" "string") "noRealSecrets" (dict "type" "boolean")
                                    "root" (dict "type" "string") "upstream" (dict "type" "string")
                                    "user" (dict "type" "string") "host" (dict "type" "string")) #())))
    ((equal (field *fixture* "profile") "playwright")
     (let ((tool (tool-definition "run_browser_smoke"
                                 "Run the generated ./run_smoke_test.sh using the prepared pinned Playwright/Chromium service. This environment owns the browser process separately from the agent sandbox. Captures actual stdout/stderr and exit status, stops the owned tree at sixty seconds, and preserves screenshots in the sample workspace."
                                 (dict "command" (dict "type" "string" "enum" (vector "./run_smoke_test.sh")))
                                 (vector "command"))))
       (setf (gethash "additionalProperties" (gethash "inputSchema" tool)) (bool nil))
       (vector tool)))
    (t #())))

(-> dispatch (t)
    (or null hash-table))
(defun dispatch (request)
  "Handle an MCP JSON-RPC request, returning NIL for notifications."
  (let ((method (field request "method")) (id (field request "id")))
    (unless id (return-from dispatch nil))
    (handler-case
        (dict "jsonrpc" "2.0" "id" id "result"
              (cond
                ((equal method "initialize")
                 (dict "protocolVersion" "2025-11-25" "capabilities" (dict "tools" (dict))
                       "serverInfo" (dict "name" "skill-eval-fixture" "version" "1")))
                ((equal method "ping") (dict))
                ((equal method "tools/list") (dict "tools" (tools)))
                ((equal method "tools/call")
                 (let* ((params (field request "params")) (name (field params "name")))
                   (multiple-value-bind (value failure)
                       (cond
                         ((and (equal name "eval_lisp_form") (equal (field *fixture* "profile") "repl"))
                          (evaluate-form (field params "arguments")))
                         ((and (equal name "remote_shell") (equal (field *fixture* "profile") "deploy"))
                          (remote-operation (field params "arguments")))
                         ((and (equal name "run_browser_smoke") (equal (field *fixture* "profile") "playwright"))
                          (run-browser-smoke (field params "arguments")))
                         (t (error "Unknown tool: ~A" name)))
                     ;; Native provider transcripts preserve this result outside
                     ;; the writable candidate workspace. Graders use this state.
                     (setf value (if (hash-table-p value) (copy-hash-table* value) (dict "error" value)))
                     (setf (gethash "state" value)
                           (cond ((equal (field *fixture* "profile") "repl") (repl-snapshot))
                                 ((equal (field *fixture* "profile") "deploy") (deploy-snapshot))
                                 (t (field value "state"))))
                     (dict "content" (vector (dict "type" "text" "text" (encode value)))
                           "isError" (bool (and failure
                                                (not (and (equal (field *fixture* "profile") "repl")
                                                          (hash-table-p value)
                                                          (eq (field value "timedOut") 'yason:true)))))))))
                (t (error "Unsupported MCP method: ~A" method))))
      (error (condition)
        (dict "jsonrpc" "2.0" "id" id "error"
              (dict "code" -32602 "message" (princ-to-string condition)))))))

(-> main (&rest t)
    t)
(defun main (&rest arguments)
  "Serve one isolated persistent fixture until standard input closes."
  (declare (ignore arguments))
  (let ((protocol-out *standard-output*))
    (let ((*standard-output* *error-output*) (*trace-output* *error-output*))
      (initialize-fixture))
    (loop for line = (read-line *standard-input* nil) while line
          do (handler-case
                 (let* ((*standard-output* *error-output*)
                        (response (dispatch (decode line))))
                   (when response (write-line (encode response) protocol-out) (finish-output protocol-out)))
               (error (condition)
                 (format *error-output* "Fixture protocol error: ~A~%" condition))))))
