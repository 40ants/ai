# ADR 0001: Common Lisp eval harness with a thin Promptfoo JavaScript adapter

Date: 2026-11-01

Status: Accepted and implemented.

## Context

Our eval harness currently contains custom JavaScript orchestration, artifact
collection and grading. We will move that code to Common Lisp, with shared
logic in the ASDF system `40ants-ai-evals`, Roswell scripts as entry points and
Qlot lockfiles for Lisp dependencies. Tool executables remain pinned by Nix.
Promptfoo and its native Codex SDK provider remain external dependencies.

Promptfoo's JavaScript assertion callback receives the provider response,
including `metadata.workingDir` and `raw`. The pre-migration callback
`evals/lib/workspace-grade.cjs` used that access to archive generated files
before Promptfoo removes the disposable workspace.

In pinned Promptfoo 0.125.1, the built-in webhook assertion sends only `output`
and `context` containing `prompt` and `vars`. It omits the provider response
and workspace path. Moving to that interface would lose data needed for
artifact collection.

The project owner explicitly permits a thin custom JavaScript adapter as an
exception to the goal of migrating our code to Common Lisp.

## Decision

Keep one JavaScript assertion adapter at the Promptfoo integration boundary.
Move artifact collection, grading, run orchestration, history and comparisons
to `40ants-ai-evals`. Use Roswell scripts for Lisp command-line entry points
and Qlot for pinned Lisp dependencies.

The adapter will:

1. Receive Promptfoo's assertion arguments and select the required context:
   output, prompt, test variables, provider label, provider response data
   (workspace path, raw turn, skill-call evidence, session and usage data when
   available), and the runner's artifact directory.
2. Start the Lisp entry point in the project Qlot environment without shell
   interpolation. Send a versioned JSON request through standard input.
3. Await completion while the native workspace still exists. Read a JSON
   response from standard output; reserve standard error for diagnostics.
4. Return the Lisp-produced grading result to Promptfoo and attach
   Lisp-produced sample metadata to `providerResponse.metadata.skillEval`,
   preserving the existing viewer and summary integration.
5. Report process failures, timeouts and invalid protocol responses explicitly,
   preserving their distinction from ordinary failed assertions in our run
   summaries.

JavaScript may handle process transport, JSON serialization and the mapping to
Promptfoo's callback objects. It must not traverse workspaces, interpret Lisp
source, calculate scores, implement assertions, aggregate history or compare
runs. These responsibilities belong to Common Lisp. Generated candidate code
continues to run in a separate Lisp process from the harness.

Promptfoo continues to own Codex execution, disposable workspace lifecycle,
eval scheduling, its database and its UI. The adapter must await Lisp artifact
collection and grading before resolving the assertion callback, so native
workspace cleanup cannot precede collection. Existing run archives and
Promptfoo history must remain readable.

## Consequences and verification

The migration retains a small JavaScript dependency at one explicit boundary.
Its behavior must be covered by integration tests for request/response mapping,
metadata attachment, workspace availability, process errors and timeouts.
Lisp grading and artifact behavior will be checked against existing calibration
examples and archived runs before fresh model evaluations.

The earlier proposal to discover workspaces through Codex notification hooks or
session files is no longer required for this migration. The existing callback
already exposes the authoritative workspace path.

The adapter invokes the Roswell entry point through the versioned
[JSON protocol](../adapter-protocol.md). Artifact collection, grading, history
and comparison now run in Common Lisp; the JavaScript adapter handles transport.

## References

- Current callback: [`evals/lib/promptfoo-adapter.cjs`](../../lib/promptfoo-adapter.cjs).
- Pre-migration callback: `git show f38a038:evals/lib/workspace-grade.cjs`.
- [Webhook assertion in Promptfoo 0.125.1](https://github.com/promptfoo/promptfoo/blob/0.125.1/src/assertions/webhook.ts).
