;;;; Offline protocol fixtures for the pinned OpenCode v2 API.
(uiop:define-package #:40ants-ai-evals-tests/opencode-test
  (:use #:cl)
  (:import-from #:serapeum #:dict #:->)
  (:import-from #:rove #:deftest #:ok #:signals)
  (:import-from #:40ants-ai-evals/util
                #:field #:at #:write-text #:read-json #:temporary-directory
                #:remove-directory #:true-p)
  (:import-from #:40ants-ai-evals/providers/opencode
                #:model-reference #:normalize-transcript #:call-agent #:*http-request*))
(in-package #:40ants-ai-evals-tests/opencode-test)

(-> assistant-fixture ()
    hash-table)
(defun assistant-fixture ()
  (dict "messages"
        (vector (dict "type" "user" "text" "Skill names in prose are not evidence")
                (dict "type" "assistant" "tokens"
                      (dict "input" 10 "output" 3 "reasoning" 2
                            "cache" (dict "read" 7 "write" 1))
                      "content"
                      (vector (dict "type" "text" "text" "Created the file.")
                              (dict "type" "tool" "name" "skill"
                                    "state" (dict "status" "completed"
                                                  "input" (dict "id" "writing-common-lisp")))
                              (dict "type" "tool" "name" "shell"
                                    "state" (dict "status" "completed"))))
                (dict "type" "compaction" "status" "completed" "tokens"
                      (dict "input" 4 "output" 1 "reasoning" 0
                            "cache" (dict "read" 0 "write" 0))))))

(deftest v2-model-and-evidence
  (let ((model (model-reference "zai-coding-plan/glm-5.3#thinking")))
    (ok (equal "zai-coding-plan" (field model "providerID")))
    (ok (equal "glm-5.3" (field model "id")))
    (ok (equal "thinking" (field model "variant"))))
  (ok (signals (model-reference "glm-5.3")))
  (ok (signals (model-reference "zai-coding-plan/")))
  (let ((evidence (normalize-transcript (assistant-fixture))))
    (ok (equal "Created the file." (field evidence "output")))
    (ok (true-p (field evidence "skillRead")))
    (ok (= 1 (field evidence "commandCount")))
    (ok (= 14 (field evidence "usage" "input_tokens")))
    (ok (= 28 (field evidence "usage" "total_tokens"))))
  (let ((evidence (normalize-transcript
                   (dict "messages"
                         (vector (dict "type" "assistant" "content"
                                       (vector (dict "type" "text" "text" "I read SKILL.md")
                                               (dict "type" "tool" "name" "skill" "state"
                                                     (dict "status" "error")))))))))
    (ok (not (true-p (field evidence "skillRead"))))
    (ok (null (field evidence "usage")))))

(deftest v2-fresh-sessions-and-partial-failure
  (let* ((scratch (temporary-directory "opencode-test"))
         (source (at scratch "fixture/"))
         (counter 0) (interrupted nil) (failed nil) (locations nil)
         (*http-request*
           (lambda (server method path body timeout raw-p)
             (declare (ignore server method timeout raw-p))
             (cond
               ((equal path "/api/session")
                (push (field body "location" "directory") locations)
                (ok (equal "zai-coding-plan" (field body "model" "providerID")))
                (dict "data" (dict "id" (format nil "ses_~D" (incf counter)))))
               ((search "/prompt" path)
                (ok (equal "Create one file" (field body "text")))
                (when failed (error "Synthetic transport failure: ~A" path))
                (dict "data" (dict)))
               ((search "/wait" path) nil)
               ((search "/interrupt" path) (setf interrupted t) (dict "interrupted" t))
               ((search "/export" path) (dict "data" (assistant-fixture)))
               ((search "/log?follow=false" path) "data: {\"type\":\"session.idle\"}")
               (t (error "Unexpected endpoint: ~A" path)))))
         (request (dict "prompt" "Create one file" "vars" (dict)
                        "config" (dict "server" (dict "id" "fake"
                                            "stateDir" (namestring (at scratch "state/")))
                                       "runDir" (namestring (at scratch "run/"))
                                       "variant" "with-skill"
                                       "working_dir" (namestring source)))))
    (unwind-protect
         (progn
           (write-text (at source ".opencode/skills/example/SKILL.md") "native skill")
           (let* ((first (call-agent request)) (second (call-agent request))
                  (trace-path (field first "metadata" "tracePath")))
             (ok (null (field first "error")))
             (ok (not (equal (field first "sessionId") (field second "sessionId"))))
             (ok (not (equal (first locations) (second locations))))
             (ok (probe-file (at (field first "metadata" "workingDir")
                                 ".opencode/skills/example/SKILL.md")))
             (ok (field (read-json trace-path) "export"))
             (ok (equal "session" (field first "metadata" "usageScope")))
             (ok (= 28 (field first "tokenUsage" "total"))))
           (setf failed t)
           (let ((result (call-agent request)))
             (ok (stringp (field result "error")))
             (ok interrupted)
             (ok (field (read-json (field result "metadata" "tracePath")) "log"))
             (ok (equal "Created the file." (field result "output")))))
      (remove-directory scratch))))

(deftest terminal-tools-final-output-and-deduplication
  (let* ((early (dict "id" "msg_1" "type" "assistant" "content"
                      (vector (dict "type" "text" "text" "I will inspect the code.")
                              (dict "id" "call_1" "type" "tool" "name" "shell"
                                    "state" (dict "status" "completed")))))
         (final (dict "id" "msg_2" "type" "assistant" "content"
                      (vector (dict "type" "text" "text" "Finished.")
                              (dict "id" "call_1" "type" "tool" "name" "shell"
                                    "state" (dict "status" "completed"))
                              (dict "id" "call_2" "type" "tool" "name" "shell"
                                    "state" (dict "status" "running"))
                              (dict "id" "call_3" "type" "tool" "name" "shell"
                                    "state" (dict "status" "error"))
                              (dict "id" "call_4" "type" "tool" "name" "skill"
                                    "state" (dict "status" "completed" "input"
                                                  (dict "id" "some-other-skill"))))))
         (result (normalize-transcript (dict "messages" (vector early final final)))))
    (ok (equal "Finished." (field result "output")))
    (ok (= 2 (field result "commandCount")))
    (ok (= 2 (field result "assistantCount")))
    (ok (not (true-p (field result "skillRead")))))
  (ok (null (field (normalize-transcript
                    (dict "messages" (vector (dict "type" "assistant"
                                                  "tokens" (dict "input" 1))))) "usage")))
  (ok (null (field (normalize-transcript nil) "commandCount"))))

(deftest timeout-and-missing-evidence
  (let* ((scratch (temporary-directory "opencode-timeout-test"))
         (source (at scratch "fixture/")) (mode :timeout) (interrupted nil)
         (*http-request*
           (lambda (server method path body timeout raw-p)
             (declare (ignore server method body timeout raw-p))
             (cond ((equal path "/api/session") (dict "data" (dict "id" "ses_fake")))
                   ((search "/prompt" path) nil)
                   ((search "/wait" path) (when (eq mode :timeout) (sleep 1)) nil)
                   ((search "/interrupt" path) (setf interrupted t) nil)
                   ((search "/export" path)
                    (if (eq mode :missing) (error "Synthetic export failure: ~A" path)
                        (dict "data" (dict "messages" #()))))
                   ((search "/log" path) "data: {}"))))
         (request (dict "prompt" "Hello" "config"
                        (dict "server" (dict "stateDir" (namestring (at scratch "state/")))
                              "timeout" 20
                              "runDir" (namestring (at scratch "run/"))
                              "working_dir" (namestring source)))))
    (unwind-protect
         (progn
           (write-text (at source "fixture.txt") "fixture")
           (let ((response (call-agent request)))
             (ok interrupted)
             (ok (search "timed out" (field response "error"))))
           (setf mode :missing)
           (ok (search "export unavailable" (field (call-agent request) "error")))
           (setf mode :empty)
           (ok (search "without an assistant" (field (call-agent request) "error"))))
      (remove-directory scratch))))

(deftest authoritative-session-usage
  (let ((transcript (assistant-fixture)))
    (setf (gethash "info" transcript)
          (dict "tokens" (dict "input" 20 "output" 5 "reasoning" 1
                                "cache" (dict "read" 10 "write" 2))))
    (let ((result (normalize-transcript transcript)))
      (ok (= 20 (field result "usage" "input_tokens")))
      (ok (= 38 (field result "usage" "total_tokens"))))))
