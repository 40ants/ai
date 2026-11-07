;;;; Multi-suite discovery, preflight and native fixture installation without models.
(uiop:define-package #:40ants-ai-skills-tests/suites-test
  (:use #:cl)
  (:import-from #:rove #:deftest #:ok #:signals)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:40ants-ai-evals/suites #:catalog #:find-suite #:suite-path #:describe-suites)
  (:import-from #:40ants-ai-evals/runner #:grading-vars #:validate-options)
  (:import-from #:40ants-ai-evals/agents #:render-task)
  (:import-from #:40ants-ai-evals/util #:field #:at #:root #:read-json #:write-text
                #:temporary-directory #:remove-directory #:sequence-list #:digest-file))
(in-package #:40ants-ai-skills-tests/suites-test)

(deftest declared-suite-coverage
  (ok (= 12 (length (catalog))))
  (ok (equal "writing-common-lisp" (field (find-suite) "id")))
  (ok (signals (find-suite "../escape")))
  (ok (signals (validate-options (dict "suite" "unknown"))))
  (let ((new-count 0))
    (dolist (suite (catalog))
      (let* ((id (field suite "id"))
             (cases (read-json (at (at (root) (suite-path id)) "cases.json"))))
        (unless (equal id "writing-common-lisp")
          (incf new-count (length cases))
          (ok (= 6 (length cases)) id)
          (ok (= 1 (count "holdout" (sequence-list cases) :test #'equal
                          :key (lambda (case) (field case "vars" "group")))))
          (ok (find "smoke" (sequence-list cases) :test #'equal
                    :key (lambda (case) (field case "vars" "id"))))
          (let ((ids (mapcar (lambda (case) (field case "vars" "id")) (sequence-list cases))))
            (ok (= (length ids) (length (remove-duplicates ids :test #'equal))))))
        (loop for case across cases do
          (let ((vars (grading-vars (field case "vars"))))
            (ok (field vars "checks"))
            (unless (equal id "writing-common-lisp")
              (ok (equal id (field vars "suite")))
              (ok (equal id (field vars "skillName"))))))))
    (ok (= 66 new-count))))

(deftest generic-native-skill-reference
  (ok (search "first read .agents/skills/handling-json-in-common-lisp/SKILL.md"
              (render-task "Use $handling-json-in-common-lisp. Repair JSON."
                           "codex" "handling-json-in-common-lisp")))
  (ok (equal "Repair JSON." (render-task "Repair JSON." "codex" "handling-json-in-common-lisp")))
  (ok (equal "Use handling-json-in-common-lisp skill. Repair JSON."
             (render-task "Use $handling-json-in-common-lisp. Repair JSON."
                          "opencode" "handling-json-in-common-lisp")))
  (let* ((scratch (temporary-directory "suite-fixture"))
         (vars (dict "suite" "handling-json-in-common-lisp"
                     "skillName" "handling-json-in-common-lisp" "environmentProfile" "lisp"
                     "id" "sample" "task" "Use $handling-json-in-common-lisp. Repair JSON."
                     "fixtures" (dict "seed.txt" "untouched"))))
    (unwind-protect
         (progn
           (write-text (at scratch "skill/SKILL.md") "fixture skill")
           (40ants-ai-evals/runner::prepare-fixtures
            scratch (list (dict "vars" vars)) '("with-skill" "without-skill") '("codex" "opencode"))
           (ok (equal "Repair JSON." (field vars "taskWithoutSkill")))
           (dolist (agent '("codex" "opencode"))
             (let ((with (field vars "workspaces" agent "with-skill"))
                   (without (field vars "workspaces" agent "without-skill"))
                   (dir (if (equal agent "codex") ".agents" ".opencode")))
               (ok (probe-file (at with (format nil "~A/skills/handling-json-in-common-lisp/SKILL.md" dir))))
               (ok (not (probe-file (at without (format nil "~A/skills/handling-json-in-common-lisp/SKILL.md" dir)))))
               (ok (probe-file (at with ".eval-fixture.json"))))))
      (remove-directory scratch))))

(deftest replay-detects-missing-or-corrupt-binary
  (let* ((scratch (temporary-directory "archive-integrity"))
         (file (at scratch "artifacts/test-shots/index.png"))
         (sample (dict "artifacts" (dict))))
    (unwind-protect
         (progn
           (write-text file "original artifact bytes")
           (setf (gethash "test-shots/index.png" (gethash "artifacts" sample))
                 (dict "kind" "binary" "size" 23 "sha256" (digest-file file)))
           (ok (not (40ants-ai-evals/runner::archive-integrity-error sample scratch)))
           (write-text file "modified artifact bytes")
           (ok (search "Corrupt" (40ants-ai-evals/runner::archive-integrity-error sample scratch)))
           (delete-file file)
           (ok (search "Missing" (40ants-ai-evals/runner::archive-integrity-error sample scratch)))
           (ok (not (40ants-ai-evals/runner::archive-integrity-error (dict) scratch))))
      (remove-directory scratch))))


(deftest version-diagnostics-do-not-change-the-pin
  (ok (equal "0.125.1" (40ants-ai-evals/runner::version-line
                        (format nil "Error removing old log file: ENOENT~%0.125.1~%"))))
  (ok (equal "0.126.0" (40ants-ai-evals/runner::version-line "0.126.0"))))


(deftest batch-index-keeps-exact-invocation-ownership
  (let ((scratch (temporary-directory "batch-concurrent-test"))
        (entry (find-suite "handling-json-in-common-lisp")))
    (unwind-protect
         (progn
           (let ((row (40ants-ai-evals/runner::run-suite-record
                       entry (dict "agent" "opencode")
                       (lambda (flags)
                         (declare (ignore flags))
                         ;; A different process can create a run during our suite.
                         (write-text (at scratch "unrelated-run/manifest.json") "{}")
                         (write-text (at scratch "owned-run/manifest.json") "{}")
                         (funcall 40ants-ai-evals/runner::*run-created-hook* "owned-run")
                         0))))
             (ok (zerop (field row "status")))
             (ok (equalp #("owned-run") (field row "runIds")))
             (ok (probe-file (at scratch "unrelated-run/manifest.json"))))
           (let ((row (40ants-ai-evals/runner::run-suite-record
                       entry (dict "agent" "opencode")
                       (lambda (flags)
                         (declare (ignore flags))
                         (funcall 40ants-ai-evals/runner::*run-created-hook* "failed-setup-run")
                         (error "Intentional setup failure")))))
             (ok (= 2 (field row "status")))
             (ok (equalp #("failed-setup-run") (field row "runIds")))))
      (remove-directory scratch))))
