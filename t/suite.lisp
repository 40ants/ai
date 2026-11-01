;;;; Load project check extensions and run the package-inferred test system.
(uiop:define-package #:40ants-ai-evals-tests/suite
  (:use #:cl)
  (:import-from #:asdf #:component-name #:find-system #:system-depends-on)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:rove #:run)
  (:import-from #:uiop #:string-prefix-p)
  (:import-from #:40ants-ai-evals/util #:field)
  (:import-from #:40ants-ai-evals/checks #:load-check-systems)
  (:import-from #:40ants-ai-evals/runner #:grading-vars)
  (:import-from #:40ants-ai-evals-tests/agents-test)
  (:import-from #:40ants-ai-evals-tests/asdf-migration-test)
  (:import-from #:40ants-ai-evals-tests/checks-test)
  (:import-from #:40ants-ai-evals-tests/collector-test)
  (:import-from #:40ants-ai-evals-tests/grading/contracts-test)
  (:import-from #:40ants-ai-evals-tests/history-test)
  (:import-from #:40ants-ai-evals-tests/opencode-test)
  (:export #:run-tests))
(in-package #:40ants-ai-evals-tests/suite)

(-> run-tests (t)
    boolean)
(defun run-tests (system)
  "Load configured check extensions before Rove runs the inferred test modules."
  (let ((vars (grading-vars (dict))))
    (load-check-systems (field vars "checkSystems")))
  (let ((test-systems
          (remove-if-not
           (lambda (dependency)
             (and (stringp dependency)
                  (string-prefix-p "40ants-ai-evals-tests/" dependency)
                  (not (string= dependency "40ants-ai-evals-tests/suite"))))
           (system-depends-on
            (find-system "40ants-ai-evals-tests/suite")))))
    (unless test-systems
      (error "No inferred test modules are registered for ~A." (component-name system)))
    (run test-systems)))
