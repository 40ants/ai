;;;; History compatibility and coverage checks do not require model calls.
(uiop:define-package #:40ants-ai-evals/tests/history-test
  (:use #:cl)
  (:import-from #:serapeum #:dict)
  (:import-from #:rove #:deftest #:ok #:signals)
  (:import-from #:40ants-ai-evals/src/util #:decode #:encode #:field #:true-p #:json-equal-p)
  (:import-from #:40ants-ai-evals/src/history #:make-summary #:find-run #:compare-runs))
(in-package #:40ants-ai-evals/tests/history-test)

(deftest json-round-trip
  (let* ((json "{\"null\":null,\"false\":false,\"true\":true,\"array\":[],\"unicode\":\"Суммы 🧮\"}")
         (value (decode json)))
    (ok (eq :null (field value "null")))
    (ok (not (true-p (field value "false"))))
    (ok (true-p (field value "true")))
    (ok (equalp #() (field value "array")))
    (ok (json-equal-p value (decode (encode value))))))

(deftest empty-coverage
  (let ((summary (make-summary
                   (dict "cases" #("one") "repeat" 3 "variants" #("with-skill")) nil 1)))
    (ok (not (true-p (field summary "coverageComplete")))))
  (ok (not (true-p (field (make-summary
                            (dict "cases" #() "repeat" 1 "variants" #("with-skill")) nil 0)
                          "coverageComplete")))))

(deftest legacy-and-native-export
  (let* ((manifest (dict "cases" #("one") "repeat" 1 "variants" #("with-skill")))
         (sample (dict "variant" "with-skill" "usage" (dict "input_tokens" 10 "output_tokens" 5)
                       "commandCount" 2 "skillRead" 'yason:false))
         (result (dict "testCase" (dict "vars" (dict "id" "one")) "success" 'yason:true
                       "response" (dict "output" (encode sample)) "latencyMs" 12))
         (legacy (make-summary manifest (dict "results" (vector result)) 0)))
    (setf (gethash "response" result)
          (dict "metadata" (dict "skillEval" sample) "output" "done"))
    (let ((native (make-summary manifest (dict "results" (dict "results" (vector result))) 0)))
      (ok (json-equal-p legacy native))
      (ok (true-p (field native "coverageComplete")))
      (ok (= 15 (field native "variants" "with-skill" "medianTokens"))))
    (setf (gethash "results" result) #())
    (ok (not (true-p (field (make-summary manifest (dict "results" (vector result result)) 0)
                            "coverageComplete"))))))

(deftest compare-guards
  (let* ((one (dict "id" "one" "label" "same" "suiteHash" "a"))
         (two (dict "id" "two" "label" "same" "suiteHash" "b")))
    (ok (signals (find-run "same" (list one two))))
    (ok (eq two (find-run "latest" (list one two))))
    (ok (signals (compare-runs one two)))))

(deftest infrastructure-errors
  (let* ((manifest (dict "cases" #("one") "repeat" 1 "variants" #("with-skill")))
         (result (dict "testCase" (dict "vars" (dict "id" "one"))
                       "provider" (dict "label" "with-skill")
                       "success" 'yason:false "error" :null
                       "response" (dict "error" "Provider failed")))
         (summary (make-summary manifest (dict "results" (vector result)) 1)))
    (ok (= 1 (field summary "variants" "with-skill" "errors")))
    (ok (equal "Provider failed" (field (aref (field summary "rows") 0) "error")))
    (setf (gethash "response" result)
          (dict "metadata" (dict "skillEval" (dict "variant" "with-skill"
                                                  "infrastructureError" "Lisp timeout"))))
    (let ((updated (make-summary manifest (dict "results" (vector result)) 1)))
      (ok (= 1 (field updated "variants" "with-skill" "errors")))
      (ok (= 0 (field updated "variants" "with-skill" "failed"))))))
