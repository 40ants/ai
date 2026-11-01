;;;; History compatibility and coverage checks do not require model calls.
(uiop:define-package #:40ants-ai-evals-tests/history-test
  (:use #:cl)
  (:import-from #:serapeum #:dict)
  (:import-from #:rove #:deftest #:ok #:signals)
  (:import-from #:40ants-ai-evals/util #:decode #:encode #:field #:true-p #:json-equal-p)
  (:import-from #:40ants-ai-evals/history
                #:make-summary #:find-run #:compare-runs #:print-summary))
(in-package #:40ants-ai-evals-tests/history-test)

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
         (sample (dict "variant" "with-skill"
                       "usage" (dict "input_tokens" 20 "output_tokens" 5 "total_tokens" 38)
                       "commandCount" 2 "skillRead" 'yason:false))
         (result (dict "testCase" (dict "vars" (dict "id" "one")) "success" 'yason:true
                       "response" (dict "output" (encode sample)) "latencyMs" 12))
         (legacy (make-summary manifest (dict "results" (vector result)) 0)))
    (setf (gethash "response" result)
          (dict "metadata" (dict "skillEval" sample) "output" "done"))
    (let ((native (make-summary manifest (dict "results" (dict "results" (vector result))) 0)))
      (ok (json-equal-p legacy native))
      (ok (true-p (field native "coverageComplete")))
      (ok (= 38 (field native "variants" "with-skill" "medianTokens"))))
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

(deftest multi-agent-coverage-and-legacy-labels
  (let* ((manifest (dict "cases" #("one") "repeat" 1 "variants" #("with-skill")
                         "agents" #("codex" "opencode")
                         "profiles" (dict "codex" (dict "agent" "codex" "model" "m1")
                                          "opencode" (dict "agent" "opencode" "model" "m2"))))
         (codex (dict "testCase" (dict "vars" (dict "id" "one"))
                      "provider" (dict "label" "codex-cli:with-skill")
                      "success" 'yason:true
                      "response" (dict "metadata" (dict "skillEval"
                                                         (dict "variant" "with-skill")))))
         (opencode (dict "testCase" (dict "vars" (dict "id" "one"))
                         "provider" (dict "label" "opencode:with-skill")
                         "success" 'yason:true
                         "response" (dict "metadata" (dict "skillEval"
                                                            (dict "agent" "opencode"
                                                                  "variant" "with-skill"
                                                                  "profile" (dict "model" "m2"))))))
         (summary (make-summary manifest (dict "results" (vector codex opencode)) 0)))
    (ok (= 2 (field summary "expected")))
    (ok (true-p (field summary "coverageComplete")))
    (ok (equal "codex" (field (aref (field summary "rows") 0) "agent")))
    (ok (= 1 (field summary "agentVariants" "opencode" "with-skill" "total")))
    (ok (= 1 (field summary "variants" "with-skill" "total")))
    (ok (equal "m2" (field (aref (field summary "rows") 1) "profile" "model")))
    (ok (eq :null (field (aref (field summary "rows") 0) "tokens")))
    (ok (eq :null (field (aref (field summary "rows") 0) "cachedInputTokens")))))

(deftest agent-profile-compatibility
  (let* ((profile (dict "agent" "codex" "model" "same" "effort" "high"
                        "tools" (dict "codex" "v1")))
         (before (dict "id" "before" "label" "run" "suiteHash" "suite"
                       "skillHash" "same-skill"
                       "profiles" (dict "codex" profile
                                        "opencode" (dict "agent" "opencode" "model" "m2"
                                                         "mode" "auto" "timeout" 120
                                                         "evaluationTimeoutMs" 500
                                                         "executionTimeoutMs" 30000
                                                         "tools" (dict "opencode" "v1")))
                       "tools" (dict "codex" "v1" "opencode" "old")
                       "rows" (vector (dict "case" "one" "variant" "codex-cli:with-skill"
                                            "pass" 'yason:true))))
         (after (dict "id" "after" "label" "run" "suiteHash" "suite"
                      "skillHash" "same-skill"
                      "profiles" (dict "codex" profile
                                       "opencode" (dict "agent" "opencode" "model" "m2"
                                                        "mode" "auto" "timeout" 120
                                                        "evaluationTimeoutMs" 500
                                                        "executionTimeoutMs" 30000
                                                        "tools" (dict "opencode" "v1")))
                      "tools" (dict "codex" "v1" "opencode" "new")
                      "rows" (vector (dict "case" "one" "variant" "codex-cli:with-skill"
                                           "pass" 'yason:true)))))
    (ok (not (signals (compare-runs before after :agent "codex"))))
    (ok (not (signals (compare-runs before after))))
    (ok (not (signals (compare-runs before after
                                     :before-agent "codex" :after-agent "opencode"))))
    (ok (signals (compare-runs before after :agent "gemini")))
    (setf (gethash "skillHash" after) "changed-skill")
    (ok (not (signals (compare-runs before after :agent "codex"))))
    (ok (signals (compare-runs before after
                               :before-agent "codex" :after-agent "opencode")))
    (setf (gethash "skillHash" after) "same-skill")
    (setf (gethash "evaluationTimeoutMs" (gethash "opencode" (gethash "profiles" after))) 501)
    (ok (signals (compare-runs before after :agent "opencode")))
    (setf (gethash "evaluationTimeoutMs" (gethash "opencode" (gethash "profiles" after))) 500)
    (setf (gethash "executionTimeoutMs" (gethash "opencode" (gethash "profiles" after))) 30001)
    (ok (signals (compare-runs before after :agent "opencode")))
    (setf (gethash "executionTimeoutMs" (gethash "opencode" (gethash "profiles" after))) 30000)
    (setf (gethash "timeout" (gethash "opencode" (gethash "profiles" after))) 121)
    (ok (signals (compare-runs before after :agent "opencode")))
    (setf (gethash "profiles" after)
          (dict "codex" (dict "agent" "codex" "model" "different" "effort" "high"
                              "tools" (dict "codex" "v1"))))
    (ok (signals (compare-runs before after :agent "codex")))))

(deftest opencode-only-summary
  (let* ((manifest (dict "id" "opencode-run" "label" "opencode" "cases" #("one")
                         "repeat" 1 "variants" #("with-skill") "agents" #("opencode")
                         "profiles" (dict "opencode" (dict "agent" "opencode" "model" "m2"))))
         (result (dict "testCase" (dict "vars" (dict "id" "one"))
                       "provider" (dict "label" "opencode:with-skill")
                       "success" 'yason:true
                       "response" (dict "metadata" (dict "skillEval"
                                                          (dict "agent" "opencode"
                                                                "variant" "with-skill")))))
         (summary (make-summary manifest (dict "results" (vector result)) 0))
         (printed (with-output-to-string (output)
                    (let ((*standard-output* output))
                      (print-summary summary))))
         (row (aref (field summary "rows") 0)))
    (ok (= 1 (field summary "variants" "with-skill" "total")))
    (ok (= 1 (field summary "agentVariants" "opencode" "with-skill" "total")))
    (ok (search "opencode:with-skill: 1/1 passed" printed))
    (ok (equal "m2" (field row "profile" "model")))))

(deftest print-history-agent-filter
  (let* ((codex (dict "id" "codex-run" "label" "codex" "expected" 33
                      "agents" #("codex") "profiles" (dict "codex" (dict "model" "codex-model"))
                      "rows" (vector (dict "case" "one" "agent" "codex" "pass" 'yason:true))))
         (opencode (dict "id" "opencode-run" "label" "opencode" "expected" 1
                         "agents" #("opencode")
                         "profiles" (dict "opencode" (dict "model" "opencode-model"))
                         "rows" (vector (dict "case" "one" "agent" "opencode" "pass" 'yason:true))))
         (printed (with-output-to-string (output)
                    (let ((*standard-output* output))
                      (40ants-ai-evals/history::print-history-runs
                       (list codex opencode) "opencode")))))
    (ok (not (search "codex-run" printed)))
    (ok (search "opencode-run  opencode  opencode-model  1/1 passed" printed))
    (ok (signals (40ants-ai-evals/history::print-history-runs
                  (list codex opencode) "gemini")))))

(deftest cross-agent-displays-selected-statistics
  (let* ((run (dict "id" "same" "label" "run" "agents" #("codex" "opencode")
                    "skillHash" "skill"
                    "agentVariants"
                    (dict "codex" (dict "with-skill" (dict "medianTokens" 111))
                          "opencode" (dict "with-skill" (dict "medianTokens" 222)))))
         (output (with-output-to-string (*standard-output*)
                   (compare-runs run run :before-agent "codex" :after-agent "opencode"))))
    (ok (search "run [codex]:" output))
    (ok (search "run [opencode]:" output))
    (ok (search "111" output))
    (ok (search "222" output))))
