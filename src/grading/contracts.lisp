;;;; Domain-independent grading of a declared, extensible check plan.
(uiop:define-package #:40ants-ai-evals/grading/contracts
  (:use #:cl)
  (:import-from #:40ants-ai-evals/case-resources #:*sample-directory*)
  (:import-from #:yason)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:40ants-ai-evals/util #:field #:true-p #:bool #:decode #:encode)
  (:import-from #:40ants-ai-evals/checks #:make-context #:validate-plan #:execute-plan)
  (:export #:grade))
(in-package #:40ants-ai-evals/grading/contracts)

(-> grade (t hash-table &key (:sample-directory t))
    hash-table)
(defun grade (output vars &key sample-directory)
  "Run the case's registered checks; infrastructure errors propagate to the collector."
  (let ((*sample-directory* (or sample-directory *sample-directory*))
        (sample (if (stringp output)
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
           (failures (remove-if (lambda (check) (true-p (field check "pass"))) checks))
           (partial (remove-if-not
                     (lambda (check)
                       (and (true-p (field check "pass")) (< (field check "score") 1)))
                     checks)))
      (unless checks (error "Check plan produced no outcomes for ~A" (field vars "id")))
      (dict "pass" (bool (and checks (null failures)))
            "score" (float (/ (reduce #'+ checks :key (lambda (check) (field check "score")))
                              (length checks)) 1d0)
            "reason" (if failures
                         (format nil "~{~A~^; ~}"
                                 (mapcar (lambda (check)
                                           (if (field check "reason")
                                               (format nil "~A:~A" (field check "name")
                                                       (field check "reason"))
                                               (field check "name"))) failures))
                         (if partial
                             (format nil "All mandatory checks passed; partial credit: ~{~A~^; ~}"
                                     (mapcar (lambda (check)
                                               (format nil "~A=~A~@[ (~A)~]"
                                                       (field check "name")
                                                       (encode (field check "score"))
                                                       (field check "reason"))) partial))
                             (format nil "~D checks passed" (length checks))))
            "checks" (coerce checks 'vector)))))
