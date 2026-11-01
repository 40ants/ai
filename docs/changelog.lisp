(uiop:define-package #:40ants-ai-evals-docs/changelog
  (:use #:cl)
  (:import-from #:40ants-doc/changelog #:defchangelog))
(in-package #:40ants-ai-evals-docs/changelog)

(defchangelog (:ignore-words ("ASDF" "API" "APM" "Codex" "OpenCode" "Promptfoo"))
  (0.2.0 2026-11-01
         "* Renamed the main system package namespace to `40ants-ai-evals/*` and the
test system and package namespace to `40ants-ai-evals-tests/*`.
* Declared explicit dependencies for evaluation check systems.")
  (0.1.0 2026-11-01
         "* Added the initial Common Lisp skill evaluation harness with Codex
and OpenCode providers and independent checks."))
