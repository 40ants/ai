;;;; This extension is deliberately separate from the core ASDF definition.
(asdf:defsystem "40ants-ai-evals-example-check"
  :version "0.1.0"
  :depends-on ("40ants-ai-evals")
  :components ((:file "check")))
