;;;; Documentation builds need a real local revision, not an installed CLI wrapper.
(uiop:define-package #:40ants-ai-evals-tests/docs-environment-test
  (:use #:cl)
  (:import-from #:rove #:deftest #:ok)
  (:import-from #:serapeum #:dict)
  (:import-from #:40ants-ai-evals/environments #:prepare #:ensure-git-baseline)
  (:import-from #:40ants-ai-evals/util
                #:at #:root #:field #:temporary-directory #:remove-directory
                #:copy-directory #:run-command #:digest-file #:write-text))
(in-package #:40ants-ai-evals-tests/docs-environment-test)

(deftest deterministic-docs-checkouts-build-with-pinned-library
  (let* ((scratch (temporary-directory "docs-environment-test"))
         (first (at scratch "first/")) (second (at scratch "second/"))
         (fixture (at (root) "evals/writing-40ants-doc-documentation/cases/smoke/fixtures/"))
         (original (digest-file (at fixture "README.md"))))
    (unwind-protect
         (progn
           (copy-directory fixture first)
           (copy-directory fixture second)
           ;; Exercise both an existing empty repository and no repository.
           (run-command '("git" "init" "--quiet") :directory first)
           (let* ((a (prepare first (dict "environmentProfile" "docs")))
                  (b (prepare second (dict "environmentProfile" "docs")))
                  (revision (field a "gitBaseline")))
             (ok (> (length revision) 20))
             (ok (equal revision (field b "gitBaseline")))
             (ok (probe-file (at first ".git/HEAD")))
             (ok (probe-file (at second ".git/HEAD")))
             (multiple-value-bind (out err status)
                 (run-command
                  '("qlot" "exec" "sbcl" "--non-interactive"
                    "--eval" "(asdf:load-system \"docs-builder\")"
                    "--eval" "(docs-builder:build \"demo-docs\" :error-on-warnings t :local t)")
                  :directory first :timeout 120 :allow-failure t)
               (ok (zerop status) err)
               (ok (not (search "WARNING:" (concatenate 'string out err))))
               (ok (probe-file (at first ".eval-cache/lisp-startup.log"))))
             (ok (search "deterministic queue" (uiop:read-file-string (at first "README.md"))
                         :test #'char-equal))
             (ok (probe-file (at first "docs/build/index.html")))
             (ok (equal original (digest-file (at second "README.md"))))
             (ok (equal original (digest-file (at fixture "README.md"))))
             ;; A real unresolved reference must still fail the same strict entry point.
             (let* ((file (at first "docs/index.lisp"))
                    (source (uiop:read-file-string file))
                    (position (search "background jobs" source)))
               (write-text file (concatenate 'string (subseq source 0 position)
                                             "MISSINGDOCREF " (subseq source position)))
               (multiple-value-bind (out err status)
                   (run-command
                    '("qlot" "exec" "sbcl" "--non-interactive"
                      "--eval" "(asdf:load-system \"docs-builder\")"
                      "--eval" "(docs-builder:build \"demo-docs\" :error-on-warnings t :local t)")
                    :directory first :timeout 120 :allow-failure t)
                 (ok (not (zerop status)))
                 (ok (search "MISSINGDOCREF" (concatenate 'string out err)))))
             ;; Calling setup after edits must keep the existing revision intact.
             (ok (equal revision (ensure-git-baseline first)))))
      (remove-directory scratch))))

(deftest docs-baseline-is-local-and-supports-empty-projects
  (let* ((parent (temporary-directory "docs-git-parent"))
         (child (at parent "child/")))
    (unwind-protect
         (progn
           (write-text (at parent "README.md") "parent checkout")
           (ensure-git-baseline parent '("README.md"))
           (ensure-directories-exist child)
           (let ((head (ensure-git-baseline child)))
             (ok (> (length head) 20))
             (ok (probe-file (at child ".git/HEAD")))
             (ok (equal (namestring (truename child))
                        (namestring (uiop:ensure-directory-pathname
                         (string-trim '(#\Space #\Newline #\Return)
                                      (run-command '("git" "rev-parse" "--show-toplevel")
                                                   :directory child))))))))
      (remove-directory parent))))
