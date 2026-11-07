(asdf:defsystem "40ants-ai-evals-skill-behavior-checks"
  :description "Observable behavior checks for bundled skill evaluation suites"
  :author "Alexander Artemenko"
  :license "Unlicense"
  :homepage "https://github.com/40ants/ai"
  :source-control (:git "https://github.com/40ants/ai")
  :bug-tracker "https://github.com/40ants/ai/issues"
  :class :40ants-asdf-system
  :defsystem-depends-on ("40ants-asdf-system")
  :path-to-changelog "../../../docs/changelog.lisp"
  :path-to-readme "../../../README.md"
  :depends-on ("40ants-ai-evals-skill-behavior-checks/checks"))
