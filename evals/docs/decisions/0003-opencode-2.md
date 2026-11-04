# ADR 0003: Call OpenCode 2 through its HTTP API from Lisp

- Status: Accepted
- Date: 2026-11-01

## Context

The skill-evaluation harness needs a second agent runtime while keeping the
existing cases, assertions, and artifact format shared. OpenCode's CLI and
session interfaces change independently of the harness, and the evaluation
needs full session exports, per-message usage, tool-call counts, isolated
workspaces, partial traces after timeout, and exact cleanup of temporary state.

The pinned Promptfoo and its native Codex SDK provider already provide the
first agent path. Promptfoo 0.125.1's native `opencode:sdk` uses
`@opencode-ai/sdk` 1.x, while OpenCode 2.2.1 ships `@opencode/client` and a
different server API; the native provider does not implement this v2 protocol. Adding an OpenCode SDK package or moving lifecycle logic to
JavaScript would create a second implementation of workspace setup, retries,
timeouts, result interpretation and cleanup.

## Decision

Pin OpenCode **2.2.1** in `shell.nix` and run it as a loopback server. Implement
OpenCode's lifecycle and HTTP API v2 calls in
`src/providers/opencode.lisp`. Lisp owns the private per-run config/cache/data/
state directories, imports only the selected `zai-coding-plan` credential,
creates one session per sample, requests the complete transcript and durable
log, records partial traces, and terminates the server and private state.

Promptfoo reaches this provider through `evals/lib/opencode-provider.cjs`, a
small JSON subprocess transport. Its only duties are to send
`{protocolVersion, prompt, config, vars}`, honor Promptfoo's abort signal and
timeout, bound stdout/stderr, parse the structured response and return it to
Promptfoo. It does not run OpenCode operations or derive evidence. The existing
`evals/lib/promptfoo-adapter.cjs` continues to send provider results to the
shared Lisp collector and check engine.

Use OpenCode's session `export` and log endpoints. A Promptfoo `exec:` provider
returns stdout as textual output, so printing JSON there cannot populate
structured `metadata`, `tokenUsage` and `sessionId` fields.
The eval needs the entire assistant/tool history, usage across assistant turns
(including compaction), tool completion status and partial evidence after an
interruption; command output alone does not carry those session details.

## Consequences

- Codex remains the default agent. `--agent codex|opencode|all` selects one or
  both; each agent has a recorded profile. Default profiles are Codex
  `gpt-6-sol` at medium effort and OpenCode `zai-coding-plan/glm-5.3` in build
  mode.
- The same cases and checks apply to both agents. Every case/repeat/agent/variant
  gets a separate workspace and session.
- `--model` is supported only when selecting one agent. `--effort` applies only
  to Codex. Selecting `all` uses both profiles unchanged. `--timeout` sets the
  overall Promptfoo deadline (240000 ms by default). OpenCode reserves
  `min(30000, floor(timeoutMs / 4))` for interruption, transcript export,
  collection and grading; `profiles["opencode"].executionTimeoutMs` records the
  remaining inner execution timeout (210000 ms at the default), while
  `manifest.timeoutMs` records the overall value.
- OpenCode credentials remain in the user's auth file and are never archived.
  OpenCode is isolated from personal plugins and MCP servers. It may still apply
  system-managed policy from `/Library/Application Support/opencode/opencode.json`;
  the API has no option to disable that policy.
- History can filter by agent. Comparisons can explicitly select a different
  agent for each side; cross-agent comparisons are practical workflow
  comparisons across different models, runtimes and effective turn limits.
  Measure skill regressions within the same profile.
- OpenCode exposes token usage but the harness has no known per-call USD price;
  reports retain `costUsd: null` as unknown.
- Documentation and offline validation do not run model evaluations. Full
  two-agent or ablation matrices remain explicit opt-in commands because each
  sample makes a model call.

## Update 2026-11-04: default execution time

The original 210-second OpenCode execution limit interrupted long model response
steps even though tools completed in milliseconds. The default overall deadline
is now 660000 ms for runs including OpenCode, leaving 630000 ms for the agent.
Codex-only runs retain 240000 ms. Explicit `--timeout` continues to override the
default. All effective limits remain recorded in manifests and agent profiles;
historical run settings are unchanged.
