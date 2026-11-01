;;;; Project-local eval orchestration, with dependencies inferred from packages.
(asdf:defsystem "40ants-ai-evals"
  :description "Reproducible skill evaluations through Promptfoo"
  :author "Alexander Artemenko"
  :license "Unlicense"
  :homepage "https://github.com/40ants/ai"
  :source-control (:git "https://github.com/40ants/ai")
  :bug-tracker "https://github.com/40ants/ai/issues"
  :class :40ants-asdf-system
  :defsystem-depends-on ("40ants-asdf-system")
  :pathname "src"
  :depends-on ("40ants-ai-evals/cli")
  :in-order-to ((asdf:test-op (asdf:test-op "40ants-ai-evals-tests"))))
