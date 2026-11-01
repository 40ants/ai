;;;; Simulate outer Promptfoo deadlines without calling a model or keeping workspaces alive.
(uiop:define-package #:40ants-ai-evals-tests/recovery-test
  (:use #:cl)
  (:import-from #:serapeum #:dict)
  (:import-from #:rove #:deftest #:ok)
  (:import-from #:40ants-ai-evals/recovery #:capture #:recover)
  (:import-from #:40ants-ai-evals/util
                #:at #:field #:write-text #:write-json #:read-json #:temporary-directory
                #:remove-directory #:digest-file #:true-p #:json-equal-p))
(in-package #:40ants-ai-evals-tests/recovery-test)

(defun failed-result (case-id variant)
  (dict "testCase" (dict "vars" (dict "id" case-id))
        "provider" (dict "label" (format nil "opencode:~A" variant))
        "success" 'yason:false "score" 0 "failureReason" 2
        "response" (dict "error" "Promptfoo evaluation timeout after 240000ms")))

(deftest timeout-workspace-evidence-recovered
  (let ((scratch (temporary-directory "provider-recovery")))
    (unwind-protect
         (let* ((workspace (at scratch "workspace/"))
                (provider-dir (at scratch "run/opencode/native/"))
                (run-dir (at scratch "run/"))
                (vars (dict "id" "smoke" "variant" "with-skill"
                            "suite" "handling-json-in-common-lisp"
                            "skillName" "handling-json-in-common-lisp" "fixtures" (dict)))
                (trace-path (at provider-dir "trace.json")))
           (write-text (at workspace "src/json.lisp") "(defun roundtrip (text) text)")
           (ensure-directories-exist (at workspace "image.bin"))
           (with-open-file (stream (at workspace "image.bin") :direction :output
                                   :element-type '(unsigned-byte 8))
             (write-sequence #(0 1 255 3) stream))
           (write-json trace-path (dict "session" (dict "data" (dict "id" "native-session"))
                                        "export" (dict "data" (dict "messages" #()))))
           (let* ((snapshot (capture workspace provider-dir vars
                                     (dict "toolCalls" (vector (dict "name" "shell"
                                                                       "arguments" (dict "command" "write source")
                                                                       "result" "done" "success" 'yason:true))
                                           "skillRead" 'yason:true "commandCount" 1
                                           "usage" (dict "total_tokens" 123) "output" "partial")
                                     trace-path "native execution timeout"))
                  (sample-id (field snapshot "sampleId"))
                  (binary-hash (digest-file (at workspace "image.bin")))
                  (row (failed-result "smoke" "with-skill")))
             (ok (true-p (field snapshot "available")))
             (ok (equal "native-session" (field snapshot "sessionId")))
             (write-json (at run-dir "results.json") (dict "results" (dict "results" (vector row))))
             (remove-directory workspace)
             (ok (= 1 (field (recover run-dir) "recovered")))
             (let* ((export (read-json (at run-dir "results.json")))
                    (result (aref (field export "results" "results") 0))
                    (stats (field result "response" "metadata" "skillEval"))
                    (sample (read-json (at run-dir (format nil "samples/~A/sample.json" sample-id)))))
               (ok (= 0 (field result "score")))
               (ok (not (true-p (field result "success"))))
               (ok (equal "smoke" (field stats "case")))
               (ok (equal "handling-json-in-common-lisp" (field sample "suite")))
               (ok (equal "(defun roundtrip (text) text)" (field sample "files" "src/json.lisp")))
               (ok (equal binary-hash (digest-file (at run-dir (format nil "samples/~A/artifacts/image.bin" sample-id)))))
               (ok (search "Promptfoo evaluation timeout" (field stats "infrastructureError")))
               (ok (probe-file (at run-dir (format nil "samples/~A/grading-error.json" sample-id))))
               (ok (equal "native-session" (field (read-json (at run-dir (field stats "trace"))) "session" "data" "id")))
               (ok (= 0 (field (recover run-dir) "recovered"))))))
      (remove-directory scratch))))

(deftest absent-native-evidence-is-not-invented
  (let ((scratch (temporary-directory "missing-provider-evidence")))
    (unwind-protect
         (progn
           (write-json (at scratch "results.json")
                       (dict "results" (vector (failed-result "smoke" "with-skill"))))
           (let* ((report (recover scratch))
                  (row (aref (field (read-json (at scratch "results.json")) "results") 0)))
             (ok (= 0 (field report "recovered")))
             (ok (= 1 (field report "unavailable")))
             (ok (null (field row "response" "metadata" "skillEval")))
             (ok (not (true-p (field row "response" "metadata" "recovery" "available"))))))
      (remove-directory scratch))))

(deftest exact-case-and-corrupt-artifact-guards
  (let ((scratch (temporary-directory "recovery-guards")))
    (unwind-protect
         (let* ((workspace (at scratch "workspace/"))
                (provider-dir (at scratch "opencode/native/")))
           (write-text (at workspace "source.lisp") "original")
           (capture workspace provider-dir (dict "id" "other-case" "variant" "with-skill")
                    (dict) nil "timeout")
           (write-json (at scratch "results.json")
                       (dict "results" (vector (failed-result "smoke" "with-skill"))))
           (ok (= 0 (field (recover scratch) "recovered")))
           (write-json (at scratch "results.json")
                       (dict "results" (vector (failed-result "other-case" "with-skill"))))
           (write-text (at provider-dir "files/source.lisp") "tampered")
           (ok (= 0 (field (recover scratch) "recovered")))
           (let ((row (aref (field (read-json (at scratch "results.json")) "results") 0)))
             (ok (null (field row "response" "metadata" "skillEval")))
             (ok (search "bytes do not match" (field row "response" "metadata" "recovery" "reason")))))
      (remove-directory scratch))))
