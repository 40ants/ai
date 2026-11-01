;;;; This extension is deliberately separate from the core ASDF definition.
(asdf:defsystem "40ants-ai-evals-example-check"
  :class :package-inferred-system
  :author "Alexander Artemenko"
  :license "Unlicense"
  :version "0.1.0"
  :depends-on ("40ants-ai-evals"
               "40ants-ai-evals-example-check/check"))
