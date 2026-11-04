;;;; Fractional credit is separate from mandatory pass/fail decisions.
(uiop:define-package #:40ants-ai-skills-tests/graded-scoring-test
  (:use #:cl)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:rove #:deftest #:testing #:ok #:signals)
  (:import-from #:yason)
  (:import-from #:40ants-ai-evals/util #:field #:true-p #:at #:read-json #:write-json
                #:run-command #:temporary-directory #:remove-directory)
  (:import-from #:40ants-ai-evals/checks #:register-check #:outcome)
  (:import-from #:40ants-ai-evals/grading/contracts #:grade)
  (:import-from #:40ants-ai-evals/runner #:grading-vars))
(in-package #:40ants-ai-skills-tests/graded-scoring-test)

(-> graded-handler (hash-table hash-table)
    hash-table)
(defun graded-handler (context params)
  (declare (ignore context))
  ;; Deliberately return a raw extension result to exercise validation too.
  (dict "name" "graded" "pass" (field params "pass")
        "score" (field params "score")))

(-> boolean-handler (hash-table hash-table)
    hash-table)
(defun boolean-handler (context params)
  (declare (ignore context))
  (dict "name" "legacy" "pass" (field params "pass")))

(register-check "tests/graded-score" 'graded-handler
                :parameters (dict "pass" "boolean" "score" "any"))
(register-check "tests/boolean-score" 'boolean-handler
                :parameters (dict "pass" "boolean"))

(-> graded-spec (t t)
    hash-table)
(defun graded-spec (pass score)
  (dict "check" "tests/graded-score" "params" (dict "pass" pass "score" score)))

(deftest fractional-aggregation-and-hard-failures
  (let* ((sample (dict "files" (dict) "skillRead" 'yason:false))
         (full (dict "check" "tests/boolean-score" "params" (dict "pass" 'yason:true)))
         (partial (grade sample (dict "checks" (vector full (graded-spec 'yason:true 0.5))))))
    (ok (true-p (field partial "pass")))
    (ok (= 0.75 (field partial "score")))
    (ok (search "graded=0.5" (field partial "reason")))
    (ok (= 1 (field (aref (field partial "checks") 0) "score")))
    (let ((failed (grade sample (dict "checks" (vector full (graded-spec 'yason:false 0.5))))))
      (ok (not (true-p (field failed "pass"))))
      (ok (= 0.75 (field failed "score"))))))

(deftest outcome-score-validation
  (ok (= 1 (field (outcome "legacy" t) "score")))
  (ok (= 0 (field (outcome "legacy" nil) "score")))
  (ok (= 0.5 (field (outcome "partial" t :score 1/2 :reason "Partial") "score")))
  (ok (equal "Partial" (field (outcome "partial" t :score 0.5 :reason "Partial") "reason")))
  (dolist (value (list -0.1 1.1 "0.5" 'yason:true :null))
    (ok (signals (apply #'outcome (list "bad" t :score value))))
    (ok (signals
          (grade (dict "files" (dict) "skillRead" 'yason:false)
                 (dict "checks" (vector (graded-spec 'yason:true value))))))))

(-> source-with-signature (string)
    string)
(defun source-with-signature (signature)
  (format nil "(uiop:define-package #:demo/src/models/score
  (:use #:cl)
  (:import-from #:serapeum #:->)
  (:export #:add-score))
(in-package #:demo/src/models/score)
~A
(defun add-score (a b)
  \"Return the sum of A and B.\"
  (+ a b))
" signature))

(-> grade-signature-source (string)
    hash-table)
(defun grade-signature-source (signature)
  (let ((vars (grading-vars
               (dict "file" "src/models/score.lisp" "package" "demo/src/models/score"
                     "function" "add-score" "runtime" "add-score" "shouldTrigger" 'yason:true))))
    (grade (dict "files" (dict "src/models/score.lisp" (source-with-signature signature))
                 "skillRead" 'yason:true) vars)))

(deftest three-level-return-layout
  (dolist (case (list
                (list "" 0 nil)
                (list "; (-> add-score (integer integer) (values integer &optional))" 0 nil)
                (list "(-> add-score (integer integer) (values integer &optional))" 0.5 t)
                (list (format nil "(-> add-score (integer integer)~%    (values integer &optional))") 1 t)
                (list (format nil "(-> add-score (integer integer)~%  (values integer &optional))") 1 t)
                (list (format nil "(-> add-score (integer integer)~%(values integer &optional))") 1 t)
                (list (format nil "(serapeum:-> add-score~%    (integer integer) (values integer &optional))") 0.5 t)
                (list "(-> other-function () (values integer &optional))" 0 nil)))
    (destructuring-bind (signature expected pass) case
      (testing signature
        (let* ((result (grade-signature-source signature))
               (layout (find "cl/return-type-layout" (field result "checks")
                             :key (lambda (item) (field item "checkId")) :test #'equal)))
          (ok (= expected (field layout "score")))
          (ok (eq pass (true-p (field layout "pass"))))
          (ok (eq pass (true-p (field result "pass"))))
          (when (= expected 0.5)
            (ok (< (abs (- (field result "score") (/ 17.5d0 18))) 1d-12))))))))


(deftest promptfoo-preserves-fractional-pass
  (let* ((scratch (temporary-directory "graded-promptfoo"))
         (config (at scratch "promptfooconfig.json"))
         (export (at scratch "results.json"))
         (results (vector (outcome "missing" nil :reason "Missing signature")
                          (outcome "inline" t :score 0.5 :reason "Inline return type")
                          (outcome "multiline" t))))
    (unwind-protect
         (progn
           (loop for result across results do
             (unless (field result "reason")
               (setf (gethash "reason" result) "Complete signature")))
           (write-json config
            (dict "description" "Offline fractional scoring transport; no model calls"
                  "providers" (vector "echo") "prompts" (vector "score transport")
                  "defaultTest" (dict "assert"
                                      (vector (dict "type" "javascript" "metric" "Layout"
                                                    "value" "context.vars.grading")))
                  "tests" (map 'vector (lambda (result)
                                         (dict "vars" (dict "grading" result))) results)))
           (multiple-value-bind (out err code)
               (run-command
                (list "qlot" "exec" "env"
                      (format nil "PROMPTFOO_CONFIG_DIR=~A" (at scratch "state/"))
                      "promptfoo" "eval" "-c" (namestring config) "-o" (namestring export)
                      "--no-cache" "--no-share" "--no-table" "--max-concurrency" "1")
                :directory scratch :timeout 60 :allow-failure t)
             (declare (ignore out))
             (ok (not (zerop code)) "The missing-signature sample must fail.")
             (ok (probe-file export) err)
             (when (probe-file export)
               (let* ((body (field (read-json export) "results"))
                      (rows (if (hash-table-p body) (field body "results") body)))
                 (ok (= 3 (length rows)))
                 (loop for row across rows
                       for expected = (or (field row "testCase" "vars" "grading")
                                          (field row "vars" "grading")) do
                   (ok (eq (true-p (field expected "pass")) (true-p (field row "success"))))
                   (ok (= (field expected "score") (field row "score"))))))))
      (remove-directory scratch))))
