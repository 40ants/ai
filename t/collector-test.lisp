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
           (let* ((answer (collect-and-grade request))
                  (sample-dir (at (field request "runDir")
                                  (format nil "samples/~A/" (field answer "sample" "sampleId"))))
                  (sample (read-json (at sample-dir "sample.json"))))
             (ok (equal "/etc/hosts" (field sample "artifacts" "outside" "target")))
             (ok (null (field sample "files" "outside")))
             (ok (not (probe-file (at sample-dir "artifacts/outside"))))))
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

(deftest binary-and-hidden-evidence
  (let ((scratch (temporary-directory "binary-collector")))
    (unwind-protect
         (progn
           (write-text (at scratch "workspace/hello.py") "hello")
           (write-text (at scratch "workspace/.eval-evidence/environment.json") "{\"profile\":\"repl\"}")
           (write-text (at scratch "workspace/.eval-environment.json") "{}")
           (write-text (at scratch "workspace/.eval-cache/common-lisp/framework.fasl") "supervisor cache")
           (write-text (at scratch "workspace/.eval-cache/sbcl-fixture/project.fasl") "sample cache")
           (let ((png (at scratch "workspace/images/screenshot.png")))
             (ensure-directories-exist png)
             (with-open-file (out png :direction :output :element-type '(unsigned-byte 8))
               ;; Real one-pixel PNG; exercises byte-for-byte archival and IHDR dimensions.
               (write-sequence
                #(137 80 78 71 13 10 26 10 0 0 0 13 73 72 68 82 0 0 0 1 0 0 0 1
                  8 4 0 0 0 181 28 12 2 0 0 0 11 73 68 65 84 120 218 99 100 248 15
                  0 1 5 1 1 39 24 227 102 0 0 0 0 73 69 78 68 174 66 96 130) out)))
           (let* ((answer (collect-and-grade (collector-request scratch)))
                  (sample-dir (at scratch (format nil "run/samples/~A/"
                                                  (field answer "sample" "sampleId"))))
                  (sample (read-json (at sample-dir "sample.json"))))
             (ok (true-p (field answer "grading" "pass")))
             (ok (equal "png" (field sample "artifacts" "images/screenshot.png" "kind")))
             (ok (= 1 (field sample "artifacts" "images/screenshot.png" "width")))
             (ok (= 1 (field sample "artifacts" "images/screenshot.png" "height")))
             (ok (null (field sample "files" "images/screenshot.png")))
             (ok (stringp (field sample "files" ".eval-evidence/environment.json")))
             (ok (null (field sample "files" ".eval-environment.json")))
             (ok (equal "text" (field sample "artifacts" ".eval-environment.json" "kind")))
             (ok (null (field sample "artifacts" ".eval-cache/common-lisp/framework.fasl")))
             (ok (equal "sample cache" (field sample "files" ".eval-cache/sbcl-fixture/project.fasl")))
             (ok (equal (40ants-ai-evals/util:digest-file
                         (at scratch "workspace/images/screenshot.png"))
                        (40ants-ai-evals/util:digest-file
                         (at sample-dir "artifacts/images/screenshot.png"))))))
      (remove-directory scratch))))

