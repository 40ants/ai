;;;; Exercise the Lisp collector against a real disposable workspace.
(uiop:define-package #:40ants-ai-evals-tests/collector-test
  (:use #:cl)
  (:import-from #:serapeum #:dict #:->)
  (:import-from #:rove #:deftest #:testing #:ok #:signals)
  (:import-from #:40ants-ai-evals/util
                #:at #:field #:encode #:read-json #:write-json #:write-text #:temporary-directory
                #:remove-directory #:true-p #:run-command #:root)
  (:import-from #:40ants-ai-evals/collector #:collect-and-grade)
  (:import-from #:40ants-ai-evals/runner #:grading-vars))
(in-package #:40ants-ai-evals-tests/collector-test)

(-> collector-request (pathname)
    hash-table)
(defun collector-request (scratch)
  (dict "protocolVersion" 1 "output" "I used writing-common-lisp"
        "runDir" (namestring (at scratch "run/"))
        "context"
        (dict "vars" (40ants-ai-evals/runner:grading-vars
                       (dict "id" "negative" "shouldTrigger" 'yason:false
                             "textFile" "hello.py" "textContains" "hello"))
              "provider" (dict "label" "with-skill") "prompt" "Create hello.py"
              "providerResponse"
              (dict "metadata" (dict "workingDir" (namestring (at scratch "workspace/"))
                                      "skillCalls" #())
                    "raw" (encode (dict "items" (vector (dict "type" "command_execution"))
                                         "usage" (dict "input_tokens" 12 "output_tokens" 3)))))))

(deftest artifact-collection
  (let ((scratch (temporary-directory "collector-test")))
    (unwind-protect
         (progn
           (write-text (at scratch "workspace/hello.py") (format nil "print(\"hello\")~%"))
           (write-text (at scratch "workspace/.git/config") "excluded")
           (write-text (at scratch "workspace/.agents/skills/example/SKILL.md") "excluded")
           (let* ((request (collector-request scratch))
                  (response (collect-and-grade request)) (sample (field response "sample"))
                  (sample-file (at scratch (format nil "run/samples/~A/sample.json"
                                                   (field sample "sampleId")))))
             (ok (true-p (field response "grading" "pass")))
             (ok (not (true-p (field sample "skillRead"))))
             (ok (= 1 (field sample "commandCount")))
             (remove-directory (at scratch "workspace/"))
             (ok (= 1 (hash-table-count (field (read-json sample-file) "files"))))
             (ok (signals (collect-and-grade request)))))
      (remove-directory scratch))))

(deftest invalid-context-and-symlinks
  (let ((scratch (temporary-directory "collector-test")))
    (unwind-protect
         (let ((request (collector-request scratch)))
           (write-text (at scratch "workspace/hello.py") "hello")
           (setf (gethash "protocolVersion" request) 2)
           (ok (signals (collect-and-grade request)))
           (setf (gethash "protocolVersion" request) 1)
           (run-command (list "ln" "-s" "/etc/hosts"
                              (namestring (at scratch "workspace/outside"))))
           (ok (signals (collect-and-grade request))))
      (remove-directory scratch))))

(deftest subprocess-timeout
  (ok (signals (run-command '("sleep" "5") :timeout 0.1))))

(-> invoke-adapter (hash-table &key (:environment list))
    hash-table)
(defun invoke-adapter (request &key environment)
  ;; Node only invokes the adapter; assertions and fixtures are Common Lisp.
  (let* ((invoke (concatenate 'string
                 "const r=JSON.parse(process.argv[2]);"
                 "require(process.argv[1])(r.output,r.context)"
                 ".then(g=>console.log(JSON.stringify({grading:g,metadata:"
                 "r.context.providerResponse.metadata})))"
                 ".catch(e=>console.log(JSON.stringify({error:e.message,metadata:"
                 "r.context.providerResponse.metadata})))"))
         (stdout (run-command
                  (append (list "env"
                                (format nil "SKILL_EVAL_RUN_DIR=~A" (field request "runDir")))
                          environment
                          (list "node" "-e" invoke
                                (namestring (at (root) "evals/lib/promptfoo-adapter.cjs"))
                                (encode request))) :timeout 90)))
    (40ants-ai-evals/util:decode stdout)))

(deftest adapter-round-trip
  (let ((scratch (temporary-directory "adapter-test")))
    (unwind-protect
         (progn
           (write-text (at scratch "workspace/hello.py") "hello")
           (let ((response (invoke-adapter (collector-request scratch))))
             (ok (true-p (field response "grading" "pass")))
             (ok (equal "with-skill" (field response "metadata" "skillEval" "variant")))
             (ok (stringp (field response "metadata" "skillEval" "sampleId")))))
      (remove-directory scratch))))

(deftest adapter-process-failures
  (let ((scratch (temporary-directory "adapter-errors")))
    (unwind-protect
         (loop for body in (list "printf 'not-json'" "printf '{}'" "exit 3" "sleep 5")
               for expected in '("Invalid Lisp protocol JSON"
                                 "Invalid Lisp protocol response schema"
                                 "Lisp assertion exited 3" "Lisp assertion timeout") do
          (let ((fake (at scratch "bin/ros")))
            (write-text fake (format nil "#!/bin/sh~%cat >/dev/null~%~A~%" body))
            (run-command (list "chmod" "+x" (namestring fake)))
            (let* ((response
                     (invoke-adapter (collector-request scratch)
                       :environment
                       (list (format nil "PATH=~A:~A" (at scratch "bin/") (uiop:getenv "PATH"))
                             (if (equal body "sleep 5")
                                 "SKILL_EVAL_ADAPTER_TIMEOUT_MS=500"
                                 "SKILL_EVAL_ADAPTER_TIMEOUT_MS=5000"))))
                   (error (field response "error")))
              (ok (and (stringp error) (search expected error))
                  (format nil "Expected ~S, received ~S" expected error))
              (ok (equal error (field response "metadata" "skillEval" "infrastructureError"))))))
      (remove-directory scratch))))

(-> open-code-request (pathname)
    hash-table)
(defun open-code-request (scratch)
  (let* ((request (collector-request scratch))
         (response (field request "context" "providerResponse"))
         (metadata (field response "metadata")))
    (write-json (at scratch "run/opencode/native-trace.json")
                (dict "agent" "opencode" "export" (dict "data" (dict "messages" #()))
                      "log" "raw session events"))
    (setf (gethash "provider" (field request "context")) (dict "label" "opencode:with-skill")
          (gethash "agent" metadata) "opencode" (gethash "variant" metadata) "with-skill"
          (gethash "tracePath" metadata) (namestring (at scratch "run/opencode/native-trace.json"))
          (gethash "skillRead" metadata) 'yason:false
          (gethash "commandCount" metadata) 2
          (gethash "usage" metadata) (dict "input_tokens" 12 "output_tokens" 3
                                         "reasoning_tokens" 4 "cached_input_tokens" 5
                                         "total_tokens" 24)
          (gethash "sessionId" response) "session-one")
    request))

(deftest opencode-collection-and-error-archive
  (let ((scratch (temporary-directory "opencode-collector")))
    (unwind-protect
         (progn
           (write-text (at scratch "workspace/hello.py") "hello")
           (write-text (at scratch "workspace/.opencode/skills/writing-common-lisp/SKILL.md") "owned")
           (let* ((request (open-code-request scratch))
                  (answer (collect-and-grade request)) (stats (field answer "sample"))
                  (sample (read-json (at scratch (format nil "run/samples/~A/sample.json"
                                                         (field stats "sampleId"))))))
             (ok (true-p (field answer "grading" "pass")))
             (ok (equal "opencode" (field stats "agent")))
             (ok (equal "with-skill" (field stats "variant")))
             (ok (equal "session" (field stats "usageScope")))
             (ok (= 1 (hash-table-count (field sample "files"))))
             (ok (equal "raw session events" (field (read-json (at (field request "runDir")
                                                                          (field stats "trace"))) "log")))
             (setf (gethash "error" (field request "context" "providerResponse")) "model timeout")
             (let ((partial (collect-and-grade request)))
               (ok (search "model timeout" (field partial "infrastructureError")))
               (ok (probe-file (at (field request "runDir")
                                   (format nil "samples/~A/files/hello.py"
                                           (field partial "sample" "sampleId"))))))
             (setf (gethash "tracePath" (field request "context" "providerResponse" "metadata"))
                   (namestring (at scratch "outside.json")))
             (write-json (at scratch "outside.json") (dict))
             (ok (signals (collect-and-grade request)))))
      (remove-directory scratch))))

(deftest failed-codex-skill-evidence
  (let ((request (collector-request #P"/tmp/unused/")))
    (setf (gethash "skillCalls" (field request "context" "providerResponse" "metadata"))
          (vector (dict "name" "writing-common-lisp" "is_error" 'yason:true)))
    (ok (not (true-p
              (field (40ants-ai-evals/collector::provider-statistics
                      (field request "context" "providerResponse")
                      (dict "items" #()) "codex") "skillRead"))))))

(deftest adapter-failure-preserves-normalized-identity
  (let ((scratch (temporary-directory "adapter-normalized-error")))
    (unwind-protect
         (progn
           (write-text (at scratch "workspace/hello.py") "hello")
           (let ((request (collector-request scratch)))
             (setf (gethash "provider" (field request "context"))
                   (dict "label" "codex:with-skill")
                   (gethash "checks" (field request "context" "vars")) #("missing/check"))
             (let ((result (invoke-adapter request)))
               (ok (stringp (field result "error")))
               (ok (equal "codex" (field result "metadata" "skillEval" "agent")))
               (ok (equal "with-skill" (field result "metadata" "skillEval" "variant"))))))
      (remove-directory scratch))))
