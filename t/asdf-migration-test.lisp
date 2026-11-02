;;;; Fresh-process checks for the package-inferred ASDF systems.
(uiop:define-package #:40ants-ai-evals-tests/asdf-migration-test
  (:use #:cl)
  (:import-from #:serapeum #:->)
  (:import-from #:rove #:deftest #:ok)
  (:import-from #:40ants-ai-evals/util
                #:at #:root #:write-text #:temporary-directory #:remove-directory #:run-command)
  (:import-from #:40ants-ai-evals/runner #:validate-options))
(in-package #:40ants-ai-evals-tests/asdf-migration-test)

(-> system-loading-script (pathname boolean)
    string)
(defun system-loading-script (project-root fail-test-op)
  "Return a fresh-process loader, optionally forcing the test-op failure path."
  (format nil
          (concatenate 'string
                       "(require :asdf)~%"
                       "(asdf:initialize-source-registry `(:source-registry (:directory ~S) "
                       ":ignore-inherited-configuration))~%"
                       "(load ~S :verbose nil :print nil)~%"
                       "(asdf:load-asd #P~S)~%"
                       "(asdf:load-asd #P~S)~%"
                       "(asdf:load-system \"40ants-ai-evals\")~%"
                       "(asdf:load-system \"40ants-ai-evals-tests\")~%"
                       "(unless (and (asdf:find-system \"40ants-ai-evals/util\" nil) "
                       "(null (asdf:find-system \"40ants-ai-evals/src/util\" nil)) "
                       "(find-package \"40ANTS-AI-EVALS/UTIL\") "
                       "(null (find-package \"40ANTS-AI-EVALS/SRC/UTIL\"))) "
                       "(error \"Stale source-prefixed ASDF aliases remain\"))~%"
                       "(unless (and (asdf:find-system \"40ants-ai-evals-tests/history-test\" nil) "
                       "(null (asdf:find-system \"40ants-ai-evals/tests\" nil)) "
                       "(find-package \"40ANTS-AI-EVALS-TESTS/HISTORY-TEST\") "
                       "(null (find-package \"40ANTS-AI-EVALS/TESTS/HISTORY-TEST\"))) "
                       "(error \"Stale tests ASDF aliases remain\"))~%"
                       "~A")
          (namestring project-root)
          (namestring (at project-root ".qlot/setup.lisp"))
          (namestring (at project-root "40ants-ai-evals.asd"))
          (namestring (at project-root "40ants-ai-evals-tests.asd"))
          (if fail-test-op
              (format nil
                      (concatenate 'string
                                   "(let* ((package (find-package \"40ANTS-AI-EVALS-TESTS/SUITE\")) "
                                   "(runner (find-symbol \"RUN-TESTS\" package)))~%"
                                   "  (setf (symbol-function runner) "
                                   "(lambda (system) (declare (ignore system)) nil)))~%"
                                   "(asdf:test-system \"40ants-ai-evals-tests\")~%"))
              (format nil "(format t ~S)~%" "COLD_SYSTEMS_LOADED"))))

(-> check-pack-loading-script (pathname string string)
    string)
(defun check-pack-loading-script (project-root system asd-path)
  "Return a fresh-process loader for one check pack without loading the main system."
  (format nil
          (concatenate 'string
                       "(require :asdf)~%"
                       "(asdf:initialize-source-registry `(:source-registry (:directory ~S) "
                       ":ignore-inherited-configuration))~%"
                       "(load ~S :verbose nil :print nil)~%"
                       "(asdf:load-asd #P~S)~%"
                       "(asdf:load-asd #P~S)~%"
                       "(asdf:load-system ~S)~%"
                       "(let ((version (asdf:component-version (asdf:find-system ~S))))~%"
                       "  (unless (equal version ~S)~%"
                       "    (error \"Check-pack version differs from the main system: ~~S\" version)))~%"
                       "(format t ~S)~%")
          (namestring project-root)
          (namestring (at project-root ".qlot/setup.lisp"))
          (namestring (at project-root "40ants-ai-evals.asd"))
          (namestring (at project-root asd-path))
          system system (asdf:component-version (asdf:find-system "40ants-ai-evals"))
          (format nil "CHECK_PACK_LOADED:~A" system)))

(deftest cold-asdf-system-loading
  (let ((scratch (temporary-directory "asdf-cold-load")))
    (unwind-protect
         (let* ((script (at scratch "load-systems.lisp"))
                (argv (list "sbcl" "--script" (namestring script)))
                (output nil) (errors nil) (status nil))
           (write-text script (system-loading-script (root) nil))
           (multiple-value-setq (output errors status)
             (run-command argv :directory (root) :timeout 120 :allow-failure t))
           (ok (= 0 status) (format nil "Fresh ASDF load failed: ~A" errors))
           (ok (search "COLD_SYSTEMS_LOADED" output)))
      (remove-directory scratch))))

(deftest standalone-check-pack-loading
  (dolist (check-pack '(("40ants-ai-evals-common-checks"
                         "evals/checks/common/40ants-ai-evals-common-checks.asd")
                        ("40ants-ai-evals-common-lisp-checks"
                         "evals/checks/writing-common-lisp/40ants-ai-evals-common-lisp-checks.asd")))
    (let* ((system (first check-pack))
           (asd-path (second check-pack))
           (scratch (temporary-directory "standalone-check-pack")))
      (unwind-protect
           (let* ((script (at scratch "load-check-pack.lisp"))
                  (argv (list "sbcl" "--script" (namestring script))))
             (write-text script (check-pack-loading-script (root) system asd-path))
             (multiple-value-bind (output errors status)
                 (run-command argv :directory (root) :timeout 120 :allow-failure t)
               (ok (= 0 status) (format nil "Fresh standalone load of ~A failed: ~A"
                                        system errors))
               (ok (search (format nil "CHECK_PACK_LOADED:~A" system) output))))
        (remove-directory scratch)))))

(deftest test-op-fails-on-false-result
  (let ((scratch (temporary-directory "asdf-test-op-failure")))
    (unwind-protect
         (let* ((script (at scratch "test-op-failure.lisp"))
                (argv (list "sbcl" "--script" (namestring script)))
                (errors nil) (status nil))
           (write-text script (system-loading-script (root) t))
           (multiple-value-bind (output error-output process-status)
               (run-command argv :directory (root) :timeout 120 :allow-failure t)
             (declare (ignore output))
             (setf errors error-output status process-status))
           (ok (/= 0 status))
           (ok (search "Eval harness tests failed" errors)))
      (remove-directory scratch))))

(deftest snapshot-contains-inferred-test-sources
  (let ((scratch (temporary-directory "asdf-snapshot")))
    (unwind-protect
         (let ((harness (progn
                          (validate-options (serapeum:dict))
                          (40ants-ai-evals/runner::snapshot scratch (serapeum:dict)))))
           (ok (probe-file (at harness "t/asdf-migration-test.lisp")))
           (ok (probe-file (at harness "t/suite.lisp")))
           (ok (probe-file (at harness "src/case-resources.lisp")))
           (ok (probe-file (at harness "evals/defining-clos-classes/cases/optional-string/assertions.lisp")))
           (ok (probe-file (at harness "evals/defining-clos-classes/cases/optional-string/fixtures/src/session.lisp")))
           (ok (probe-file (at harness "t/fixtures/case-resources/pixel.png")))
           (ok (probe-file (at harness "40ants-ai-evals-tests.asd")))
           (ok (probe-file (at harness "docs/changelog.lisp")))
           (ok (probe-file (at harness "40ants-ai-evals.asd"))))
      (remove-directory scratch))))
