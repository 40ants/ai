;;;; Frozen known-good and known-bad examples from the original 22 test groups.
(uiop:define-package #:40ants-ai-evals/tests/grading/contracts-test
  (:use #:cl)
  (:import-from #:rove #:deftest #:testing #:ok)
  (:import-from #:40ants-ai-evals/src/util #:read-json #:field #:root #:at #:true-p)
  (:import-from #:40ants-ai-evals/src/grading/contracts #:grade))
(in-package #:40ants-ai-evals/tests/grading/contracts-test)

(deftest calibration-parity
  (loop for example across (concatenate 'vector
                            (read-json (at (root) "tests/calibration.json"))
                            (read-json (at (root) "tests/model-regressions.json")))
        for index from 0
        for expected = (field example "expected")
        for actual = (grade (field example "sample")
                           (40ants-ai-evals/src/runner:grading-vars (field example "vars"))) do
    (testing (format nil "Frozen example ~D" index)
      (ok (eq (true-p (field expected "pass")) (true-p (field actual "pass"))))
      (ok (< (abs (- (field expected "score") (field actual "score"))) 1d-12))
      ;; SBCL diagnostic text includes the checker's package name; preserve the
      ;; functional failure ID without treating that incidental text as contract.
      (ok (if (uiop:string-prefix-p "functional:" (field expected "reason"))
              (uiop:string-prefix-p "functional:" (field actual "reason"))
              (equal (field expected "reason") (field actual "reason")))))))
