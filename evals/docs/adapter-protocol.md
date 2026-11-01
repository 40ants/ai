# Promptfoo ↔ Common Lisp protocol, version 1

The only production JavaScript file is `evals/lib/promptfoo-adapter.cjs`.
It invokes `ros -Q -- roswell/ai-evals.ros assert` without a shell, writes one
JSON request to stdin and awaits one JSON response on stdout. Lisp bootstrap
and runtime diagnostics go to stderr. The Roswell script loads dependencies
from the project's `.qlot/` and implementation code from its own harness root.

The request has this shape (optional provider data may be absent):

```json
{
  "protocolVersion": 1,
  "output": "Agent's final answer",
  "runDir": "/absolute/project/.evals/runs/RUN_ID/",
  "context": {
    "prompt": "Rendered task",
    "vars": {"id": "case-id", "shouldTrigger": true},
    "provider": {"label": "with-skill"},
    "providerResponse": {
      "metadata": {"workingDir": "/temporary/workspace", "skillCalls": []},
      "raw": "JSON-encoded Codex turn with items and usage",
      "sessionId": "native-session-id",
      "tokenUsage": {"total": 123}
    }
  }
}
```

The collector saves `files/`, `prompt.txt`, `turn.json` and `sample.json` before
grading. A successful protocol exchange returns the grading outcome, including
ordinary assertion failures, with exit status 0:

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
    "sampleId": "case-id-with-skill-uniqueid",
    "variant": "with-skill",
    "skillRead": true,
    "commandCount": 9,
    "usage": {},
    "final": "Agent's final answer",
    "trace": "samples/case-id-with-skill-uniqueid/turn.json"
  }
}
```

The adapter returns `grading` unchanged and attaches `sample` to
`providerResponse.metadata.skillEval`. `grading.json` is saved beside the sample.
If grading infrastructure fails after collection, Lisp returns
`{protocolVersion: 1, infrastructureError: "message", sample: {...}}`, with no
`grading`. The adapter preserves sample metadata and throws. Failures before
collection exit nonzero with diagnostics on stderr. Invalid responses and
process failures also throw; the adapter records `skillEval.infrastructureError`.
The Lisp summary distinguishes these errors from failed assertions even when
Promptfoo presents an assertion error in its UI.

The adapter has a 60-second deadline and an 8 MiB stdout limit. Tests can shorten
the deadline with `SKILL_EVAL_ADAPTER_TIMEOUT_MS` (1..60000). A timed-out adapter
child runs in its own process group, which is terminated on failure. Functional
checks have a separate child-process deadline. JSON booleans, null and empty
arrays remain distinct throughout transport.

The runner supplies `SKILL_EVAL_RUN_DIR`, `SKILL_EVAL_HARNESS_ROOT` and
`SKILL_EVAL_DEPENDENCY_ROOT`. Archived harnesses load their own source, while
the last variable points to the Qlot dependency installation. Run snapshots
include `qlfile.lock`; manifests record its SHA-256 and all tool versions.
Reproducing an old harness requires restoring its recorded dependencies too.
Authentication files and process environments are never sent in this protocol.
