;;;; Rove must execute package-inferred tests under isolated FASL translations.
(uiop:define-package #:40ants-ai-skills-tests/rove-discovery-test
  (:use #:cl)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:rove #:deftest #:ok #:testing)
  (:import-from #:40ants-ai-evals/environments #:prepare)
  (:import-from #:40ants-ai-evals/util
                #:at #:root #:write-text #:copy-directory #:run-command
                #:temporary-directory #:remove-directory #:unique-id))
(in-package #:40ants-ai-skills-tests/rove-discovery-test)

(-> prepare-test-project (pathname string)
    t)
(defun prepare-test-project (workspace scenario)
  "Construct a real package-inferred test system with a controlled implementation."
  (copy-directory (at (root) "evals/testing-with-rove/cases/test-op/fixtures/") workspace)
  (prepare workspace (dict "environmentProfile" "lisp"))
  (write-text (at workspace "demo.asd")
              "(asdf:defsystem \"demo\" :class :package-inferred-system :depends-on (\"demo/src/core\") :in-order-to ((asdf:test-op (asdf:test-op \"demo-tests\"))))")
  (write-text (at workspace "demo-tests.asd")
              "(asdf:defsystem \"demo-tests\" :class :package-inferred-system :pathname \"tests\" :depends-on (\"demo\" \"demo-tests/core-test\") :perform (asdf:test-op (operation system) (declare (ignore operation)) (unless (uiop:symbol-call :rove :run system) (error \"Rove tests failed for ~A\" (asdf:component-name system)))))")
  (write-text (at workspace "tests/core-test.lisp")
              "(uiop:define-package #:demo-tests/core-test (:use #:cl) (:import-from #:rove #:deftest #:ok #:signals) (:import-from #:demo/src/core)) (in-package #:demo-tests/core-test) (deftest positive-count (write-line \"REAL-ROVE-ASSERTIONS\") (ok (= 7 (demo/src/core:positive-count 7))) (ok (signals (demo/src/core:positive-count 0) 'demo/src/core:invalid-count)))")
  (unless (equal scenario "correct")
    (write-text (at workspace "src/core.lisp")
                (concatenate 'string
                  "(uiop:define-package #:demo/src/core (:use #:cl) (:export #:positive-count #:invalid-count)) (in-package #:demo/src/core) (define-condition invalid-count (error) ()) "
                  (if (equal scenario "wrong-return")
                      "(defun positive-count (n) (declare (ignore n)) 99)"
                      "(defun positive-count (n) (if (plusp n) n (error \"unrelated error\")))"))))
  t)

(deftest inferred-test-discovery-and-real-failure-exit-status
  (let* ((outside (temporary-directory "rove-cache-outside"))
         (inside (at (root) (format nil ".evals/verification/rove-cache-inside-~A/" (unique-id)))))
    (unwind-protect
         (dolist (base (list outside inside))
           (testing (namestring base)
             (dolist (scenario '("correct" "wrong-return" "wrong-condition"))
               (testing scenario
                 ;; Distinct source paths avoid dependence on timestamp granularity.
                 (let ((workspace (at base (format nil "~A/" scenario))))
                   (prepare-test-project workspace scenario)
                   (multiple-value-bind (out err status)
                       (run-command '("qlot" "exec" "sbcl" "--non-interactive"
                                      "--eval" "(asdf:test-system \"demo\")")
                                    :directory workspace :timeout 90 :allow-failure t)
                     (ok (search "REAL-ROVE-ASSERTIONS" out) (concatenate 'string out err))
                     (ok (not (search "0 tests completed" out)))
                     (if (equal scenario "correct")
                         (ok (zerop status) err)
                         (progn
                           (ok (not (zerop status)))
                           ;; Dependency/load errors are not a successful negative test.
                           (ok (search "Rove tests failed" err))))))))))
      (remove-directory outside)
      (remove-directory inside))))
