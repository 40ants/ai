;;;; Real, offline Qlot subprocesses and prepared workspace contracts.
(uiop:define-package #:40ants-ai-evals-tests/qlot-environment-test
  (:use #:cl)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:rove #:deftest #:ok)
  (:import-from #:40ants-ai-evals/util
                #:at #:root #:run-command #:temporary-directory #:remove-directory
                #:write-text #:read-json #:field)
  (:import-from #:40ants-ai-evals/runner)
  (:import-from #:uiop)
  (:import-from #:40ants-ai-evals/environments #:prepare))
(in-package #:40ants-ai-evals-tests/qlot-environment-test)

(deftest isolated-qlot-runtime
  (let ((workspace (temporary-directory "qlot-runtime-test")))
    (unwind-protect
         (progn
           ;; An identically named DEMO exists in the harness fixtures. A fresh
           ;; sample must neither discover it nor lose the pinned distribution.
           (multiple-value-bind (out err code)
               (run-command
                (list "qlot" "exec" "sbcl" "--non-interactive"
                      "--eval" "(assert (null (asdf:find-system \"demo\" nil)))"
                      "--eval" "(asdf:load-system \"serapeum\")"
                      "--eval" "(assert (macro-function (find-symbol \"->\" \"SERAPEUM\")))"
                      "--eval" "(warn \"CANDIDATE-WARNING-MARKER\")"
                      "--eval" "(write-line \"ISOLATED-READY\")")
                :directory workspace :timeout 60 :allow-failure t)
             (ok (zerop code) err)
             (ok (search "ISOLATED-READY" out))
             (ok (search "CANDIDATE-WARNING-MARKER" err))
             (ok (not (search "redefining UIOP" err)))
             (ok (probe-file (at workspace ".eval-cache/lisp-startup.log"))))
           (multiple-value-bind (out err code)
               (run-command
                (list "qlot" "exec" "sbcl" "--non-interactive"
                      "--eval" "(error \"CANDIDATE-ERROR-MARKER\")")
                :directory workspace :timeout 60 :allow-failure t)
             (declare (ignore out))
             (ok (not (zerop code)))
             (ok (search "CANDIDATE-ERROR-MARKER" err)))
           (multiple-value-bind (out err code)
               (run-command
                (list "qlot" "exec" "ros" "-e"
                      "(progn (asdf:load-system \"serapeum\") (write-line \"ROSWELL-READY\"))")
                :directory workspace :timeout 60 :allow-failure t)
             (ok (zerop code) err)
             (ok (search "ROSWELL-READY" out))))
      (remove-directory workspace))))

(deftest local-inferred-projects-do-not-cross-samples
  (dolist (answer '(42 99))
    (let ((workspace (temporary-directory "qlot-local-project")))
      (unwind-protect
           (progn
             (write-text (at workspace "demo.asd")
                         "(asdf:defsystem \"demo\" :class :package-inferred-system :depends-on (\"demo/src/value\"))")
             (write-text (at workspace "src/value.lisp")
                         (format nil "(uiop:define-package #:demo/src/value (:use #:cl) (:export #:value)) (in-package #:demo/src/value) (defun value () ~D)" answer))
             (multiple-value-bind (out err code)
                 (run-command
                  (list "qlot" "exec" "sbcl" "--non-interactive"
                        "--eval" "(asdf:load-system \"demo\")"
                        "--eval" (format nil "(assert (= ~D (uiop:symbol-call :demo/src/value :value)))" answer)
                        "--eval" "(write-line \"LOCAL-PROJECT-READY\")")
                  :directory workspace :timeout 60 :allow-failure t)
               (ok (zerop code) err)
               (ok (search "LOCAL-PROJECT-READY" out))))
        (remove-directory workspace)))))

(deftest original-suite-receives-identical-runtime-context
  (let* ((scratch (temporary-directory "original-runtime-context"))
         (vars (dict "suite" "writing-common-lisp" "skillName" "writing-common-lisp"
                     "environmentProfile" "lisp" "id" "sample"
                     "task" "Create a standalone Lisp source file."
                     "fixtures" (dict "AGENTS.md" "Existing project override"))))
    (unwind-protect
         (progn
           (write-text (at scratch "skill/SKILL.md") "fixture skill")
           (40ants-ai-evals/runner::prepare-fixtures
            scratch (list (dict "vars" vars)) '("with-skill" "without-skill") '("codex" "opencode"))
           (ok (search "qlot exec" (field vars "environmentInstructions")))
           (dolist (agent '("codex" "opencode"))
             (dolist (variant '("with-skill" "without-skill"))
               (let* ((workspace (field vars "workspaces" agent variant))
                      (descriptor (read-json (at workspace ".eval-environment.json"))))
                 (ok (equal "Existing project override"
                            (uiop:read-file-string (at workspace "AGENTS.md"))))
                 (ok (equalp #("qlot" "exec") (field descriptor "commandPrefix")))
                 (ok (equal "source-file" (field descriptor "verificationMode")))
                 (ok (probe-file (at workspace ".eval-fixture.json")))))))
      (remove-directory scratch))))


(deftest actual-writing-suite-asdf-fixture
  (let* ((scratch (temporary-directory "writing-project-fixture"))
         (case (first (40ants-ai-evals/runner::selected-cases
                       (dict "suite" "writing-common-lisp" "filter" "^loop-style:"))))
         (vars (field case "vars")))
    (unwind-protect
         (progn
           (write-text (at scratch "skill/SKILL.md") "fixture skill")
           (40ants-ai-evals/runner::prepare-fixtures
            scratch (list case) '("with-skill") '("opencode"))
           (let* ((workspace (field vars "workspaces" "opencode" "with-skill"))
                  (descriptor (read-json (at workspace ".eval-environment.json"))))
             (ok (probe-file (at workspace "demo.asd")))
             (ok (equal "asdf-system" (field descriptor "verificationMode")))
             (write-text
              (at workspace "src/numbers.lisp")
              "(uiop:define-package #:demo/src/numbers (:use #:cl) (:import-from #:serapeum #:->) (:export #:sum-even)) (in-package #:demo/src/numbers) (-> sum-even (list) (values integer &optional)) (defun sum-even (numbers) (loop for n in numbers when (evenp n) sum n))")
             (multiple-value-bind (out err code)
                 (run-command
                  (list "qlot" "exec" "sbcl" "--non-interactive"
                        "--eval" "(asdf:load-system \"demo\")"
                        "--eval" "(assert (= 6 (uiop:symbol-call :demo/src/numbers :sum-even '(1 2 3 4))))"
                        "--eval" "(write-line \"WRITING-PROJECT-READY\")")
                  :directory workspace :timeout 60 :allow-failure t)
               (ok (zerop code) err)
               (ok (search "WRITING-PROJECT-READY" out)))))
      (remove-directory scratch))))


(deftest nested-qlot-in-root-shell
  (multiple-value-bind (out err code)
      (run-command
       (list "qlot" "exec" "sh" "-c"
             "qlot exec sbcl --non-interactive --eval '(asdf:load-system \"serapeum\")' --eval '(write-line \"NESTED-QLOT-READY\")'")
       :directory (root) :timeout 60 :allow-failure t)
    (ok (zerop code) err)
    (ok (search "NESTED-QLOT-READY" out))))
