<a id="x-2840ANTS-AI-SKILLS-DOCS-2FCHANGELOG-3A-40CHANGELOG-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

# ChangeLog

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FCHANGELOG-3A-3A-7C0-2E5-2E0-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## 0.5.0 (2026-11-04)

* Connected the skill suites to the separately versioned evaluation library.
* Kept fixture environments, calibration tests and skill-specific assertions local.
* Preserved evaluation history while removing the embedded runner implementation.

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FCHANGELOG-3A-3A-7C0-2E4-2E10-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## 0.4.10 (2026-11-04)

* Aligned the browser bootstrap helper with the pinned Python 3.13 runtime,
so browser diagnostics reach Playwright instead of failing on unsupported packages.
* Preserved existing Nix and runner files and inherited an explicitly supplied browser.
* Kept complete strict-build output and exposed root changelog sections.
* Used available image inspection tools without substituting custom pixel heuristics.

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FCHANGELOG-3A-3A-7C0-2E4-2E9-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## 0.4.9 (2026-11-04)

* Prepared real unavailable-tool and unavailable-browser scenarios through
literal per-workspace environment overrides, including nested Qlot commands.
* Created reproducible tracked-source baselines for lint fixtures while respecting
ignored vendor files, and preserved environment metadata during grading.
* Clarified automatic selection of Rove testing and live Lisp evaluation skills.

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FCHANGELOG-3A-3A-7C0-2E4-2E8-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## 0.4.8 (2026-11-04)

* Preserved source pathnames beneath isolated compilation caches so Rove
discovers package-inferred test suites instead of reporting zero tests.
* Kept dependency outputs shared while confining candidate outputs to each workspace.
* Made Rove guidance record condition predicates as assertions and propagate
failed suites through the `ASDF` test operation and process exit status.

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FCHANGELOG-3A-3A-7C0-2E4-2E7-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## 0.4.7 (2026-11-04)

* Recorded exact batch run ownership instead of discovering new directories,
so concurrent diagnostic evaluations cannot enter another suite's batch index.
* Retained the run identifier when suite preparation fails before model execution.

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FCHANGELOG-3A-3A-7C0-2E4-2E6-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## 0.4.6 (2026-11-04)

* Prepared local Git baseline revisions for documentation fixtures so
strict source-link generation starts from a valid checkout.
* Used the installed documentation builder through Qlot without requiring an executable
wrapper or dependency installation.
* Kept pinned dependency bootstrap diagnostics in the startup log while
preserving candidate warnings and strict documentation failures in tool output.
* Corrected `JSON` parsing examples to the installed Yason keyword and boolean
representations, preserving semantic round-trips without custom Unicode rewriting.

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FCHANGELOG-3A-3A-7C0-2E4-2E5-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## 0.4.5 (2026-11-04)

* Rejected accidental external OpenCode tool directories while retaining
read access to pinned dependencies, binaries and captured tool output.
* Recommended relative paths inside isolated evaluation workspaces.

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FCHANGELOG-3A-3A-7C0-2E4-2E4-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## 0.4.4 (2026-11-04)

* Checked rejected-input error reports through runtime observations,
including custom conditions, instead of requiring one error-call syntax.
* Verified positive real inputs and several distinct rejected values.

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FCHANGELOG-3A-3A-7C0-2E4-2E3-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## 0.4.3 (2026-11-04)

* Increased the default OpenCode execution deadline to 630 seconds.
* Kept file resource inventories atomic in Promptfoo to prevent duplicate samples.
* Observed recovered Lisp runtime deadlines without depending on candidate handlers.
* Clarified project-only cache cleanup and preserved spaces in helper paths.

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FCHANGELOG-3A-3A-7C0-2E4-2E2-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## 0.4.2 (2026-11-04)

* Added fractional check scores while preserving mandatory pass decisions.
* Awarded half credit for inline Serapeum return types and full credit for
return types on a separate line. Missing signatures remain failures.

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FCHANGELOG-3A-3A-7C0-2E4-2E1-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## 0.4.1 (2026-11-04)

* Isolated sample `ASDF` system discovery from unrelated fixture projects.
* Added prepared runtime instructions and Qlot execution preflight to all suites.
* Supplied real `ASDF` project fixtures for the original Lisp writing tasks.
* Routed the prepared agent shell through Qlot for complete compound commands.
* Retained `UIOP` bootstrap diagnostics in sample logs instead of tool output.

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FCHANGELOG-3A-3A-7C0-2E4-2E0-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## 0.4.0 (2026-11-02)

* Moved runtime assertions and fixture projects into per-case files.
* Added binary fixture baselines, executable permission tracking and confined
file parameters for independent check extensions.
* Prepared workspaces and replay inputs from immutable snapshots while retaining
support for historical inline case inputs.

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FCHANGELOG-3A-3A-7C0-2E3-2E0-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## 0.3.0 (2026-11-01)

* Added evaluation suites for the remaining eleven project skills and
suite selection, independent behavioral checks, and reproducible tool environments.
* Archived tool calls, binary artifacts, symbolic links, and environment identity.
* Added suite-aware history comparisons and multi-suite batch indexes.
* Preserved provider artifacts across evaluator timeouts and exposed prepared
`MCP` runners with native tool-result evidence.

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FCHANGELOG-3A-3A-7C0-2E2-2E0-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## 0.2.0 (2026-11-01)

* Renamed the main system package namespace to `40ants-ai-evals/*` and the
test system and package namespace to `40ants-ai-evals-tests/*`.
* Declared explicit dependencies for evaluation check systems.

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FCHANGELOG-3A-3A-7C0-2E1-2E0-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## 0.1.0 (2026-11-01)

* Added the initial Common Lisp skill evaluation harness with Codex
and OpenCode providers and independent checks.


* * *
###### [generated by [40ANTS-DOC](https://40ants.com/doc/)]