(deftest exact-skill-and-normalized-tool-evidence
  (let* ((request (collector-request #P"/tmp/unused/"))
         (response (field request "context" "providerResponse"))
         (metadata (field response "metadata"))
         (turn (dict "items" (vector (dict "type" "mcp_tool_call" "id" "tool-one"
                                           "name" "mcp__image__create" "status" "completed"
                                           "arguments" (dict "prompt" "a picture")
                                           "result" (dict "path" "image.png"))))))
    (setf (gethash "skillCalls" metadata)
          (vector (dict "name" "writing-common-lisp")
                  (dict "name" "other-skill" "success" 'yason:false)))
    (ok (not (true-p (field (40ants-ai-evals/collector::provider-statistics
                            response turn "codex" "other-skill") "skillRead"))))
    (setf (gethash "skillCalls" metadata) (vector (dict "name" "other-skill")))
    (ok (true-p (field (40ants-ai-evals/collector::provider-statistics
                       response turn "codex" "other-skill") "skillRead")))
    (let ((call (aref (40ants-ai-evals/collector::provider-tool-calls response turn) 0)))
      (ok (equal "mcp__image__create" (field call "name")))
      (ok (equal "tool-one" (field call "id")))
      (ok (equal "a picture" (field call "arguments" "prompt")))
      (ok (true-p (field call "success"))))
    (setf (gethash "toolCalls" metadata)
          (vector (dict "name" "mcp__sites__deploy" "arguments" (dict "site" "test")
                        "result" "failed" "success" 'yason:false)))
    (ok (not (true-p (field (aref (40ants-ai-evals/collector::provider-tool-calls
                                  response turn) 0) "success"))))))

(deftest environment-finalization-is-archived
  (let ((scratch (temporary-directory "collector-environment")))
    (unwind-protect
         (progn
           (write-text (at scratch "workspace/hello.py") "hello")
           (write-json (at scratch "workspace/.eval-fixture.json")
                       (dict "profile" "lisp" "schemaVersion" 1))
           (let* ((request (collector-request scratch))
                  (answer (collect-and-grade request))
                  (sample-dir (at (field request "runDir")
                                  (format nil "samples/~A/" (field answer "sample" "sampleId"))))
                  (sample (read-json (at sample-dir "sample.json"))))
             (ok (true-p (field answer "grading" "pass")))
             (ok (equal "lisp" (field sample "environment" "profile")))
             (ok (null (field sample "files" ".eval-fixture.json")))
             (ok (equal "text" (field sample "artifacts" ".eval-fixture.json" "kind")))
             (ok (stringp (field sample "files" ".eval-evidence/environment.json")))
             (ok (probe-file (at sample-dir ".eval-evidence/environment.json")))
             (setf (gethash "environmentProfile" (field request "context" "vars")) "deploy")
             (let ((failed (collect-and-grade request)))
               (ok (search "Environment verification failed" (field failed "infrastructureError")))
               (ok (probe-file (at (field request "runDir")
                                   (format nil "samples/~A/grading-error.json"
                                           (field failed "sample" "sampleId"))))))))
      (remove-directory scratch))))

(deftest explicit-candidate-file-changes
  (let ((scratch (temporary-directory "collector-changes")))
    (unwind-protect
         (let* ((request (collector-request scratch))
                (vars (field request "context" "vars")))
           (setf (gethash "fixtures" vars)
                 (dict "hello.py" "hello" "keep.txt" "same" "modify.txt" "before"
                       "deleted.txt" "gone" "replace.txt" "old"))
           (dolist (entry '(("hello.py" . "hello") ("keep.txt" . "same")
                            ("modify.txt" . "after") ("added.txt" . "new")
                            (".eval-evidence/journal.jsonl" . "generated")
                            (".eval-cache/sbcl/project.fasl" . "generated")
                            (".eval-environment.json" . "{}")))
             (write-text (at (at scratch "workspace/") (car entry)) (cdr entry)))
           (dolist (name '("binary.dat" "replace.txt"))
             (with-open-file (stream (at (at scratch "workspace/") name)
                                     :direction :output :element-type '(unsigned-byte 8))
               (write-sequence #(0 255 1 2) stream)))
           (let* ((answer (collect-and-grade request))
                  (sample (read-json (at (field request "runDir")
                                         (format nil "samples/~A/sample.json"
                                                 (field answer "sample" "sampleId")))))
                  (expected (vector (dict "path" "added.txt" "status" "added")
                                    (dict "path" "binary.dat" "status" "added")
                                    (dict "path" "deleted.txt" "status" "deleted")
                                    (dict "path" "modify.txt" "status" "modified")
                                    (dict "path" "replace.txt" "status" "modified"))))
             (ok (true-p (field answer "grading" "pass")))
             (ok (40ants-ai-evals/util:json-equal-p expected (field sample "changes")))
             (ok (40ants-ai-evals/util:json-equal-p expected (field answer "sample" "changes")))
             (ok (equal "same" (field sample "files" "keep.txt")))
             (ok (stringp (field sample "files" ".eval-evidence/journal.jsonl")))
             (ok (equal "binary" (field sample "artifacts" "binary.dat" "kind")))))
      (remove-directory scratch))))

(deftest normalized-tool-exit-semantics
  (dolist (key '("exit_code" "exitCode" "exit"))
    (let ((failed (40ants-ai-evals/collector::normalized-tool-call
                   (dict "type" "command_execution" "command" "false"
                         "status" "completed" "success" 'yason:true key 1)))
          (passed (40ants-ai-evals/collector::normalized-tool-call
                   (dict "type" "command_execution" "command" "true"
                         "status" "completed" key 0))))
      (ok (not (true-p (field failed "success"))))
      (ok (= 1 (field failed "exitCode")))
      (ok (true-p (field passed "success")))))
  (ok (not (true-p
            (field (40ants-ai-evals/collector::normalized-tool-call
                    (dict "type" "mcp_tool_call" "tool" "eval_lisp_form"
                          "status" "completed" "success" 'yason:true
                          "result" (dict "isError" 'yason:true))) "success")))))


(deftest mcp-policy-rejection-is-infrastructure
  (let ((item (dict "type" "mcp_tool_call" "status" "failed")))
    (setf (gethash "error" item)
          (dict "message" "MCP tool call requires approval, but approval policy is never"))
    (ok (40ants-ai-evals/collector::blocked-mcp-error (dict "items" (vector item))))
    (setf (gethash "error" item) (dict "message" "Invalid function result"))
    (ok (not (40ants-ai-evals/collector::blocked-mcp-error (dict "items" (vector item)))))))
