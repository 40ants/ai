;;;; Project-local eval orchestration and grading.
(asdf:defsystem "40ants-ai-evals"
  :description "Reproducible skill evaluations through Promptfoo"
  :version "0.1.0"
  :depends-on ("serapeum" "yason" "ironclad" "babel" "local-time" "cl-ppcre")
  :serial t
  :components ((:file "src/util")
               (:file "src/checks")
               (:file "src/grading/contracts")
               (:file "src/collector")
               (:file "src/history")
               (:file "src/runner")
               (:file "src/cli"))
  :in-order-to ((asdf:test-op (asdf:test-op "40ants-ai-evals/tests"))))

(asdf:defsystem "40ants-ai-evals/tests"
  :depends-on ("40ants-ai-evals" "rove" "40ants-ai-evals-common-checks"
               "40ants-ai-evals-common-lisp-checks")
  :serial t
  :components ((:file "tests/grading/contracts-test")
               (:file "tests/collector-test")
               (:file "tests/history-test")
               (:file "tests/checks-test"))
  :perform (asdf:test-op (op system)
             (declare (ignore op))
             (unless (uiop:symbol-call '#:rove '#:run system)
               (error "Eval harness tests failed: ~A" system))))
