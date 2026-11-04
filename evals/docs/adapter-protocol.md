# Promptfoo ↔ Common Lisp JSON protocols

Provider lifecycle, OpenCode's HTTP API calls, workspace and trace collection,
and grading live in Common Lisp. JavaScript files at `evals/lib/` are thin
Promptfoo transports. They invoke Roswell without a shell, send one JSON request
on stdin, and read one JSON response from stdout. Lisp bootstrap and runtime
diagnostics go to stderr. The harness loads dependencies from the project's
`.qlot/` and implementation code from its own harness root.

## OpenCode provider protocol, version 1

Promptfoo's custom provider in `evals/lib/opencode-provider.cjs` invokes:

```text
ros -Q -- <harness>/roswell/ai-evals.ros provider
```

The request contains the rendered prompt, evaluation vars, and provider config:

```json
{
  "protocolVersion": 1,
  "prompt": "Implement the task",
  "vars": {
    "id": "package-path",
    "variant": "with-skill",
    "workspaces": {
      "opencode": {
        "with-skill": "/project/.evals/runs/RUN_ID/fixtures/package-path/opencode/with-skill/"
      }
    }
  },
  "config": {
    "agent": "opencode",
    "timeout": 630000,
    "overallTimeoutMs": 660000,
    "runDir": "/project/.evals/runs/RUN_ID/",
    "variant": "with-skill",
    "profile": {"model": "zai-coding-plan/glm-5.3", "mode": "build", "executionTimeoutMs": 630000},
    "server": {
      "baseUrl": "http://127.0.0.1:PORT",
      "stateDir": "/private/tmp/opencode-eval/"
    }
  }
}
```

`vars.workspaces.opencode[variant]` resolves to the immutable fixture template;
the Lisp provider copies that template to a fresh sample workspace. A direct
provider request may instead set `config.working_dir`. `server` is a private,
per-run descriptor for the loopback server and its private password file; it
contains no credential value. The Lisp provider reads
only the `zai-coding-plan` key from `~/.local/share/opencode/auth.json`, or the
file selected by `SKILL_EVAL_OPENCODE_AUTH_FILE`. The imported credential is not
sent in the request, written to artifacts, or printed in diagnostics. OpenCode
runs with per-run config, cache, data and state directories and does not load
personal plugins or MCP servers. OpenCode can still apply system-managed
policy from `/Library/Application Support/opencode/opencode.json`; the API has
no option to disable that policy.

The provider returns one complete Promptfoo `ProviderResponse` JSON object on
stdout, including its output or error, metadata, session ID and token usage when
available. The JavaScript transport validates the outer response shape and
returns it unchanged; it does not interpret the conversation or compute usage.
The Lisp provider calls OpenCode's HTTP API v2 directly. It captures the full
session export and durable log, plus partial trace data on cancellation or
failure. Each sample, repeat, agent and skill variant receives a separate
workspace/session. OpenCode copies the immutable run fixture into a fresh
workspace under the server's private state directory. Collection copies its
files and trace into the run artifacts; stopping the server removes that private
workspace/state, while fixture templates stay under the run directory.
Assistant token usage is accumulated across the full session,
including compaction messages; shell tool calls provide the command count.

The transport preserves inherited pinned Nix and Qlot environment variables
but sends no process environment or authentication file contents in JSON. It
has an 8 MiB stdout limit, retains only the last 8 KiB of stderr for diagnostics,
and uses the overall evaluation deadline rather than the inner OpenCode
execution timeout. The OpenCode run timeout defaults to 660000 ms and is passed as `overallTimeoutMs` to
the provider. The OpenCode profile reserves
`min(30000, floor(timeoutMs / 4))` for interruption, transcript export,
collection and grading; its recorded `executionTimeoutMs` is the remainder
(630000 ms at the default). The manifest records the overall `timeoutMs`. These
values describe separate deadlines, not identical model thinking time across
providers. Promptfoo's `abortSignal` terminates the
child process group, allows a one-second grace period, then sends `SIGKILL` if
needed. `SKILL_EVAL_HARNESS_ROOT` selects the harness snapshot; if absent, the
provider resolves the harness relative to its own file.

## Assertion protocol, version 1

The assertion adapter invokes:

```text
ros -Q -- <harness>/roswell/ai-evals.ros assert
```

It sends the rendered prompt, variables, provider label and full structured
provider response. For example:

```json
{
  "protocolVersion": 1,
  "output": "The agent's final answer",
  "runDir": "/project/.evals/runs/RUN_ID/",
  "context": {
    "prompt": "Implement the task",
    "vars": {"id": "case-id", "shouldTrigger": true},
    "provider": {"label": "opencode:with-skill"},
    "providerResponse": {
      "output": "The agent's final answer",
      "sessionId": "native-session-id",
      "tokenUsage": {"total": 123},
      "metadata": {"agent": "opencode", "workingDir": "/temporary/workspace"}
    }
  }
}
```

The collector saves the prompt, complete provider trace, generated workspace
files and `sample.json` before grading. A successful protocol exchange returns
the grading outcome, including ordinary assertion failures, with exit status 0:

```json
{
  "protocolVersion": 1,
  "grading": {
    "pass": false,
    "score": 0.95,
    "reason": "return-type-layout",
    "checks": [{"name": "return-type-layout", "pass": false}]
  },
  "sample": {
    "sampleId": "case-id-with-skill-opencode-uniqueid",
    "agent": "opencode",
    "variant": "with-skill",
    "skillRead": true,
    "commandCount": 9,
    "usage": {"total_tokens": 123},
    "final": "The agent's final answer",
    "trace": "samples/case-id-with-skill-opencode-uniqueid/turn.json"
  }
}
```

The adapter returns `grading` unchanged and attaches `sample` to
`providerResponse.metadata.skillEval`. `grading.json` is saved beside the
sample. If grading infrastructure fails after collection, Lisp returns
`{protocolVersion: 1, infrastructureError: "message", sample: {...}}`, with no
`grading`. The adapter preserves sample metadata and throws. Failures before
collection exit nonzero with diagnostics on stderr. Invalid responses and
process failures also throw; the adapter records
`skillEval.infrastructureError`. Ordinary grading failures remain distinct
from infrastructure errors in the Lisp summary.

The assertion adapter has a 60-second deadline and an 8 MiB stdout limit. Tests
can shorten the deadline with `SKILL_EVAL_ADAPTER_TIMEOUT_MS` (1..60000). Its
child runs in its own process group and is terminated on failure. Functional
checks have a separate child-process deadline. JSON booleans, null and empty
arrays remain distinct throughout transport.

## Run and snapshot environment

The runner supplies `SKILL_EVAL_RUN_DIR`, `SKILL_EVAL_HARNESS_ROOT` and
`SKILL_EVAL_DEPENDENCY_ROOT`. Archived harnesses load their own source, while
the last variable points to the Qlot dependency installation. Run snapshots
include `qlfile.lock`; manifests record its SHA-256, the overall `timeoutMs`, and the selected
agent profiles including `executionTimeoutMs`. Reproducing an old harness requires restoring its
recorded dependencies too. Authentication files and process environments are
never sent in either JSON protocol.
