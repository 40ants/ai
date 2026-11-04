;;;; Actual per-sample availability and immutable environment evidence.
(uiop:define-package #:40ants-ai-skills-tests/sample-environment-test
  (:use #:cl)
  (:import-from #:rove #:deftest #:ok)
  (:import-from #:serapeum #:dict)
  (:import-from #:40ants-ai-skill-test-environments/environments #:prepare #:environment-variables)
  (:import-from #:40ants-ai-evals/case-resources #:file-metadata #:product-path-p)
  (:import-from #:40ants-ai-evals/collector #:collect-files)
  (:import-from #:40ants-ai-evals/grading/contracts #:grade)
  (:import-from #:40ants-ai-evals/util
                #:at #:root #:field #:write-text #:run-command #:temporary-directory
                #:remove-directory #:true-p #:digest-file))
(in-package #:40ants-ai-skills-tests/sample-environment-test)

(deftest lint-baseline-respects-ignored-vendor
  (let ((workspace (temporary-directory "lint-git-baseline")))
    (unwind-protect
         (progn
           (write-text (at workspace ".gitignore") "vendor/")
           (write-text (at workspace "src/core.lisp") "(defun add (a b) (+ a b))")
           (write-text (at workspace "vendor/broken.lisp") "(unbalanced")
           (let* ((descriptor (prepare workspace (dict "environmentProfile" "lint")))
                  (tracked (run-command '("git" "ls-files") :directory workspace)))
             (ok (field descriptor "gitBaseline"))
             (ok (search "src/core.lisp" tracked))
             (ok (not (search "vendor/" tracked)))
             (ok (probe-file (at workspace "vendor/broken.lisp"))))
           (ok (not (probe-file (at workspace ".eval-shell-env")))))
      (remove-directory workspace))))

(deftest missing-tool-is-real-and-local
  (let* ((workspace (temporary-directory "missing-tool"))
         (normal (temporary-directory "normal-tool"))
         (shell (uiop:getenv "SKILL_EVAL_SHELL"))
         (original (uiop:getenv "SKILL_EVAL_TOOL_PATH")))
    (unwind-protect
         (progn
           (prepare workspace (dict "environmentProfile" "lint"
                                    "scenario" (dict "name" "missing-tool")))
           (prepare normal (dict "environmentProfile" "lint"))
           (ensure-directories-exist (at workspace "nested/"))
           (multiple-value-bind (out err status)
               (run-command
                (list shell "-lc"
                      "! command -v 40ants-linter && command -v mallet && qlot exec sh -c '! command -v 40ants-linter && command -v mallet'")
                :directory (at workspace "nested/") :timeout 60 :allow-failure t)
             (ok (zerop status) err)
             (ok (search "mallet" out)))
           (ok (search "40ants-linter"
                       (run-command (list shell "-lc" "command -v 40ants-linter")
                                    :directory normal)))
           (ok (equal original (uiop:getenv "SKILL_EVAL_TOOL_PATH"))))
      (remove-directory workspace)
      (remove-directory normal))))

(deftest missing-browser-overrides-shell-and-mcp
  (let ((workspace (temporary-directory "missing-browser")))
    (unwind-protect
         (let* ((descriptor (prepare workspace (dict "environmentProfile" "playwright"
                                                     "scenario" (dict "name" "missing-browser"))))
                (env (environment-variables descriptor workspace)))
           (ok (equal ".missing-browser/chromium" (field env "PLAYWRIGHT_BROWSER_PATH")))
           (multiple-value-bind (out err status)
               (run-command
                (list (uiop:getenv "SKILL_EVAL_SHELL") "-lc"
                      "test ! -e \"$PLAYWRIGHT_BROWSER_PATH\" && test \"$PLAYWRIGHT_BROWSER_PATH\" = .missing-browser/chromium && printf '%s' \"$PLAYWRIGHT_BROWSER_PATH\"")
                :directory workspace :allow-failure t)
             (ok (zerop status) err)
             (ok (equal ".missing-browser/chromium" out))))
      (remove-directory workspace))))

(deftest environment-is-protected-but-not-product
  (let ((workspace (temporary-directory "environment-evidence")))
    (unwind-protect
         (progn
           (prepare workspace (dict "environmentProfile" "lint"
                                    "scenario" (dict "name" "missing-tool")))
           (let* ((manifest (dict))
                  (vars (dict "environmentManifest" manifest
                              "checks" (vector "files/preserved"))))
             (dolist (path '(".eval-shell-env" ".eval-environment.json" ".eval-fixture.json"))
               (setf (gethash path manifest) (file-metadata (at workspace path)))
               (ok (not (product-path-p path))))
             (labels ((evaluate ()
                        (multiple-value-bind (files artifacts) (collect-files workspace)
                          (grade (dict "files" files "artifacts" artifacts "skillRead" 'yason:false)
                                 vars))))
               (ok (true-p (field (evaluate) "pass")))
               (write-text (at workspace ".eval-shell-env") "tampered")
               (ok (not (true-p (field (evaluate) "pass"))))
               (delete-file (at workspace ".eval-fixture.json"))
               (ok (not (true-p (field (evaluate) "pass")))))))
      (remove-directory workspace))))

(deftest shell-policy-rejects-symlink-and-code
  (let ((workspace (temporary-directory "invalid-shell-policy")))
    (unwind-protect
         (progn
           (run-command '("git" "init" "--quiet") :directory workspace)
           (write-text (at workspace ".eval-shell-env")
                       (format nil "UNEXPECTED=$(touch injected)~C" (code-char 0)))
           (multiple-value-bind (out err status)
               (run-command (list (uiop:getenv "SKILL_EVAL_SHELL") "-lc" "true")
                            :directory workspace :allow-failure t)
             (declare (ignore out err)) (ok (= 2 status)))
           (ok (not (probe-file (at workspace "injected"))))
           (delete-file (at workspace ".eval-shell-env"))
           (write-text (at workspace "actual-policy") "")
           (run-command '("ln" "-s" "actual-policy" ".eval-shell-env") :directory workspace)
           (multiple-value-bind (out err status)
               (run-command (list (uiop:getenv "SKILL_EVAL_SHELL") "-lc" "true")
                            :directory workspace :allow-failure t)
             (declare (ignore out err)) (ok (= 2 status))))
      (remove-directory workspace))))


(deftest browser-bootstrap-uses-pinned-python-and-preserves-existing-files
  (dolist (scenario '("smoke" "missing-browser"))
    (let* ((workspace (temporary-directory "browser-bootstrap"))
           (skill (at (root) "plugins/tools/skills/nix-shell-playwright/")))
      (unwind-protect
           (progn
             (prepare workspace (dict "environmentProfile" "playwright"
                                      "scenario" (dict "name" scenario)))
             (write-text (at workspace "index.html") "<!doctype html><title>Fixture</title><h1>Browser fixture</h1>")
             (run-command (list "qlot" "exec" "bash"
                                (namestring (at skill "scripts/bootstrap_python_playwright_nix.sh")) ".")
                          :directory workspace)
             (let ((before (digest-file (at workspace "shell.nix"))))
               (multiple-value-bind (out err status)
                   (run-command (list "qlot" "exec" "bash"
                                      (namestring (at skill "scripts/bootstrap_python_playwright_nix.sh")) ".")
                                :directory workspace :allow-failure t)
                 (declare (ignore out))
                 (ok (= 2 status))
                 (ok (search "Refusing to overwrite" err)))
               (ok (equal before (digest-file (at workspace "shell.nix")))))
             (run-command (list "qlot" "exec" "python3"
                                (namestring (at skill "scripts/generate_static_smoke_test.py"))
                                "--output" "smoke_test.py" "--paths" "index.html")
                          :directory workspace)
             (multiple-value-bind (out err status)
                 (run-command (list (uiop:getenv "SKILL_EVAL_SHELL") "-lc" "./run_smoke_test.sh")
                              :directory workspace :timeout 120 :allow-failure t)
               (let ((output (concatenate 'string out err)))
                 (ok (not (search "unsupportedPython" output)))
                 (if (equal scenario "missing-browser")
                     (progn
                       (ok (not (zerop status)))
                       (ok (search "doesn't exist" output) output)
                       (ok (not (probe-file (at workspace "test-shots/index.png")))))
                     (progn
                       (ok (zerop status) output)
                       (ok (probe-file (at workspace "test-shots/index.png")))
                       (ok (probe-file (at workspace "test-shots/index-mobile.png"))))))))
        (remove-directory workspace)))))
