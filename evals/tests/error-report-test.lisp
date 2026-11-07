;;;; Error-report contracts must accept custom conditions and reject fake context.
(uiop:define-package #:40ants-ai-skills-tests/error-report-test
  (:use #:cl)
  (:import-from #:yason)
  (:import-from #:rove #:deftest #:testing #:ok)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:40ants-ai-evals/util #:field #:true-p)
  (:import-from #:40ants-ai-evals/grading/contracts #:grade)
  (:import-from #:40ants-ai-evals/runner #:grading-vars))
(in-package #:40ants-ai-skills-tests/error-report-test)

(-> grade-error-source (string string)
    hash-table)
(defun grade-error-source (definitions expression)
  (let* ((source
           (format nil "(uiop:define-package #:demo/src/validation
  (:use #:cl)
  (:import-from #:serapeum #:->)
  (:export #:ensure-positive))
(in-package #:demo/src/validation)
~A
(-> ensure-positive (real)
    (values real &optional))
(defun ensure-positive (value)
  ~S
  (if (plusp value)
      value
      ~A))
" definitions "Return positive VALUE unchanged, otherwise report the rejected input." expression))
         (vars (grading-vars
                (dict "file" "src/validation.lisp" "package" "demo/src/validation"
                      "function" "ensure-positive" "runtime" "ensure-positive"
                      "requireFormattedError" 'yason:true "shouldTrigger" 'yason:true))))
    (grade (dict "files" (dict "src/validation.lisp" source) "skillRead" 'yason:true) vars)))

(deftest actual-error-reports-cover-simple-and-custom-conditions
  (dolist (example
           (list
            (list "" "(error \"Rejected: ~A\" value)" t)
            (list "" "(error 'simple-error :format-control \"Rejected: ~A\" :format-arguments (list value))" t)
            (list "(define-condition rejected-value (error)
  ((value :initarg :value :reader rejected-value-input))
  (:report (lambda (condition stream)
             (format stream \"Rejected: ~A\" (rejected-value-input condition)))))"
                  "(error 'rejected-value :value value)" t)
            (list "" "(error \"Rejected: ~A\" -7)" nil)
            (list "" "(error \"Rejected input\")" nil)
            (list "(defun unrelated () (error \"Unrelated: ~A\" -7))"
                  "(error 'simple-error :format-control \"No input\" :format-arguments nil)" nil)
            (list "" "value" nil)
            (list "(define-condition rejected-value (error) ()
  (:report (lambda (condition stream)
             (declare (ignore condition)) (write-string \"Rejected: -7\" stream))))"
                  "(error 'rejected-value)" nil)))
    (destructuring-bind (definitions expression expected) example
      (testing expression
        (let* ((result (grade-error-source definitions expression))
               (check (find "cl/formatted-error-present" (field result "checks")
                            :key (lambda (check) (field check "checkId")) :test #'equal)))
          (ok (eq expected (true-p (field check "pass"))))
          (ok (eq expected (true-p (field result "pass"))) (field result "reason")))))))
