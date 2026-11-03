(uiop:define-package #:40ants-ai-evals-docs/changelog
  (:use #:cl)
  (:import-from #:40ants-doc/changelog #:defchangelog))
(in-package #:40ants-ai-evals-docs/changelog)

(defchangelog (:ignore-words ("ASDF" "API" "APM" "Codex" "OpenCode" "Promptfoo" "MCP" "Qlot" "UIOP" "Serapeum"))
  (0.4.2 2026-11-04
         "* Added fractional check scores while preserving mandatory pass decisions.
* Awarded half credit for inline Serapeum return types and full credit for
return types on a separate line. Missing signatures remain failures.")
  (0.4.1 2026-11-04
         "* Isolated sample ASDF system discovery from unrelated fixture projects.
* Added prepared runtime instructions and Qlot execution preflight to all suites.
* Supplied real ASDF project fixtures for the original Lisp writing tasks.
* Routed the prepared agent shell through Qlot for complete compound commands.
* Retained UIOP bootstrap diagnostics in sample logs instead of tool output.")
  (0.4.0 2026-11-02
         "* Moved runtime assertions and fixture projects into per-case files.
* Added binary fixture baselines, executable permission tracking and confined
file parameters for independent check extensions.
* Prepared workspaces and replay inputs from immutable snapshots while retaining
support for historical inline case inputs.")
  (0.3.0 2026-11-01
         "* Added evaluation suites for the remaining eleven project skills and
suite selection, independent behavioral checks, and reproducible tool environments.
* Archived tool calls, binary artifacts, symbolic links, and environment identity.
* Added suite-aware history comparisons and multi-suite batch indexes.
* Preserved provider artifacts across evaluator timeouts and exposed prepared
MCP runners with native tool-result evidence.")
  (0.2.0 2026-11-01
         "* Renamed the main system package namespace to `40ants-ai-evals/*` and the
test system and package namespace to `40ants-ai-evals-tests/*`.
* Declared explicit dependencies for evaluation check systems.")
  (0.1.0 2026-11-01
         "* Added the initial Common Lisp skill evaluation harness with Codex
and OpenCode providers and independent checks."))
