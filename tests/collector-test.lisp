;;;; Exercise the Lisp collector against a real disposable workspace.
(uiop:define-package #:40ants-ai-evals/tests/collector-test
  (:use #:cl)
  (:import-from #:serapeum #:dict #:->)
  (:import-from #:rove #:deftest #:testing #:ok #:signals)
  (:import-from #:40ants-ai-evals/src/util
                #:at #:field #:encode #:read-json #:write-text #:temporary-directory
                #:remove-directory #:true-p #:run-command #:root)
  (:import-from #:40ants-ai-evals/src/collector #:collect-and-grade))
(in-package #:40ants-ai-evals/tests/collector-test)

(-> collector-request (pathname)
    hash-table)
(defun collector-request (scratch)
  (dict "protocolVersion" 1 "output" "I used writing-common-lisp"
        "runDir" (namestring (at scratch "run/"))
        "context"
        (dict "vars" (40ants-ai-evals/src/runner:grading-vars
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
    (40ants-ai-evals/src/util:decode stdout)))

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
