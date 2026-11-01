;;;; Domain-independent grading of a declared, extensible check plan.
(uiop:define-package #:40ants-ai-evals/grading/contracts
  (:use #:cl)
  (:import-from #:yason)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:40ants-ai-evals/util #:field #:true-p #:bool #:decode)
  (:import-from #:40ants-ai-evals/checks #:make-context #:validate-plan #:execute-plan)
  (:export #:grade))
(in-package #:40ants-ai-evals/grading/contracts)

(-> grade (t hash-table)
    hash-table)
(defun grade (output vars)
  "Run the case's registered checks; infrastructure errors propagate to the collector."
  (let ((sample (if (stringp output)
                    (handler-case (decode output)
                      (error () (return-from grade
                                  (dict "pass" 'yason:false "score" 0
                                        "reason" "Provider returned malformed evidence JSON"))))
                    output)))
    (unless (and (hash-table-p (field sample "files"))
                 (member (field sample "skillRead") '(yason:true yason:false)))
      (return-from grade (dict "pass" 'yason:false "score" 0
                               "reason" "Missing files/skill-read evidence")))
    (let* ((context (make-context sample vars))
           (checks (execute-plan context (validate-plan vars)))
           (failures (remove-if (lambda (check) (true-p (field check "pass"))) checks)))
      (unless checks (error "Check plan produced no outcomes for ~A" (field vars "id")))
      (dict "pass" (bool (and checks (null failures)))
            "score" (if checks (float (/ (- (length checks) (length failures))
                                         (length checks)) 1d0) 0)
            "reason" (if failures
                         (format nil "~{~A~^; ~}"
                                 (mapcar (lambda (check)
                                           (if (field check "reason")
                                               (format nil "~A:~A" (field check "name")
                                                       (field check "reason"))
                                               (field check "name"))) failures))
                         (format nil "~D checks passed" (length checks)))
            "checks" (coerce checks 'vector)))))
