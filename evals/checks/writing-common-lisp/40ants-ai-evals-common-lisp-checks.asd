(asdf:defsystem "40ants-ai-evals-common-lisp-checks"
  :description "Common Lisp reader, runtime and source convention checks"
  :version "0.1.0"
  :depends-on ("40ants-ai-evals")
  :serial t
  :components ((:file "lisp-reader") (:file "checks")))
