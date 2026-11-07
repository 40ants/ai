;;;; Test system for 40ants-ai-evals.
(asdf:defsystem "40ants-ai-skills-tests"
  :class :package-inferred-system
  :pathname "evals/tests/"
  :description "Offline and deterministic tests for 40ants-ai-evals"
  :author "Alexander Artemenko"
  :license "Unlicense"
  :homepage "https://github.com/40ants/ai"
  :source-control (:git "https://github.com/40ants/ai")
  :bug-tracker "https://github.com/40ants/ai/issues"
  :depends-on ("40ants-ai-evals"
               "rove"
               "40ants-ai-skills-tests/suite")
  :perform (asdf:test-op (operation system)
             (declare (ignore operation))
             (unless (uiop:symbol-call '#:40ants-ai-skills-tests/suite '#:run-tests system)
               (error "Eval harness tests failed: ~A" system))))
