;;;; Offline fixture behavior and native provider configuration.
(uiop:define-package #:40ants-ai-evals-tests/environments-test
  (:use #:cl)
  (:import-from #:40ants-ai-evals/case-resources #:resolve-resource)
  (:import-from #:serapeum #:dict)
  (:import-from #:rove #:deftest #:ok #:signals)
  (:import-from #:40ants-ai-evals/util
                #:field #:at #:root #:read-json #:write-text #:temporary-directory
                #:remove-directory #:true-p #:bool #:run-command #:decode #:encode)
  (:import-from #:40ants-ai-evals/environments
                #:prepare #:preflight #:codex-config #:opencode-config #:finalize)
  (:import-from #:40ants-ai-evals/fixture-mcp
                #:initialize-fixture #:evaluate-form #:remote-operation #:dispatch #:run-browser-smoke))
(in-package #:40ants-ai-evals-tests/environments-test)

(defmacro with-fixture ((workspace profile &optional scenario) &body body)
  `(let* ((,workspace (temporary-directory "eval-environment"))
          (*default-pathname-defaults* *default-pathname-defaults*))
     (unwind-protect
          (progn (prepare ,workspace (dict "environmentProfile" ,profile
                                          "scenario" (dict "name" ,scenario)))
                 ,@body)
       (asdf:initialize-output-translations
        `(:output-translations (t (,(at (root) ".eval-cache/common-lisp/") :implementation))
          :ignore-inherited-configuration))
       (remove-directory ,workspace))))

(deftest copyable-profile-and-provider-config
  (with-fixture (workspace "repl" "smoke")
    (let* ((descriptor (read-json (at workspace ".eval-fixture.json")))
           (codex (codex-config descriptor)) (opencode (opencode-config descriptor)))
      (ok (probe-file (at workspace ".eval-environment.json")))
      (ok (equal "ros" (field codex "mcp_servers" "eval_fixture" "command")))
      (ok (null (field codex "mcp_servers" "eval_fixture" "cwd")))
      (ok (equal "." (field opencode "mcp" "eval_fixture" "cwd")))
      (ok (equal "local" (field opencode "mcp" "eval_fixture" "type")))
      (ok (eq 'yason:false (field opencode "mcp" "eval_fixture" "codemode")))
      (ok (= 2 (length (field opencode "mcp" "eval_fixture" "command"))))
      (ok (field descriptor "versions" "quicklisp"))))
  (ok (signals (preflight "invalid-profile" :check-tools nil))))

(deftest pinned-shell-for-ordinary-lisp-fixtures
  (with-fixture (workspace "lisp" "smoke")
    (let* ((descriptor (read-json (at workspace ".eval-fixture.json")))
           (config (opencode-config descriptor)))
      (ok (search "/nix/store/" (field config "shell")))
      (ok (null (field config "mcp")))
      (multiple-value-bind (stdout stderr status)
          (run-command (list (field config "shell") "-lc"
                             "if shopt -q login_shell; then exit 91; fi; test \"$QUICKLISP_HOME\" = \"$SKILL_EVAL_DEPENDENCY_ROOT/.qlot/\" || exit 92; command -v sbcl; sbcl --non-interactive --eval '(format t \"SOURCE=~A~%\" (asdf:system-source-directory :yason))'")
                       :directory workspace :timeout 60 :allow-failure t)
        (ok (zerop status) stderr)
        (ok (uiop:string-prefix-p "/nix/store/" stdout))
        (ok (or (search (namestring (at (root) ".qlot/")) stdout)
                (search (namestring (at (root) ".evals/qlot-cache/")) stdout)))
        (ok (not (search "/Users/art/projects/lisp/yason" stdout)))
        (ok (not (search "/Users/art/quicklisp" stdout)))))))

(deftest cache-independent-final-state
  (with-fixture (workspace "cache" "smoke")
    (let ((file (at workspace ".eval-cache/sbcl-2.6.6-macosx-arm64/project/src/counter.fasl")))
      (delete-file file)
      (finalize workspace :vars (dict "environmentProfile" "cache"))
      (let ((state (read-json (at workspace ".eval-evidence/cache.json"))))
        (ok (= 4 (hash-table-count (field state "before"))))
        (ok (= 3 (hash-table-count (field state "after"))))
        (ok (null (field (field state "after") (namestring file))))
        (loop for foreign across (field state "foreignPaths")
              do (ok (equal (field (field state "before") foreign)
                             (field (field state "after") foreign))))))))

(deftest persistent-repl-deadline-and-independent-connection
  (with-fixture (workspace "repl" "smoke")
    (initialize-fixture workspace)
    (evaluate-form (dict "form" "(demo/state:inc-counter)"))
    (multiple-value-bind (result failed) (evaluate-form (dict "form" "(demo/state:read-counter)"))
      (ok (not failed)) (ok (equal "42" (aref (field result "values") 0))))
    (multiple-value-bind (result failed)
        (evaluate-form (dict "form" "(sb-sys:with-deadline (:seconds 0.01) (sleep 10))"
                             "deadline_seconds" 0.1))
      (ok failed) (ok (true-p (field result "deadlineExpired"))))
    (multiple-value-bind (result failed) (evaluate-form (dict "form" "(demo/state:read-counter)"))
      (ok (not failed)) (ok (equal "42" (aref (field result "values") 0))))
    (ok (= 42 (field (read-json (at workspace ".eval-evidence/repl.json")) "counter")))
    (with-fixture (second "repl" "smoke")
      (initialize-fixture second)
      (ok (= 41 (field (read-json (at second ".eval-evidence/repl.json")) "counter"))))))

(deftest virtual-deploy-invariants-and-cleanup
  (with-fixture (workspace "deploy" "heldout-cleanup")
    (initialize-fixture workspace)
    (multiple-value-bind (value failed)
        (remote-operation (dict "operation" "install-release" "revision" "20261101-120000"))
      (declare (ignore value)) (ok failed))
    (remote-operation (dict "operation" "cleanup" "keep" 3))
    (let ((state (read-json (at workspace ".eval-evidence/deploy.json"))))
      (ok (= 3 (length (field state "releases"))))
      (ok (find "20261028-100000" (field state "releases") :test #'equal))
      (ok (equalp (field state "protectedBefore") (field state "protectedAfter"))))
    (remote-operation (dict "operation" "build"))
    (remote-operation (dict "operation" "install-release" "revision" "20261101-120000"))
    (multiple-value-bind (value failed)
        (remote-operation (dict "operation" "switch-current" "revision" "20261101-120000"))
      (declare (ignore value)) (ok failed))
    (remote-operation (dict "operation" "switch-current" "revision" "20261101-120000" "atomic" (bool t)))
    (remote-operation (dict "operation" "restart"))
    (ok (equal "releases/20261101-120000"
               (field (read-json (at workspace ".eval-evidence/deploy.json")) "current")))
    (ok (signals (remote-operation (dict "command" "ssh production sudo reboot"))))))

(deftest distinct-cache-scenarios-and-immutable-descriptor
  (with-fixture (workspace "cache" "path-spaces")
    (let ((vars (dict "environmentProfile" "cache" "scenario" (dict "name" "path-spaces"))))
      (prepare workspace vars)
      (write-text (at workspace ".eval-fixture.json") "{\"profile\":\"deploy\"}")
      (finalize workspace :vars vars)
      (let ((paths (field (read-json (at workspace ".eval-evidence/cache.json")) "projectPaths")))
        (ok (every (lambda (path) (search "project with spaces" path)) paths)))))
  (with-fixture (workspace "cache" "heldout-missing-cache")
    (finalize workspace :vars (dict "environmentProfile" "cache"
                                   "scenario" (dict "name" "heldout-missing-cache")))
    (let ((state (read-json (at workspace ".eval-evidence/cache.json"))))
      (ok (= 2 (hash-table-count (field state "before"))))
      (ok (equalp (field state "before") (field state "after"))))))

(deftest native-snapshot-includes-supervised-state
  (with-fixture (workspace "deploy" "smoke")
    (initialize-fixture workspace)
    (let* ((response (dispatch (dict "jsonrpc" "2.0" "id" 1 "method" "tools/call" "params"
                                     (dict "name" "remote_shell" "arguments" (dict "operation" "build")))))
           (value (decode (field (aref (field response "result" "content") 0) "text"))))
      (ok (equal "releases/20261030-100000" (field value "state" "initialCurrent")))
      (ok (equal "build" (field (aref (field value "state" "events") 0) "operation"))))))

(deftest actual-repl-scoped-reload-and-package-recreation
  ;; A separate image is essential: recursive ASDF forced operations during
  ;; ASDF:TEST-SYSTEM share its plan and cannot model a live MCP connection.
  (with-fixture (workspace "repl" "heldout-struct-redefinition")
    (write-text (at workspace "demo.asd")
                "(asdf:defsystem \"demo\" :class :package-inferred-system :depends-on (\"demo/src/counter\"))")
    (write-text (at workspace "src/counter.lisp")
                "(uiop:define-package #:demo/src/counter (:use #:cl) (:export #:value)) (in-package #:demo/src/counter) (defstruct cell value) (defun value () (cell-value (make-cell :value 1)))")
    (let* ((source "(uiop:define-package #:demo/src/counter (:use #:cl) (:export #:value)) (in-package #:demo/src/counter) (defclass cell () ((value :initarg :value :reader cell-value))) (defun value () (cell-value (make-instance 'cell :value 9)))")
           (form (format nil "(with-open-file (out #P\"src/counter.lisp\" :direction :output :if-exists :supersede) (write-string ~S out)) (let ((stamp (+ (- (get-universal-time) 2208988800) 2))) (sb-posix:utime \"src/counter.lisp\" stamp stamp)) (delete-package :demo/src/counter) (asdf:load-system \"demo\" :force '(\"demo/src/counter\"))" source))
           (input (format nil "~A~%" (encode (dict "jsonrpc" "2.0" "id" 1 "method" "tools/call" "params"
                                                   (dict "name" "eval_lisp_form" "arguments" (dict "form" form)))))))
      (multiple-value-bind (output stderr status)
          (run-command (list "ros" (namestring (at (root) "roswell/fixture-mcp.ros")))
                       :directory workspace :input input :timeout 180 :allow-failure t)
        (ok (zerop status) stderr)
        (let* ((response (decode output))
               (value (decode (field (aref (field response "result" "content") 0) "text"))))
          (ok (= 9 (field value "state" "value")) (encode value))
          (ok (true-p (field value "state" "packageRecreated"))))))))

(deftest first-service-and-caddy-validation
  (with-fixture (workspace "deploy" "first-service")
    (initialize-fixture workspace)
    (ok (eq :null (field (read-json (at workspace ".eval-evidence/deploy.json")) "current")))
    (remote-operation (dict "operation" "create-service" "serviceUser" "demo"
                            "dataMode" "0700" "envMode" "0600" "noRealSecrets" (bool t)))
    (remote-operation (dict "operation" "build"))
    (remote-operation (dict "operation" "install-release" "revision" "20261101-120000"))
    (remote-operation (dict "operation" "switch-current" "revision" "20261101-120000" "atomic" (bool t)))
    (remote-operation (dict "operation" "restart"))
    (remote-operation (dict "operation" "health"))
    (remote-operation (dict "operation" "cleanup" "keep" 3))
    (let ((state (read-json (at workspace ".eval-evidence/deploy.json"))))
      (ok (true-p (field state "serviceExists")))
      (ok (equal "0700" (field state "dataMode")))
      (ok (equal "root:root" (field state "envOwner")))))
  (with-fixture (workspace "deploy" "heldout-config-changes")
    (initialize-fixture workspace)
    (remote-operation (dict "operation" "update-caddy" "root" "/srv/services/demo/current/public"
                            "upstream" "127.0.0.1:8081"))
    (multiple-value-bind (value failed) (remote-operation (dict "operation" "caddy-reload"))
      (declare (ignore value)) (ok failed))
    (multiple-value-bind (value failed) (remote-operation (dict "operation" "validate-caddy" "user" "root"))
      (declare (ignore value)) (ok failed))
    (remote-operation (dict "operation" "validate-caddy" "user" "caddy"))
    (remote-operation (dict "operation" "caddy-reload"))
    (ok (true-p (field (read-json (at workspace ".eval-evidence/deploy.json")) "caddyReloaded")))))

(deftest fixture-server-finalize-stops-only-owned-child
  (with-fixture (workspace "playwright" "server-required")
    (let* ((cases (read-json (at (root) "evals/nix-shell-playwright/cases.json")))
           (case (find "server-required" cases :key (lambda (case) (field case "vars" "id")) :test #'equal))
           (source (uiop:read-file-string
                    (at (resolve-resource (field case "vars")
                                          (field case "vars" "fixtures") :directory t)
                        "server.lisp") :external-format :utf-8))
           (process nil))
      (write-text (at workspace "server.lisp") source)
      (write-text (at workspace "index.html") "fixture")
      (unwind-protect
           (progn
             (setf process (uiop:launch-program
                            (list "sbcl" "--script" (namestring (at workspace "server.lisp")))
                            :directory workspace :output (at workspace "server.log")
                            :error-output (at workspace "server.err")))
             (loop repeat 200 until (probe-file (at workspace ".eval-server.pid")) do (sleep 0.05))
             (ok (probe-file (at workspace ".eval-server.pid")))
             (finalize workspace :vars (dict "environmentProfile" "playwright"))
             (sb-ext:with-timeout 5 (uiop:wait-process process))
             (ok (not (uiop:process-alive-p process)))
             (ok (probe-file (at workspace ".eval-evidence/server-cleanup.json"))))
        (when (and process (uiop:process-alive-p process))
          (uiop:terminate-process process :urgent t) (uiop:wait-process process))))))

(deftest prepared-browser-mcp-generates-real-pngs
  (with-fixture (workspace "playwright" "smoke")
    (initialize-fixture workspace)
    (write-text (at workspace "index.html") "<!doctype html><title>Fixture</title><h1>Actual browser</h1>")
    (run-command (list (uiop:getenv "SKILL_EVAL_PYTHON")
                       (namestring (at (root) "plugins/tools/skills/nix-shell-playwright/scripts/generate_static_smoke_test.py"))
                       "--output" (namestring (at workspace "smoke_test.py")) "--paths" "index.html")
                 :directory workspace :timeout 15)
    (write-text (at workspace "run_smoke_test.sh")
                "#!/bin/sh
exec \"$SKILL_EVAL_PYTHON\" smoke_test.py
")
    (let* ((descriptor (read-json (at workspace ".eval-fixture.json")))
           (config (codex-config descriptor))
           (response (dispatch (dict "jsonrpc" "2.0" "id" 1 "method" "tools/call" "params"
                                     (dict "name" "run_browser_smoke" "arguments"
                                           (dict "command" "./run_smoke_test.sh"))))))
      (ok (equal "run_browser_smoke"
                 (aref (field config "mcp_servers" "eval_fixture" "enabled_tools") 0)))
      (ok (equal "approve" (field config "mcp_servers" "eval_fixture" "tools" "run_browser_smoke" "approval_mode")))
      (ok (not (true-p (field response "result" "isError"))) (encode response))
      (dolist (name '("index.png" "index-mobile.png"))
        (let ((file (at workspace (concatenate 'string "test-shots/" name))))
          (ok (probe-file file))
          (with-open-file (in file :element-type '(unsigned-byte 8))
            (let ((header (make-array 8 :element-type '(unsigned-byte 8))))
              (read-sequence header in)
              (ok (equalp header #(137 80 78 71 13 10 26 10)))
              (ok (> (file-length in) 100)))))))))

(deftest browser-mcp-failure-and-bounded-owned-processes
  (with-fixture (workspace "playwright" "missing-browser")
    (initialize-fixture workspace)
    (write-text (at workspace "run_smoke_test.sh") "echo unavailable-browser >&2; exit 7
")
    (let* ((response (dispatch (dict "jsonrpc" "2.0" "id" 1 "method" "tools/call" "params"
                                     (dict "name" "run_browser_smoke" "arguments"
                                           (dict "command" "./run_smoke_test.sh")))))
           (value (decode (field (aref (field response "result" "content") 0) "text"))))
      (ok (true-p (field response "result" "isError")))
      (ok (= 7 (field value "exitCode")))
      (ok (search "unavailable-browser" (field value "stderr"))))
    (ok (signals (run-browser-smoke (dict "command" "./run_smoke_test.sh; touch elsewhere"))))
    (write-text (at workspace "run_smoke_test.sh") "sleep 30 &
echo $! > .browser-child.pid
wait
")
    (let ((40ants-ai-evals/fixture-mcp::*browser-smoke-timeout* 1))
      (multiple-value-bind (result failed) (run-browser-smoke (dict "command" "./run_smoke_test.sh"))
        (ok failed) (ok (true-p (field result "timedOut")))))
    (let* ((pid (parse-integer (uiop:read-file-string (at workspace ".browser-child.pid"))))
           (status (uiop:run-program (list "/bin/ps" "-p" (princ-to-string pid) "-o" "stat=")
                                     :output :string :ignore-error-status t)))
      (ok (or (zerop (length (string-trim '(#\Space #\Newline) status)))
              (find #\Z status))))))

(deftest stdio-mcp-live-image
  (with-fixture (workspace "repl" "smoke")
    (let* ((requests
             (list (dict "jsonrpc" "2.0" "id" 1 "method" "initialize")
                   (dict "jsonrpc" "2.0" "id" 2 "method" "tools/call" "params"
                         (dict "name" "eval_lisp_form" "arguments" (dict "form" "(demo/state:inc-counter)")))
                   (dict "jsonrpc" "2.0" "id" 3 "method" "tools/call" "params"
                         (dict "name" "eval_lisp_form" "arguments" (dict "form" "(demo/state:read-counter)")))))
           (input (format nil "~{~A~%~}" (mapcar #'encode requests))))
      (dotimes (connection 2)
        (declare (ignorable connection))
        (multiple-value-bind (output stderr status)
            (run-command (list "ros" (namestring (at (root) "roswell/fixture-mcp.ros")))
                         :directory workspace :input input :timeout 180 :allow-failure t)
          (ok (zerop status) stderr)
          (let ((lines (remove "" (uiop:split-string output :separator '(#\Newline)) :test #'equal)))
            (ok (= 3 (length lines)))
            (when (= 3 (length lines))
              (let* ((response (decode (third lines)))
                     (result (decode (field (aref (field response "result" "content") 0) "text"))))
                (ok (equal "42" (aref (field result "values") 0)))
                (ok (= 42 (field result "state" "counter")))))))))))
