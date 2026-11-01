;;;; Isolated OpenCode 2.2.1 HTTP provider; no SDK or shell transport.
(uiop:define-package #:40ants-ai-evals/src/providers/opencode
  (:use #:cl)
  (:import-from #:serapeum #:dict #:->)
  (:import-from #:40ants-ai-evals/src/util
                #:field #:at #:encode #:decode #:read-json #:write-json #:write-text
                #:temporary-directory #:remove-directory #:unique-id #:now
                #:sequence-list #:true-p #:bool #:copy-directory)
  (:export #:start-server #:stop-server #:call-agent #:normalize-transcript
           #:model-reference #:*http-request*))
(in-package #:40ants-ai-evals/src/providers/opencode)

(defvar *servers* (make-hash-table :test 'equal))
(defvar *http-request* nil
  "Optional HTTP test hook receiving descriptor, method, path, body, timeout and raw-p.
The hook must return an already decoded JSON value, or text when RAW-P is true.")

(-> request-http (hash-table keyword string t real boolean)
    t)
(defun request-http (server method path body timeout raw-p)
  (if *http-request*
      (funcall *http-request* server method path body timeout raw-p)
      (let* ((password-file (at (field server "stateDir") "password"))
             (password (uiop:read-file-string password-file :external-format :utf-8))
             (result
               (handler-case
                   (dexador:request (concatenate 'string (field server "baseUrl") path)
                     :method method :basic-auth (cons "opencode" password)
                     :headers '(("Content-Type" . "application/json"))
                     :content (when body (encode body))
                     :connect-timeout (min 10 timeout) :read-timeout timeout
                     :keep-alive nil)
                 ;; HTTP conditions can include request/response bodies containing credentials.
                 (sb-ext:timeout (condition) (error condition))
                 (error () (error "OpenCode HTTP ~A failed for ~A" method path)))))
        (if raw-p result
            (if (and (stringp result) (plusp (length result))) (decode result) nil)))))

(-> server-environment (pathname string)
    list)
(defun server-environment (state password)
  (append
   (loop for name in '("PATH" "SHELL" "LANG" "LC_ALL" "TMPDIR" "SSL_CERT_FILE"
                        "SSL_CERT_DIR" "NIX_SSL_CERT_FILE" "HTTP_PROXY" "HTTPS_PROXY"
                        "ALL_PROXY" "NO_PROXY" "SKILL_EVAL_DEPENDENCY_ROOT")
         for value = (uiop:getenv name)
         when value collect (format nil "~A=~A" name value))
   (list (format nil "OPENCODE_TEST_HOME=~A" (at state "home/"))
         (format nil "XDG_CONFIG_HOME=~A" (at state "config/"))
         (format nil "XDG_DATA_HOME=~A" (at state "data/"))
         (format nil "XDG_CACHE_HOME=~A" (at state "cache/"))
         (format nil "XDG_STATE_HOME=~A" (at state "state/"))
         (format nil "OPENCODE_CONFIG_DIR=~A" (at state "config/opencode/"))
         (format nil "OPENCODE_PASSWORD=~A" password)
         "OPENCODE_DISABLE_AUTOUPDATE=true" "OPENCODE_DISABLE_CLAUDE_CODE=true"
         "OPENCODE_DISABLE_FILEWATCHER=true"
         (concatenate 'string
           "OPENCODE_CONFIG_CONTENT={\"permissions\":["
           "{\"action\":\"*\",\"resource\":\"*\",\"effect\":\"allow\"},"
           "{\"action\":\"question\",\"resource\":\"*\",\"effect\":\"deny\"}]}"))))

(-> import-credential (hash-table)
    t)
(defun import-credential (server)
  (let* ((file (or (uiop:getenv "SKILL_EVAL_OPENCODE_AUTH_FILE")
                   (namestring (merge-pathnames ".local/share/opencode/auth.json"
                                                (user-homedir-pathname)))))
         (auth (when (probe-file file) (read-json file)))
         (key (field auth "zai-coding-plan" "key")))
    (unless (and (stringp key) (plusp (length key)))
      (error "Missing zai-coding-plan key in configured OpenCode auth file: ~A" file))
    ;; Never persist or log the response: credential.create echoes the secret value.
    (request-http server :post "/api/credential"
                  (dict "integrationID" "zai-coding-plan" "label" "skill-eval"
                        "value" (dict "type" "key" "key" key)) 20 nil)
    t))

(-> start-server (t &key (:executable string))
    hash-table)
(defun start-server (run-dir &key (executable (or (uiop:getenv "SKILL_EVAL_OPENCODE_BIN")
                                                "opencode")))
  "Start a private loopback OpenCode v2 server and import only the ZAI API key.
The serializable descriptor references private temporary state; STOP-SERVER erases it."
  (let* ((state (temporary-directory "opencode-eval"))
         (id (unique-id)) (password (unique-id))
         (server (dict "id" id "stateDir" (namestring state)
                       "runDir" (namestring (uiop:ensure-directory-pathname run-dir))))
         (stdout (at run-dir (format nil "server/~A.stdout.log" id)))
         (stderr (at run-dir (format nil "server/~A.stderr.log" id)))
         (process nil) (ready nil))
    (unwind-protect
         (progn
           (dolist (directory '("home/" "config/opencode/" "data/" "cache/" "state/"))
             (ensure-directories-exist (at (at state directory) ".keep")))
           (write-text (at state "password") password)
           (sb-posix:chmod (namestring (at state "password")) #o600)
           (ensure-directories-exist stdout)
           (setf process
                 (uiop:launch-program (list executable "serve" "--stdio" "--hostname" "127.0.0.1"
                                            "--port" "0")
                   :directory state :environment (server-environment state password)
                   :input :stream :output stdout :error-output stderr
                   :if-output-exists :supersede :if-error-output-exists :supersede))
           (setf (gethash id *servers*) process)
           (loop repeat 600
                 for text = (if (probe-file stdout) (uiop:read-file-string stdout) "")
                 for url = (cl-ppcre:scan-to-strings "http://127\\.0\\.0\\.1:[0-9]+" text)
                 do (when url
                      (setf (gethash "baseUrl" server) url)
                      (return))
                    (unless (uiop:process-alive-p process)
                      (error "OpenCode server exited; inspect ~A" stderr))
                    (sleep 0.1))
           (unless (field server "baseUrl")
             (error "OpenCode server startup timed out; inspect ~A" stderr))
           (import-credential server)
           (setf ready t)
           server)
      (unless ready
        (stop-server server)
        (when (probe-file state) (remove-directory state))))))

(-> stop-server (hash-table)
    t)
(defun stop-server (server)
  "Stop the owned server and remove its private configuration, SQL data and credentials."
  (let* ((id (field server "id")) (process (gethash id *servers*)))
    (when process
      (when (uiop:process-alive-p process)
        (uiop:terminate-process process :urgent t))
      (ignore-errors (uiop:wait-process process))
      (remhash id *servers*))
    (when (and process (field server "stateDir"))
      (remove-directory (field server "stateDir"))))
  t)

(-> model-reference (string)
    hash-table)
(defun model-reference (model)
  "Parse the v2 provider/model[#variant] reference without changing its model name."
  (let* ((slash (position #\/ model)) (hash (position #\# model))
         (result (when (and slash (plusp slash) (< (1+ slash) (or hash (length model))))
                   (dict "providerID" (subseq model 0 slash)
                         "id" (subseq model (1+ slash) hash)))))
    (unless result (error "Invalid OpenCode model reference: ~A" model))
    (when hash
      (when (= (1+ hash) (length model))
        (error "Invalid OpenCode model variant: ~A" model))
      (setf (gethash "variant" result) (subseq model (1+ hash))))
    result))

(-> successful-tool-p (hash-table)
    boolean)
(defun successful-tool-p (part)
  (equal "completed" (field part "state" "status")))

(-> skill-call-p (t t t)
    boolean)
(defun skill-call-p (name input metadata)
  (or (and (equal "skill" name)
           (or (equal "writing-common-lisp" (field input "id"))
               (equal "writing-common-lisp" (field metadata "name"))))
      (and (equal "read" name)
           (let ((path (or (field input "filePath") (field input "path"))))
             (and (stringp path)
                  (search "/writing-common-lisp/SKILL.md" path :from-end t))))))

(-> normalize-transcript (t)
    hash-table)
(defun normalize-transcript (transcript)
  "Normalize complete v2 export data, deduplicating message and tool identifiers.
Token counts include compaction calls; only completed target skill reads count."
  (let ((input 0) (output 0) (reasoning 0) (cached 0) (written 0)
        (usage-seen nil) (usage-complete t) (assistant-count 0)
        (skill nil) (commands 0) (texts nil) (errors nil)
        (messages (make-hash-table :test 'equal)) (tools (make-hash-table :test 'equal)))
    (dolist (message (sequence-list (field transcript "messages")))
      (let ((id (field message "id")))
        (unless (and id (gethash id messages))
          (when id (setf (gethash id messages) t))
          (let ((tokens (field message "tokens")))
            (when tokens
              (setf usage-seen t)
              (unless (every #'numberp
                             (list (field tokens "input") (field tokens "output")
                                   (field tokens "reasoning") (field tokens "cache" "read")
                                   (field tokens "cache" "write")))
                (setf usage-complete nil))
              (incf input (or (field tokens "input") 0))
              (incf output (or (field tokens "output") 0))
              (incf reasoning (or (field tokens "reasoning") 0))
              (incf cached (or (field tokens "cache" "read") 0))
              (incf written (or (field tokens "cache" "write") 0))))
          (when (equal "assistant" (field message "type"))
            (incf assistant-count)
            (setf texts nil)
            (when (field message "error") (push (field message "error") errors))
            (dolist (part (sequence-list (field message "content")))
              (cond
                ((equal "text" (field part "type"))
                 (push (or (field part "text") "") texts))
                ((equal "tool" (field part "type"))
                 (let ((tool-id (field part "id")))
                   (unless (and tool-id (gethash tool-id tools))
                     (when tool-id (setf (gethash tool-id tools) t))
                     (when (and (successful-tool-p part)
                                (skill-call-p (field part "name")
                                              (field part "state" "input")
                                              (field part "state" "metadata")))
                       (setf skill t))
                     (when (and (member (field part "name") '("shell" "bash") :test #'equal)
                                (member (field part "state" "status")
                                        '("completed" "error") :test #'equal))
                       (incf commands))
                     ;; Code Mode records nested native calls in execution metadata.
                     (when (equal "execute" (field part "name"))
                       (dolist (call (sequence-list (field part "state" "metadata" "toolCalls")))
                         (let* ((qualified (field call "tool"))
                                (name (when (stringp qualified)
                                        (subseq qualified (1+ (or (position #\. qualified
                                                                           :from-end t) -1))))))
                           (when (and (member name '("shell" "bash") :test #'equal)
                                      (member (field call "status") '("completed" "error")
                                              :test #'equal))
                             (incf commands))
                           (when (and (equal "completed" (field call "status"))
                                      (skill-call-p name (field call "input") nil))
                             (setf skill t))))))))))))))
    ;; Session totals also include durable usage outside assistant messages.
    (let ((tokens (field transcript "info" "tokens")))
      (when tokens
        (setf usage-seen t
              usage-complete (every #'numberp
                                    (list (field tokens "input") (field tokens "output")
                                          (field tokens "reasoning")
                                          (field tokens "cache" "read")
                                          (field tokens "cache" "write"))))
        (when usage-complete
          (setf input (field tokens "input") output (field tokens "output")
                reasoning (field tokens "reasoning") cached (field tokens "cache" "read")
                written (field tokens "cache" "write")))))
    (dict "output" (format nil "~{~A~^~%~}" (nreverse texts))
          "assistantCount" assistant-count
          "skillRead" (bool skill) "commandCount" (when transcript commands)
          "errors" (coerce (nreverse errors) 'vector)
          "usage" (when (and usage-seen usage-complete)
                    (dict "input_tokens" input "output_tokens" output
                          "reasoning_tokens" reasoning "cached_input_tokens" cached
                          "cache_write_tokens" written
                          "total_tokens" (+ input output reasoning cached written))))))

(-> workspace-for (hash-table hash-table string t)
    pathname)
(defun workspace-for (config vars variant state-dir)
  (let* ((source (or (field config "working_dir")
                     (field vars "workspaces" "opencode" variant)))
         (target (if state-dir
                     (at state-dir (format nil "workspaces/~A/" (unique-id)))
                     (temporary-directory "opencode-workspace"))))
    (unless (and (stringp source) (not (search "{{" source)))
      (error "Missing resolved OpenCode fixture directory for variant ~A" variant))
    ;; Even repeated samples receive a distinct mutable workspace.
    (copy-directory source target)
    target))

(-> save-evidence (t (or null string) hash-table pathname)
    t)
(defun save-evidence (server session-id trace trace-path)
  (when session-id
    (dolist (entry '(("export" . "/api/experimental/session/~A/export")
                     ("log" . "/api/experimental/session/~A/log?follow=false")))
      (handler-case
          (setf (gethash (car entry) trace)
                (request-http server :get (format nil (cdr entry) session-id) nil 5
                              (equal "log" (car entry))))
        (error ()
          (setf (gethash (concatenate 'string (car entry) "Unavailable") trace) t)))))
  (write-json trace-path trace))

(-> call-agent (hash-table)
    hash-table)
(defun call-agent (request)
  "Run one prompt in a fresh workspace/session; retain full and partial raw evidence.
CONFIG requires runDir, server and working_dir (or VARS.workspaces.opencode.VARIANT).
Timeouts interrupt execution before collecting the projected export and durable SSE log."
  (let* ((config (or (field request "config") (dict)))
         (vars (or (field request "vars") (dict)))
         (variant (or (field config "variant") (field vars "variant") "with-skill"))
         (run-dir (or (field config "runDir") (uiop:getenv "SKILL_EVAL_RUN_DIR")))
         (sample-dir (when run-dir (at run-dir (format nil "opencode/~A/" (unique-id)))))
         (trace-path (when sample-dir (at sample-dir "trace.json")))
         (server (field config "server")) (owned nil) (session-id nil) (workspace nil)
         (started (get-internal-real-time))
         (trace (dict "schemaVersion" 1 "agent" "opencode" "startedAt" (now)))
         (failure nil) (normalized nil))
    (unless sample-dir (error "OpenCode provider requires runDir: ~A" config))
    (unwind-protect
         (handler-case
             (progn
               (unless server (setf server (start-server run-dir) owned t))
               ;; Project discovery walks ancestors: keep fixtures outside the user's home.
               ;; Shared server state lives until all assertions and error archives finish.
               (setf workspace (workspace-for config vars variant
                                              (unless owned (field server "stateDir"))))
               (let* ((model (or (field config "profile" "model")
                                 (field config "model") "zai-coding-plan/glm-5.3"))
                      (session
                        (request-http server :post "/api/session"
                          (dict "title" "Skill evaluation"
                                "location" (dict "directory" (namestring workspace))
                                "agent" (or (field config "profile" "mode") "build")
                                "model" (model-reference model)
                                "permissions"
                                (vector (dict "action" "*" "resource" "*" "effect" "allow")
                                        (dict "action" "question" "resource" "*"
                                              "effect" "deny")))
                          30 nil)))
                 (setf (gethash "session" trace) session
                       session-id (field session "data" "id"))
                 (unless (stringp session-id)
                   (error "OpenCode create response has no session ID: ~A" (encode session)))
                 (write-json trace-path trace)
                 (let ((timeout (/ (or (field config "timeout")
                                       (field config "timeoutMs") 600000) 1000.0)))
                   (handler-case
                       (sb-ext:with-timeout timeout
                         (request-http server :post (format nil "/api/session/~A/prompt" session-id)
                                       (dict "text" (field request "prompt")) timeout nil)
                         (request-http server :post
                                       (format nil "/api/experimental/session/~A/wait" session-id)
                                       nil timeout nil))
                     (sb-ext:timeout ()
                       (error "OpenCode sample timed out after ~As" timeout))))))
           (error (condition) (setf failure (princ-to-string condition))))
      (when (and failure session-id)
        (ignore-errors
          (request-http server :post (format nil "/api/session/~A/interrupt" session-id)
                        nil 5 nil)))
      (setf (gethash "finishedAt" trace) (now))
      (when failure (setf (gethash "error" trace) failure))
      (unwind-protect
           (progn
             (save-evidence server session-id trace trace-path)
             (setf normalized (normalize-transcript (field trace "export" "data"))))
        (when owned (stop-server server))))
    (unless (or failure (field trace "export" "data"))
      (setf failure "OpenCode transcript export unavailable"))
    (when (and (not failure) (zerop (field normalized "assistantCount")))
      (setf failure "OpenCode completed without an assistant response"))
    (when (and (not failure) (plusp (length (field normalized "errors"))))
      (setf failure "OpenCode assistant reported a model or execution error"))
    (let* ((usage (field normalized "usage"))
           (metadata
             (dict "agent" "opencode" "variant" variant "sessionId" session-id
                   "workingDir" (when workspace (namestring workspace))
                   "tracePath" (namestring trace-path) "skillRead" (field normalized "skillRead")
                   "commandCount" (field normalized "commandCount") "usage" usage
                   "usageScope" "session"
                   "mode" (or (field config "profile" "mode") "build")
                   "durationMs" (round (* 1000 (/ (- (get-internal-real-time) started)
                                                  internal-time-units-per-second)))))
           (response (dict "output" (field normalized "output") "sessionId" session-id
                           "metadata" metadata)))
      (when usage
        (setf (gethash "tokenUsage" response)
              (dict "prompt" (+ (field usage "input_tokens")
                                (field usage "cached_input_tokens")
                                (field usage "cache_write_tokens"))
                    "completion" (+ (field usage "output_tokens") (field usage "reasoning_tokens"))
                    "cached" (field usage "cached_input_tokens")
                    "total" (field usage "total_tokens"))))
      (when failure
        (setf (gethash "error" response) failure
              (gethash "error" trace) failure)
        (write-json trace-path trace))
      response)))
