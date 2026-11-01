(uiop:define-package #:40ants-ai-evals-docs/index
  (:use #:cl)
  (:import-from #:pythonic-string-reader #:pythonic-string-syntax)
  (:import-from #:named-readtables #:in-readtable)
  (:import-from #:40ants-doc #:defsection #:defsection-copy)
  (:import-from #:40ants-ai-evals-docs/changelog #:@changelog)
  (:import-from #:docs-config #:docs-config)
  (:import-from #:40ants-doc/autodoc #:defautodoc)
  (:export #:@index #:@readme #:@changelog))
(in-package #:40ants-ai-evals-docs/index)

(in-readtable pythonic-string-syntax)

(defmethod docs-config ((system (eql (asdf:find-system "40ants-ai-evals-docs"))))
  #+quicklisp (ql:quickload "40ants-doc-theme-40ants")
  #-quicklisp (asdf:load-system "40ants-doc-theme-40ants")
  (list :theme
        (find-symbol "40ANTS-THEME"
                     (find-package "40ANTS-DOC-THEME-40ANTS"))))

(defsection @index (:title "40ants-ai-evals — Reproducible skill evaluations in Common Lisp."
                    :ignore-words ("40A" "API" "APM" "ASDF" "CLI" "CL" "CI"
                                   "Codex" "Common Lisp" "Git" "GitHub" "HTTP"
                                   "JSON" "MCP" "Nix" "OpenCode" "Promptfoo"
                                   "Qlot" "Quicklisp" "README" "REPL" "Roswell"
                                   "SBCL" "SDK" "Serapeum" "SQL" "Unlicense" "URL"
                                   "USD" "XDG" "`SQLite`" "MIT" "VPS" "CLOS"
                                   "EFFORT" "HEAD" "HTML" "ID" "ISO" "JS" "JSONL"
                                   "PATH" "SHA-256" "SSE" "SSH" "PNG"
                                   "UTF-8" "UTC" "ZAI" "`macOS`" "Ultralisp"))
  (40ants-ai-evals system)
  """
This repository provides APM-installable coding skills and a reproducible
Common Lisp evaluation harness. The harness runs the same behavioral suite
against Codex and OpenCode, records full traces and generated files, and grades
results with Lisp checks.
"""
  (@packages section)
  (@evaluations section)
  (@other-skills section)
  (@development section)
  (@api section))

(defsection @packages (:title "APM skill packages and development")
  """

This repository contains APM-installable skill packages for coding agents.

The current packages are:

- `common-lisp-skills`: reusable Common Lisp development skills
- `tools`: reusable tooling skills, currently including `nix-shell-playwright`

The recommended installation method is APM (Agent Package Manager), because APM can install these skills directly from GitHub into multiple agent runtimes, including Codex and OpenCode.

## Repository Layout

The APM-installable packages are located in:

- `plugins/common-lisp-skills/`
- `plugins/tools/`

## Package Contents

### `common-lisp-skills`

Includes skills for:

- writing Common Lisp code
- working with the REPL
- testing with Rove
- handling JSON
- logging with `log4cl`
- defining CLOS classes
- writing 40ants-doc documentation
- avoiding common Lisp pitfalls
- clearing stale ASDF fasl cache
- linting Common Lisp projects with [Mallet](https://github.com/fukamachi/mallet) and [40ants-linter](https://github.com/40ants/linter)

### `tools`

Includes skills for:

- bootstrapping a reproducible Playwright environment with `nix-shell`
- generating static smoke tests for local HTML pages
- running local browser-based smoke tests with screenshot capture
- deploying, updating, and rolling back 40ants pet-project services on VPS hosts (`/srv/services` scheme with Caddy and systemd isolation)

## Install from GitHub with APM

APM is the recommended way to consume these packages from another project.

1. Install APM.

`macOS` / Linux:

```bash
curl -sSL https://aka.ms/apm-unix | sh
```

Windows (PowerShell):

```bash
irm https://aka.ms/apm-windows | iex
```

2. From the root of your own project, install the package you want for your target agent.

### Example: install all Common Lisp skills for Codex

```bash
apm install 40ants/ai/plugins/common-lisp-skills --target codex
```

### Example: install the tools plugin for Codex

```bash
apm install 40ants/ai/plugins/tools --target codex
```

### Example: install the tools plugin for OpenCode

```bash
apm install 40ants/ai/plugins/tools --target opencode
```

### Example: install only the Playwright nix-shell skill

```bash
apm install 40ants/ai/plugins/tools --target codex --skill nix-shell-playwright
```

### Example: install for both Codex and OpenCode

```bash
apm install 40ants/ai/plugins/common-lisp-skills --target codex,opencode
apm install 40ants/ai/plugins/tools --target codex,opencode
```

APM installs into the target runtime's native directories. According to the current APM docs, `codex` deploys to `.codex/` plus `.agents/` for skills, and `opencode` deploys to `.opencode/`.

After installation, start a new agent session or thread so the new skills are available for invocation.

## Persist in Your Project's `apm.yml`

Instead of running the full command each time, declare the package in your project's `apm.yml`:

```yaml
name: my-project
version: 0.1.0

dependencies:
  apm:
    - 40ants/ai/plugins/common-lisp-skills
    - 40ants/ai/plugins/tools
```

Then run:

```bash
apm install --target codex
```

## Updating in Another Project

If your project depends on these packages through APM, rerun install in your own project:

```bash
apm install --target codex
```

Or, if you installed a package directly as a package reference:

```bash
apm install 40ants/ai/plugins/tools --target opencode
```

If your agent does not pick up updated skills in the current session, start a new thread or session.

## Development Notes

- `plugins/common-lisp-skills/apm.yml`
- `plugins/common-lisp-skills/plugin.json`
- `plugins/common-lisp-skills/skills/`
- `plugins/tools/apm.yml`
- `plugins/tools/plugin.json`
- `plugins/tools/skills/`

## Local Validation

If you want to validate plugin structure with the plugin scaffold validator:

```bash
python3 /Users/art/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py /Users/art/projects/lisp/ai/plugins/common-lisp-skills
python3 /Users/art/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py /Users/art/projects/lisp/ai/plugins/tools
```

Note: this validator requires `PyYAML` in the active Python environment.
""")

(defsection @evaluations (:title "Evaluate skills with Promptfoo")
  """
The first behavioral suite is for `writing-common-lisp`. It asks an agent to
edit a disposable project, captures its transcript and generated files, then
reads and runs the Lisp with SBCL and Serapeum. The same cases, prompts and
checks run through either Codex or OpenCode. Codex remains the default.

The harness is the ASDF system `40ants-ai-evals`, with Roswell entry points.
[ADR 0001](https://github.com/40ants/ai/blob/master/evals/docs/decisions/0001-common-lisp-with-promptfoo-js-adapter.md)
records the original Promptfoo-to-Lisp adapter. [ADR 0003](https://github.com/40ants/ai/blob/master/evals/docs/decisions/0003-opencode-2.md)
records the OpenCode integration. The [JSON protocols](https://github.com/40ants/ai/blob/master/evals/docs/adapter-protocol.md)
keep provider lifecycle, collection and grading in Lisp; JavaScript only carries
JSON across Promptfoo's custom-provider boundary.

### 1. Enter the pinned environment

```bash
cd /Users/art/projects/lisp/ai
nix-shell
qlot install
```

`shell.nix` pins nixpkgs by commit and SHA-256, Promptfoo **0.125.1**, Codex
SDK and CLI **0.156.1**, OpenCode **2.2.1**, APM **0.31.0**, Node.js **22.23.4**,
SBCL **2.6.8**, Roswell **26.10.117** and Qlot **1.8.2**.
`qlfile` and `qlfile.lock` pin project libraries to Quicklisp **2026-01-01**,
including the same Serapeum release as before the Lisp migration. `nix/promptfoo/package-lock.json` pins the published npm packages
and their complete dependency graph; Nix also checks the downloaded dependency
hash. The native Codex provider requires SDK `^0.156.1`, so its matching CLI
replaces the previous 0.165.0 CLI only inside this shell. OpenCode's pinned
CLI is on the shell PATH; the Lisp provider calls its HTTP API v2 directly. The new Promptfoo uses a `SQLite`-backed database;
the old better-sqlite3 rebuild workaround is removed. The shell targets Apple
Silicon `macOS`. Nix downloads dependencies to its store without installing global npm
packages or changing a Homebrew installation/user Nix profile.

The shell uses a PATH made from those Nix packages plus `macOS` system utilities.
Global/Homebrew executables are excluded. SBCL user initialization is disabled;
Roswell state, compilation caches and Qlot download caches stay under `.evals/`.
Libraries are installed under `.qlot/`; personal Quicklisp is not loaded.
Roswell uses the Nix SBCL and does not install another Lisp implementation.
Use `qlot install` to restore the lockfile and `qlot update` only for an intentional
dependency upgrade. Check in both `qlfile` and `qlfile.lock`; do not edit `.qlot/`.

Check the tools yourself:

```bash
promptfoo --version
codex --version
opencode --version
apm --version
sbcl --version
node --version
ros --version
qlot --version
qlot check
```

APM's four Promptfoo skills are installed only into this project's
`.agents/skills/`. `apm.yml` pins their upstream commit and `apm.lock.yaml`
records resolved content. Recreate the installation after a fresh clone:

```bash
apm install --frozen --target codex --only apm
```

Do not run `apm self-update` to respond to its upgrade banner: the shell
deliberately supplies a fixed version. Start a new Codex task in this project
to discover the installed skills.

### 2. Understand the three pieces of an eval

Open `evals/writing-common-lisp/promptfooconfig.json`:

- `prompts` selects the user request (`{{task}}`).
- the runner selects Promptfoo's native Codex SDK provider or the custom
  `evals/lib/opencode-provider.cjs` provider, based on `--agent`.
- Each sample/repeat and skill variant gets a fresh workspace and provider
  session. Artifacts are copied into the run before Promptfoo discards the
  temporary working directory.
- `defaultTest.assert` calls `evals/lib/promptfoo-adapter.cjs`. It sends JSON to
  `roswell/ai-evals.ros assert`, which archives files in `src/collector.lisp`.
  The core in `src/checks.lisp` resolves named check plans;
  independent ASDF systems under `evals/checks/` implement the rules.
  Real reader/runtime checks execute in a separate process through
  `roswell/check-lisp.ros`. Promptfoo waits for the assertion before cleanup.

The `Contract` assertion includes `return-type-layout`: every Serapeum `->`
signature in the tested source must put its return type on a separate line
with exactly four leading spaces. SBCL identifies actual forms and source
positions, so examples in comments or docstrings cannot satisfy the check.
Cases with an explicit project override forbidding Serapeum skip this rule.

`cases.json` supplies inputs and expectations. For example, `package-path`
asks for `src/models/score.lisp` in system `demo`. The expected package is
`demo/src/models/score`; SBCL also verifies that `add-score` adds correctly.
Expectations live outside the prompt, so the agent does not see the answer key.

There are **9 development cases** and **2 holdout cases**. Coverage includes
package paths, public exports/docstrings, signatures, LOOP style, exhaustive
dispatch, error reporting, unused parameters, hook contracts, project overrides,
protected `.qlot/` dependencies, and a negative Python routing case.

The runner prepares fixture templates with a Git root and a snapshot of the
tested skill. Its default profiles are Codex `gpt-6-sol` at medium effort and
OpenCode `zai-coding-plan/glm-5.3` in build mode. OpenCode's server is
started per run on loopback with private config, cache, data and state directories. It
imports only the `zai-coding-plan` credential from
`~/.local/share/opencode/auth.json`; set `SKILL_EVAL_OPENCODE_AUTH_FILE` to use
another auth file. It does not load personal OpenCode plugins or MCP servers.
OpenCode can still apply system-managed policy from
`/Library/Application Support/opencode/opencode.json`; the API has no option to
disable that global policy. The Codex path reuses existing Codex file-based
login state. Evaluation calls consume the allowance or API credits of the
selected account. No model grader is
used.

### 3. Calibrate the grader before trusting it

```bash
qlot exec ros roswell/ai-evals.ros test
promptfoo validate config -c evals/writing-common-lisp/promptfooconfig.json
```

Rove replays 47 frozen inputs (36 original calibration inputs plus one real
output for each of the 11 scenarios) and checks
collector/adapter failures, JSON round trips, historical exports, coverage,
parameter schemas, profile cycles, evidence caching and an independent ASDF
check extension.
The calibration suite checks known-good code and intentional defects, including
wrong arithmetic despite correct style. Passing calibration is evidence about
the grader, not evidence that the skill passed a real model evaluation.

### 4. Start with one case

```bash
qlot exec ros roswell/ai-evals.ros run --label opencode-package \
  --agent opencode --filter package-path --repeat 1
```

To run the same case through both agents and then run a matched ablation for
both, keep the case filter fixed:

```bash
qlot exec ros roswell/ai-evals.ros run --label package-both --agent all --filter package-path --repeat 1
qlot exec ros roswell/ai-evals.ros run --label package-ablation \
  --agent all --filter package-path --repeat 1 --ablation
```

Each command makes model calls. Begin with the one-case run; the full matrix is
opt-in below. Exit code zero requires every expected sample to be present and
passing, with no infrastructure errors. Inspect artifacts after a failure
before changing the skill or its test.

Runs default to one repeat and `--timeout 240000` ms for the overall Promptfoo
evaluation deadline. For OpenCode, a portion of that deadline is reserved for
interrupting the session, exporting its trace and grading: the inner execution
timeout is `timeout - min(30000, floor(timeout / 4))`, or 210000 ms by default.
The manifest records the overall timeout; the selected profile records its
execution timeout. Codex and OpenCode workflows can have different effective
turn limits, so use within-profile runs to measure skill regressions. Use
`--repeat` and `--timeout` when you intentionally want a larger or longer run.

Codex routing evidence uses Promptfoo's native `metadata.skillCalls`. OpenCode
routing evidence uses recorded completed skill/read tool calls. Both are runtime
evidence, not proof that every instruction affected the answer. Inspect the
archived transcript when a routing result looks wrong.

### 5. Read the accumulated history

```bash
qlot exec ros roswell/ai-evals.ros history
qlot exec ros roswell/ai-evals.ros history --agent opencode
qlot exec ros roswell/ai-evals.ros view
```

The viewer serves the project's persistent Promptfoo database at
`http://127.0.0.1:15500`. Its run list retains earlier evaluations. Use Ctrl-C to
stop the viewer. No Promptfoo Cloud account or result sharing is configured.

Every run also gets a unique directory under `.evals/runs/` containing:

```text
manifest.json          Git revision/status, tool versions, per-agent profiles,
                       case list, repeat count, skill hash and suite hash
skill/                 Exact skill directory used by that run
harness/               Snapshot of eval code, tests, shell.nix and npm lockfile
results.json           Full Promptfoo export
summary.json           Per-case results, failures/errors, efficiency statistics
fixtures/              Immutable starting project templates for native copies
samples/<sample-id>/   Prompt, full provider trace, sample.json, generated files
```

Both passing and failing runs remain in history. Authentication values are not
copied into artifacts. The OpenCode server and its private state are removed at
run end; Codex authentication is mounted only in its temporary runtime home.
OpenCode fixture templates remain under the run directory. Per-sample copies
are created under the server's private state directory and removed when the
server stops after assertions; generated files and full traces stay archived.
Old runs keep their original JSONL artifacts and remain readable in history.

Before the 0.125.1 migration, a consistent `SQLite` backup was saved under
`.evals/backups/before-promptfoo-0.125.1-*/promptfoo.db`. Existing database rows
and run folders are preserved. Re-enter `nix-shell` after pulling this upgrade;
an already-open shell still has the previous tools on its PATH. Establish a
new baseline with the upgraded harness before assessing further skill edits.

`.evals/` is ignored by Git. Back up **the whole directory**, including the
Promptfoo database, if you need history to survive deletion of this checkout or
a disk failure. Local accumulation is not an off-machine backup.

To regrade archived samples without model calls or replacing original results:

```bash
qlot exec ros roswell/ai-evals.ros replay RUN_ID
```

This writes `replay-lisp.json` beside the original run. Historical harness
snapshots retain their original JS files; active project code uses the Lisp CLI.
A migration changes the suite hash and recorded tools, so comparisons across
this boundary require inspecting settings and using `--allow-mismatch` explicitly.
Establish a fresh baseline for subsequent skill edits. The Codex `skill-read`
check retains its earlier semantics: automatic skill injection can still
produce a false negative in Promptfoo's skill-call evidence.

### 6. Compare a change with any earlier version

```bash
# After making one intentional change to SKILL.md:
qlot exec ros roswell/ai-evals.ros run --label candidate --agent opencode --filter package-path
qlot exec ros roswell/ai-evals.ros compare baseline candidate --agent opencode

# Compare both agents from the same run explicitly:
qlot exec ros roswell/ai-evals.ros compare package-both package-both \
  --before-agent codex --after-agent opencode
```

Use unique labels or exact run IDs. Same-agent comparison checks the test suite,
selected cases, repetitions, model and relevant tool versions. Cross-agent
comparison is descriptive: it cannot isolate agent differences from their
models, runtimes and turn limits. This is a practical agent-workflow
comparison, not a controlled skill-only comparison. Measure skill regressions
within the same profile. `--model` is for a single selected agent; `--effort` applies
only to Codex. `--agent all` uses each profile's defaults. Use `--allow-mismatch`
for an intentional same-agent exploration with differing settings.

You can evaluate an old skill from **any Git commit** with today's test suite:

```bash
qlot exec ros roswell/ai-evals.ros run --label historical --ref HEAD
```

Replace `HEAD` with a real commit hash or tag from `git log`. The runner extracts
only that commit's skill directory; it never checks out a different branch or
changes the current skill. To evaluate a separate experimental copy, use
`--skill-dir /absolute/path/to/writing-common-lisp` instead of `--ref`.

Model references such as `gpt-6-sol` and `zai-coding-plan/glm-5.3` are provider-managed,
so pinned client tools do not freeze model weights. Keep the agent and profile
constant when measuring a skill change; cross-agent results are useful for
practical workflow comparisons, not controlled skill-only comparisons.

### 7. Run larger matrices when useful

```bash
# Full opt-in matrix: 11 cases × 3 repeats × 2 agents = 66 samples.
qlot exec ros roswell/ai-evals.ros run --label full-matrix --agent all --group all --repeat 3

# Matched with/without-skill matrix: 11 × 3 × 2 agents × 2 variants = 132 samples.
qlot exec ros roswell/ai-evals.ros run --label full-ablation --agent all --group all --repeat 3 --ablation

# A smaller repeat run for one profile.
qlot exec ros roswell/ai-evals.ros run --label opencode-repeat \
  --agent opencode --filter package-path --repeat 3
```

In ablation mode, the control receives the same task without an explicit
`Use $writing-common-lisp` request, and the tested skill is absent. Other checks
remain the same, except skill-read evidence does not apply to that control. This
is a paired observational comparison, not a claim of statistical significance.

The report retains passes, assertion failures, infrastructure errors, token
usage, command count and elapsed time separately. OpenCode token totals include
all assistant messages in the session, including compaction; command counts come
from shell tool calls. Runtime turn limits and transport cleanup time may differ
by provider. Per-call USD pricing is not known here, so `costUsd: null`
means unknown, not zero. Choose a matrix size intentionally: every sample makes
an evaluation call.

### 8. Extend checks without changing the core

Cases declare an ordered `vars.checks` array of named checks and profiles.
`defaultTest.vars.checkSystems` selects independent ASDF systems that register
those checks. Typed parameters, missing variables and unknown names are
validated before model calls. The built-in rules retain their previous scores.

See [Adding independent checks](https://github.com/40ants/ai/blob/master/evals/docs/extending-checks.md) for a complete
ASDF example and the JSON format, or inspect the runnable example under
`t/fixtures/example-check/`. [ADR 0002](https://github.com/40ants/ai/blob/master/evals/docs/decisions/0002-extensible-checks.md)
records the architecture. List the 28 built-in check schemas with:

```bash
qlot exec ros roswell/ai-evals.ros checks
```

### 9. Add a regression case before editing instructions

1. Reproduce a real failure as one entry in `cases.json`.
2. Write the expected behavior independently of the agent's current output.
3. Add an objective assertion/functional check and calibrate it with a passing
   and failing example in `t/grading/contracts-test.lisp`.
4. Run the old skill to record the failure.
5. Make one targeted skill change, keeping the cases/grader/model fixed.
6. Rerun with the same repeat count and compare exact run IDs.
7. Check the holdout set after selecting the change.

The current suite deliberately leaves the skill's conflicting file-layout
wording unscored: the package example starts with a package definition, while
the file-layout paragraph calls `in-package` the first executable form. Resolve
that intended contract before making it a hard assertion. The suite also does
not prove every formatting/naming rule or behavior of related skills.

References: [Promptfoo native Codex SDK provider](https://www.promptfoo.dev/docs/providers/openai-codex-sdk/),
[Promptfoo skill evaluations](https://developers.openai.com/blog/eval-skills),
[APM install and frozen dependencies](https://microsoft.github.io/apm/reference/cli/install/).
""")


(defsection @other-skills (:title "Evaluate any project skill")
  """
The suite catalog in `evals/suites.json` includes all 12 project skills.
The original `writing-common-lisp` remains the default; the other 11 skills
have six cases each: four functional tasks, automatic activation and an
unrelated task. One functional case per skill belongs to the holdout group.
Externally installed APM skills are not included.

From the pinned project shell, list suites and their check schemas:

```bash
qlot exec ros roswell/ai-evals.ros suites
qlot exec ros roswell/ai-evals.ros checks --suite handling-json-in-common-lisp
```

Start with one sample before selecting a larger matrix:

```bash
qlot exec ros roswell/ai-evals.ros run --suite handling-json-in-common-lisp --filter smoke --agent codex --repeat 1 --label json-baseline
qlot exec ros roswell/ai-evals.ros run --suite handling-json-in-common-lisp --filter smoke --agent opencode --repeat 1 --label json-opencode
```

Run the full catalog explicitly, including holdouts, on both agents:

```bash
qlot exec ros roswell/ai-evals.ros run --suite all --group all --agent all --repeat 1 --label all-skills
```

This includes the original 11 cases and 66 new cases, making 154 samples.
Each suite has its own Promptfoo evaluation. Multi-suite runs also retain
an index under `.evals/batches/`, including failed suites and child run IDs.
Without `--group all`, holdout cases are excluded. Repeats and ablation
multiply the number of model calls; neither is enabled implicitly.

### Working environments

Python, Playwright and Chromium come from Nix. Additional Lisp tools are
pinned in `qlfile.lock`; run `qlot install` after updating the checkout.
Each sample gets its own copied workspace. Preflight checks run before
model calls, including an actual browser launch for browser suites.

The REPL suite connects an isolated persistent Lisp image through MCP.
Its state survives tool calls within that sample. Cache cases use explicit
fixture directories, preserving the user's real ASDF cache. Documentation
and lint cases use the real pinned tools. Deployment cases use a virtual
server with modeled releases, services and health checks; its operations
never invoke real SSH, sudo or systemd.

The prepared browser MCP runner accepts only `./run_smoke_test.sh` and
executes the generated wrapper with the pinned browser. This avoids browser
startup failures inside the agent's subprocess sandbox. It does not generate
or repair candidate tests. The fixture MCP exposes only its profile's tool;
Codex approvals are configured for that private tool, as described in the
[official OpenAI documentation](https://learn.chatgpt.com/docs/extend/mcp).
OpenCode exposes fixture tools directly: its nested execution mode omits
native child-tool results and cannot provide authoritative state evidence.

The default sample deadline remains 240 seconds. For longer tool workflows,
select a larger deadline explicitly, for example `--timeout 600000`.
Timeouts are infrastructure errors and do not prove a skill regression.

### Inspect failures and accumulated results

```bash
qlot exec ros roswell/ai-evals.ros view
qlot exec ros roswell/ai-evals.ros history --suite handling-json-in-common-lisp
qlot exec ros roswell/ai-evals.ros compare BEFORE_RUN_ID AFTER_RUN_ID --suite handling-json-in-common-lisp
qlot exec ros roswell/ai-evals.ros replay RUN_ID
```

Open a failed cell in Promptfoo to inspect its assertion reason. The same
reason is recorded under `.evals/runs/RUN_ID/samples/SAMPLE_ID/grading.json`.
`sample.json` contains collected source files and normalized tool calls;
`turn.json` retains the raw transcript. Binary artifacts, including PNG
screenshots, live beside it under `artifacts/`, with hashes and dimensions
in the artifact metadata. OpenCode also captures files beside its raw provider
trace before returning, so an outer evaluator timeout can recover them into
the standard sample archive. Missing or ambiguous recovery evidence is marked
unavailable instead of being assigned to an unrelated sample. Symbolic links are recorded without following them.

History records suite identity, skill and check fingerprints, fixtures,
environment versions and agent profiles. Runs from different suites cannot
be compared as if they contained the same tasks. Old archives are treated
as the original suite and remain unchanged; replay reports missing evidence
when older formats lack tool calls, binary metadata or environment records.
Replay writes a separate report without replacing original scores.

Explicit Codex tasks in the new suites request a read of the installed
`SKILL.md` file. Native dollar references can inject skill contents before
SDK tool tracing; Promptfoo's heuristic cannot observe that injection.
Automatic activation cases omit the explicit reference. A missing observed
read must not be interpreted as proof that native injection did not happen.

Assertions are independent ASDF extensions. Their calibration tests accept
known-good artifacts and reject deliberately broken artifacts. A valid test
can expose an existing skill defect: do not change the assertion merely to
make the current skill pass. A single smoke sample validates integration;
it does not establish statistical improvement.
""")

(defsection @development (:title "Developing the Lisp systems")
  """
The harness, tests and generated documentation use separate ASDF systems.
The main system uses the `40ants-asdf-system` class and roots its
package-inferred sources at `src/`: each `40ants-ai-evals/*` package maps to
its matching Lisp file, with no compatibility package aliases. For example,
`src/agents.lisp` defines `40ants-ai-evals/agents`.

The test system is `40ants-ai-evals-tests`, rooted at `t/` and using
package-inferred `40ants-ai-evals-tests/*` packages. Its `test-op` runs the
offline Rove suite. For example, `t/suite.lisp` defines
`40ants-ai-evals-tests/suite`.

The separate `40ants-ai-evals-docs` system is rooted at `docs/`. Its
`docs/index.lisp` builds the generated root README and the site under
`docs/build/`; `docs/changelog.lisp` is the source of the project version
(`0.3.0`) as well as the release notes. The docs system's dependencies stay
out of the main runtime system. `README.md` and `ChangeLog.md` are generated
from these sources, and `docs/build/` is ignored by Git. There is no CI docs
build configured.

Run tests in the pinned project environment:

```bash
nix-shell
qlot install
qlot exec ros -e '(asdf:test-system "40ants-ai-evals")'
```

Build the generated README and HTML documentation with the pinned local
documentation dependencies:

```bash
qlot exec ros roswell/build-docs.ros
```

The repository's APM skill packages remain independently installable through
APM. Their package metadata and licensing are unchanged; the root Lisp
systems declare `Unlicense` separately.
""")

(defsection-copy @readme @index)

(defautodoc @api (:system "40ants-ai-evals"))
