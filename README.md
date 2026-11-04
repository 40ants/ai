<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-40README-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

# 40ants-ai-evals — Reproducible skill evaluations in Common Lisp.

<a id="40-ants-ai-evals-asdf-system-details"></a>

## 40ANTS-AI-EVALS ASDF System Details

* Version: 0.4.5
* Description: Reproducible skill evaluations through Promptfoo
* Licence: Unlicense
* Author: Alexander Artemenko
* Homepage: [https://github.com/40ants/ai][d7b8]
* Bug tracker: [https://github.com/40ants/ai/issues][e1fe]
* Source control: [GIT][d7b8]
* Depends on: [asdf][c15d], [babel][3a1f], [cl-ppcre][49b9], [dexador][8347], [ironclad][90b9], [local-time][46a1], [quri][2103], [serapeum][c41d], [yason][aba2]

This repository provides `APM`-installable coding skills and a reproducible
Common Lisp evaluation harness. The harness runs the same behavioral suite
against Codex and OpenCode, records full traces and generated files, and grades
results with Lisp checks.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-40PACKAGES-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## APM skill packages and development

This repository contains `APM`-installable skill packages for coding agents.

The current packages are:

* `common-lisp-skills`: reusable Common Lisp development skills
* `tools`: reusable tooling skills, currently including `nix-shell-playwright`

The recommended installation method is `APM` (Agent Package Manager), because `APM` can install these skills directly from GitHub into multiple agent runtimes, including Codex and OpenCode.

<a id="repository-layout"></a>

### Repository Layout

The `APM`-installable packages are located in:

* `plugins/common-lisp-skills/`
* `plugins/tools/`

<a id="package-contents"></a>

### Package Contents

<a id="common-lisp-skills"></a>

#### `common-lisp-skills`

Includes skills for:

* writing Common Lisp code
* working with the `REPL`
* testing with Rove
* handling `JSON`
* logging with `log4cl`
* defining `CLOS` classes
* writing 40ants-doc documentation
* avoiding common Lisp pitfalls
* clearing stale `ASDF` fasl cache
* linting Common Lisp projects with [Mallet][6975] and [40ants-linter][5fd6]

<a id="tools"></a>

#### `tools`

Includes skills for:

* bootstrapping a reproducible Playwright environment with `nix-shell`
* generating static smoke tests for local `HTML` pages
* running local browser-based smoke tests with screenshot capture
* deploying, updating, and rolling back 40ants pet-project services on `VPS` hosts (`/srv/services` scheme with Caddy and systemd isolation)

<a id="install-from-git-hub-with-apm"></a>

### Install from GitHub with APM

`APM` is the recommended way to consume these packages from another project.

1. Install `APM`.

`macOS` / Linux:

```bash
curl -sSL https://aka.ms/apm-unix | sh
```
Windows (PowerShell):

```bash
irm https://aka.ms/apm-windows | iex
```
1. From the root of your own project, install the package you want for your target agent.

<a id="example-install-all-common-lisp-skills-for-codex"></a>

#### Example: install all Common Lisp skills for Codex

```bash
apm install 40ants/ai/plugins/common-lisp-skills --target codex
```
<a id="example-install-the-tools-plugin-for-codex"></a>

#### Example: install the tools plugin for Codex

```bash
apm install 40ants/ai/plugins/tools --target codex
```
<a id="example-install-the-tools-plugin-for-open-code"></a>

#### Example: install the tools plugin for OpenCode

```bash
apm install 40ants/ai/plugins/tools --target opencode
```
<a id="example-install-only-the-playwright-nix-shell-skill"></a>

#### Example: install only the Playwright nix-shell skill

```bash
apm install 40ants/ai/plugins/tools --target codex --skill nix-shell-playwright
```
<a id="example-install-for-both-codex-and-open-code"></a>

#### Example: install for both Codex and OpenCode

```bash
apm install 40ants/ai/plugins/common-lisp-skills --target codex,opencode
apm install 40ants/ai/plugins/tools --target codex,opencode
```
`APM` installs into the target runtime's native directories. According to the current `APM` docs, `codex` deploys to `.codex/` plus `.agents/` for skills, and `opencode` deploys to `.opencode/`.

After installation, start a new agent session or thread so the new skills are available for invocation.

<a id="persist-in-your-project-s-apm-yml"></a>

### Persist in Your Project's `apm.yml`

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
<a id="updating-in-another-project"></a>

### Updating in Another Project

If your project depends on these packages through `APM`, rerun install in your own project:

```bash
apm install --target codex
```
Or, if you installed a package directly as a package reference:

```bash
apm install 40ants/ai/plugins/tools --target opencode
```
If your agent does not pick up updated skills in the current session, start a new thread or session.

<a id="development-notes"></a>

### Development Notes

* `plugins/common-lisp-skills/apm.yml`
* `plugins/common-lisp-skills/plugin.json`
* `plugins/common-lisp-skills/skills/`
* `plugins/tools/apm.yml`
* `plugins/tools/plugin.json`
* `plugins/tools/skills/`

<a id="local-validation"></a>

### Local Validation

If you want to validate plugin structure with the plugin scaffold validator:

```bash
python3 /Users/art/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py /Users/art/projects/lisp/ai/plugins/common-lisp-skills
python3 /Users/art/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py /Users/art/projects/lisp/ai/plugins/tools
```
Note: this validator requires `PyYAML` in the active Python environment.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-40EVALUATIONS-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## Evaluate skills with Promptfoo

The first behavioral suite is for `writing-common-lisp`. It asks an agent to
edit a disposable project, captures its transcript and generated files, then
reads and runs the Lisp with `SBCL` and Serapeum. The same cases, prompts and
checks run through either Codex or OpenCode. Codex remains the default.

The harness is the `ASDF` system `40ants-ai-evals`, with Roswell entry points.
[ADR 0001][9e7b]
records the original Promptfoo-to-Lisp adapter. [ADR 0003][3116]
records the OpenCode integration. The [JSON protocols][2c24]
keep provider lifecycle, collection and grading in Lisp; JavaScript only carries
`JSON` across Promptfoo's custom-provider boundary.

<a id="1-enter-the-pinned-environment"></a>

### 1. Enter the pinned environment

```bash
cd /Users/art/projects/lisp/ai
nix-shell
qlot install
```
`shell.nix` pins nixpkgs by commit and `SHA-256`, Promptfoo **0.125.1**, Codex
`SDK` and `CLI` **0.156.1**, OpenCode **2.2.1**, `APM` **0.31.0**, Node.js **22.23.4**,
`SBCL` **2.6.8**, Roswell **26.10.117** and Qlot **1.8.2**.
`qlfile` and `qlfile.lock` pin project libraries to Quicklisp **2026-01-01**,
including the same Serapeum release as before the Lisp migration. `nix/promptfoo/package-lock.json` pins the published npm packages
and their complete dependency graph; Nix also checks the downloaded dependency
hash. The native Codex provider requires `SDK` `^0.156.1`, so its matching `CLI`
replaces the previous 0.165.0 `CLI` only inside this shell. OpenCode's pinned
`CLI` is on the shell `PATH`; the Lisp provider calls its `HTTP` `API` v2 directly. The new Promptfoo uses a `SQLite`-backed database;
the old better-sqlite3 rebuild workaround is removed. The shell targets Apple
Silicon `macOS`. Nix downloads dependencies to its store without installing global npm
packages or changing a Homebrew installation/user Nix profile.

The shell uses a `PATH` made from those Nix packages plus `macOS` system utilities.
Global/Homebrew executables are excluded. `SBCL` user initialization is disabled;
Roswell state, compilation caches and Qlot download caches stay under `.evals/`.
Libraries are installed under `.qlot/`; personal Quicklisp is not loaded.
Run all agent shell commands through `qlot exec`. The prepared OpenCode shell
enters Qlot for the whole command, including pipeline segments. Each prepared workspace
describes its runtime in `.eval-environment.json`; the same environment facts
are supplied to both skill and ablation variants. Sample `ASDF` discovery is
restricted to that workspace and the pinned Qlot distribution, so a system
from another suite cannot satisfy a missing local project. For a standalone
file, use `qlot exec sbcl --non-interactive --eval '(asdf:load-system "serapeum")'
--load path/to/module.lisp`; an actual `ASDF` project instead uses its declared
entry system. Expected `UIOP` bootstrap redefinition diagnostics are retained
in `.eval-cache/lisp-startup.log`. Candidate errors and strict documentation
warnings are not suppressed. Preflight tests the sample entry point before
any model call.
Roswell uses the Nix `SBCL` and does not install another Lisp implementation.
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
`APM`'s four Promptfoo skills are installed only into this project's
`.agents/skills/`. `apm.yml` pins their upstream commit and `apm.lock.yaml`
records resolved content. Recreate the installation after a fresh clone:

```bash
apm install --frozen --target codex --only apm
```
Do not run `apm self-update` to respond to its upgrade banner: the shell
deliberately supplies a fixed version. Start a new Codex task in this project
to discover the installed skills.

<a id="2-understand-the-three-pieces-of-an-eval"></a>

### 2. Understand the three pieces of an eval

Open `evals/writing-common-lisp/promptfooconfig.json`:

* `prompts` selects the user request (`{{task}}`).
* the runner selects Promptfoo's native Codex `SDK` provider or the custom
  `evals/lib/opencode-provider.cjs` provider, based on `--agent`.
* Each sample/repeat and skill variant gets a fresh workspace and provider
  session. Artifacts are copied into the run before Promptfoo discards the
  temporary working directory.
* `defaultTest.assert` calls `evals/lib/promptfoo-adapter.cjs`. It sends `JSON` to
  `roswell/ai-evals.ros assert`, which archives files in `src/collector.lisp`.
  The core in `src/checks.lisp` resolves named check plans;
  independent `ASDF` systems under `evals/checks/` implement the rules.
  Real reader/runtime checks execute in a separate process through
  `roswell/check-lisp.ros`. Promptfoo waits for the assertion before cleanup.

The `Contract` assertion includes `return-type-layout`: every Serapeum `->`
signature in the tested source must put its return type on a separate line
with exactly four leading spaces. `SBCL` identifies actual forms and source
positions, so examples in comments or docstrings cannot satisfy the check.
Cases with an explicit project override forbidding Serapeum skip this rule.

`cases.json` supplies inputs and expectations. For example, `package-path`
asks for `src/models/score.lisp` in system `demo`. The expected package is
`demo/src/models/score`; `SBCL` also verifies that `add-score` adds correctly.
Expectations live outside the prompt, so the agent does not see the answer key.

There are **9 development cases** and **2 holdout cases**. Coverage includes
package paths, public exports/docstrings, signatures, `LOOP` style, exhaustive
dispatch, error reporting, unused parameters, hook contracts, project overrides,
protected `.qlot/` dependencies, and a negative Python routing case.

The runner prepares fixture templates with a Git root and a snapshot of the
tested skill. Its default profiles are Codex `gpt-6-sol` at medium effort and
OpenCode `zai-coding-plan/glm-5.3` in build mode. OpenCode's server is
started per run on loopback with private config, cache, data and state directories. It
imports only the `zai-coding-plan` credential from
`~/.local/share/opencode/auth.json`; set `SKILL_EVAL_OPENCODE_AUTH_FILE` to use
another auth file. It does not load personal OpenCode plugins or `MCP` servers.
OpenCode can still apply system-managed policy from
`/Library/Application Support/opencode/opencode.json`; the `API` has no option to
disable that global policy. The Codex path reuses existing Codex file-based
login state. Evaluation calls consume the allowance or `API` credits of the
selected account. No model grader is
used.

<a id="3-calibrate-the-grader-before-trusting-it"></a>

### 3. Calibrate the grader before trusting it

```bash
qlot exec ros roswell/ai-evals.ros test
promptfoo validate config -c evals/writing-common-lisp/promptfooconfig.json
```
Rove replays 47 frozen inputs (36 original calibration inputs plus one real
output for each of the 11 scenarios) and checks
collector/adapter failures, `JSON` round trips, historical exports, coverage,
parameter schemas, profile cycles, evidence caching and an independent `ASDF`
check extension.
The calibration suite checks known-good code and intentional defects, including
wrong arithmetic despite correct style. Passing calibration is evidence about
the grader, not evidence that the skill passed a real model evaluation.

<a id="4-start-with-one-case"></a>

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

Runs default to one repeat. The overall Promptfoo deadline defaults to
240000 ms for Codex and 660000 ms when OpenCode is selected. OpenCode reserves
part of that deadline for interruption, trace export and grading: its execution
timeout is `timeout - min(30000, floor(timeout / 4))`, or 630000 ms by default.
This allows longer model responses; it does not turn failed checks into passes.
The manifest records the overall timeout; the selected profile records its
execution timeout. Codex and OpenCode workflows can have different effective
turn limits, so use within-profile runs to measure skill regressions. Use
`--repeat` and `--timeout` when you intentionally want a larger or longer run.

Codex routing evidence uses Promptfoo's native `metadata.skillCalls`. OpenCode
routing evidence uses recorded completed skill/read tool calls. Both are runtime
evidence, not proof that every instruction affected the answer. Inspect the
archived transcript when a routing result looks wrong.

<a id="5-read-the-accumulated-history"></a>

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
Old runs keep their original `JSONL` artifacts and remain readable in history.

Before the 0.125.1 migration, a consistent `SQLite` backup was saved under
`.evals/backups/before-promptfoo-0.125.1-*/promptfoo.db`. Existing database rows
and run folders are preserved. Re-enter `nix-shell` after pulling this upgrade;
an already-open shell still has the previous tools on its `PATH`. Establish a
new baseline with the upgraded harness before assessing further skill edits.

`.evals/` is ignored by Git. Back up **the whole directory**, including the
Promptfoo database, if you need history to survive deletion of this checkout or
a disk failure. Local accumulation is not an off-machine backup.

To regrade archived samples without model calls or replacing original results:

```bash
qlot exec ros roswell/ai-evals.ros replay RUN_ID
```
This writes `replay-lisp.json` beside the original run. Historical harness
snapshots retain their original `JS` files; active project code uses the Lisp `CLI`.
A migration changes the suite hash and recorded tools, so comparisons across
this boundary require inspecting settings and using `--allow-mismatch` explicitly.
Establish a fresh baseline for subsequent skill edits. The Codex `skill-read`
check retains its earlier semantics: automatic skill injection can still
produce a false negative in Promptfoo's skill-call evidence.

<a id="6-compare-a-change-with-any-earlier-version"></a>

### 6. Compare a change with any earlier version

```bash
# After making one intentional change to SKILL.md:
qlot exec ros roswell/ai-evals.ros run --label candidate --agent opencode --filter package-path
qlot exec ros roswell/ai-evals.ros compare baseline candidate --agent opencode

# Compare both agents from the same run explicitly:
qlot exec ros roswell/ai-evals.ros compare package-both package-both \
  --before-agent codex --after-agent opencode
```
Use unique labels or exact run `ID`s. Same-agent comparison checks the test suite,
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

<a id="7-run-larger-matrices-when-useful"></a>

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
by provider. Per-call `USD` pricing is not known here, so `costUsd: null`
means unknown, not zero. Choose a matrix size intentionally: every sample makes
an evaluation call.

<a id="8-extend-checks-without-changing-the-core"></a>

### 8. Extend checks without changing the core

Cases declare an ordered `vars.checks` array of named checks and profiles.
`defaultTest.vars.checkSystems` selects independent `ASDF` systems that register
those checks. Typed parameters, missing variables and unknown names are
validated before model calls. Boolean checks retain their 0/1 scores;
graded checks can award partial credit independently of mandatory pass decisions.
The `return-type-layout` check awards 0 for a missing signature, 0.5 for an
inline return type and 1 for a return type on a separate line. Partial layout
credit is accepted; a missing signature fails the case. The aggregate score
is the mean of check scores. With 20 checks, a single half-credit layout and
19 full-credit results give 0.975. Original run scores remain unchanged;
replay applies current scoring into a separate report.

See [Adding independent checks][06d2] for a complete
`ASDF` example and the `JSON` format, or inspect the runnable example under
`t/fixtures/example-check/`. [ADR 0002][0ce0]
records the architecture. List the 28 built-in check schemas with:

```bash
qlot exec ros roswell/ai-evals.ros checks
```
<a id="9-add-a-regression-case-before-editing-instructions"></a>

### 9. Add a regression case before editing instructions

1. Reproduce a real failure as one entry in `cases.json`.
2. Write the expected behavior independently of the agent's current output.
3. Add an objective assertion/functional check and calibrate it with a passing
   and failing example in `t/grading/contracts-test.lisp`.
4. Run the old skill to record the failure.
5. Make one targeted skill change, keeping the cases/grader/model fixed.
6. Rerun with the same repeat count and compare exact run `ID`s.
7. Check the holdout set after selecting the change.

The current suite deliberately leaves the skill's conflicting file-layout
wording unscored: the package example starts with a package definition, while
the file-layout paragraph calls `in-package` the first executable form. Resolve
that intended contract before making it a hard assertion. The suite also does
not prove every formatting/naming rule or behavior of related skills.

References: [Promptfoo native Codex SDK provider][6455],
[Promptfoo skill evaluations][ca79],
[APM install and frozen dependencies][4457].

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-40OTHER-SKILLS-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## Evaluate any project skill

The suite catalog in `evals/suites.json` includes all 12 project skills.
The original `writing-common-lisp` remains the default; the other 11 skills
have six cases each: four functional tasks, automatic activation and an
unrelated task. One functional case per skill belongs to the holdout group.
Externally installed `APM` skills are not included.

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
an index under `.evals/batches/`, including failed suites and child run `ID`s.
Without `--group all`, holdout cases are excluded. Repeats and ablation
multiply the number of model calls; neither is enabled implicitly.

<a id="working-environments"></a>

### Working environments

Python, Playwright and Chromium come from Nix. Additional Lisp tools are
pinned in `qlfile.lock`; run `qlot install` after updating the checkout.
Each sample gets its own copied workspace. Preflight checks run before
model calls, including an actual browser launch for browser suites.

The `REPL` suite connects an isolated persistent Lisp image through `MCP`.
Its state survives tool calls within that sample. Cache cases use explicit
fixture directories, preserving the user's real `ASDF` cache. Documentation
and lint cases use the real pinned tools. Deployment cases use a virtual
server with modeled releases, services and health checks; its operations
never invoke real `SSH`, sudo or systemd.

The prepared browser `MCP` runner accepts only `./run_smoke_test.sh` and
executes the generated wrapper with the pinned browser. This avoids browser
startup failures inside the agent's subprocess sandbox. It does not generate
or repair candidate tests. The fixture `MCP` exposes only its profile's tool;
Codex approvals are configured for that private tool, as described in the
[official OpenAI documentation][5dac].
OpenCode exposes fixture tools directly: its nested execution mode omits
native child-tool results and cannot provide authoritative state evidence.

The default sample deadline remains 240 seconds. For longer tool workflows,
select a larger deadline explicitly, for example `--timeout 600000`.
Timeouts are infrastructure errors and do not prove a skill regression.

<a id="file-backed-assertions-and-fixtures"></a>

### File-backed assertions and fixtures

Case inputs live beside each other under the suite directory:

```text
cases/optional-string/
  assertions.lisp
  fixtures/
    src/session.lisp
```
References in `cases.json` are relative to the suite directory:

```json
{
  "fixtures": "cases/optional-string/fixtures/",
  "checks": [
    {
      "check": "skill/lisp-runtime",
      "params": {
        "loadFiles": ["src/session.lisp"],
        "systems": [],
        "assertionsFile": "cases/optional-string/assertions.lisp"
      }
    }
  ]
}
```
Omit `fixtures` when the case has no starting files. Directories can contain
text, `PNG` images and arbitrary binary files. Hidden files, nested directories
and executable permissions are preserved; symbolic links and special files
are rejected. Existing archive limits apply: 2 MiB per text file and 20 MiB
per binary artifact. Paths must stay inside the suite.

`assertions.lisp` contains ordinary Lisp forms. The fresh checking process
loads dependencies, candidate source and runtime helpers before loading this
file. Relative candidate paths and helpers such as `definition`, `forms`,
`nodes` and `op-p` keep their existing meaning. Assertion files are grading
inputs and are not installed in the agent workspace.

Fixture baselines record hashes, sizes and executable bits before the agent
runs, including protected instructions supplied by the harness. Binary changes
are included in preservation checks and the added/modified/deleted inventory.
Input fingerprints change when resource bytes or executable permissions change.
The harness validates inputs before a model call, checks the snapshot against
those inputs and prepares every workspace from that snapshot.

Replay uses archived case inputs with the current check implementation, so
later edits to working-tree fixtures and assertions do not affect an old run.
Legacy inline fixture objects and `assertions` strings remain readable; do not
specify both `assertions` and `assertionsFile` in one check.

<a id="inspect-failures-and-accumulated-results"></a>

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
`turn.json` retains the raw transcript. Binary artifacts, including `PNG`
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
`SDK` tool tracing; Promptfoo's heuristic cannot observe that injection.
Automatic activation cases omit the explicit reference. A missing observed
read must not be interpreted as proof that native injection did not happen.

Assertions are independent `ASDF` extensions. Their calibration tests accept
known-good artifacts and reject deliberately broken artifacts. A valid test
can expose an existing skill defect: do not change the assertion merely to
make the current skill pass. A single smoke sample validates integration;
it does not establish statistical improvement.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-40DEVELOPMENT-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## Developing the Lisp systems

The harness, tests and generated documentation use separate `ASDF` systems.
The main system uses the `40ants-asdf-system` class and roots its
package-inferred sources at `src/`: each `40ants-ai-evals/*` package maps to
its matching Lisp file, with no compatibility package aliases. For example,
`src/agents.lisp` defines `40ants-ai-evals/agents`.

The test system is `40ants-ai-evals-tests`, rooted at `t/` and using
package-inferred `40ants-ai-evals-tests/*` packages. Its `test-op` runs the
offline Rove suite. For example, `t/suite.lisp` defines
`40ants-ai-evals-tests/suite`.

The separate `40ants-ai-evals-docs` system is rooted at `docs/`. Its
`docs/index.lisp` builds the generated root `README` and the site under
`docs/build/`; `docs/changelog.lisp` is the source of the project version
(`0.3.0`) as well as the release notes. The docs system's dependencies stay
out of the main runtime system. `README.md` and `ChangeLog.md` are generated
from these sources, and `docs/build/` is ignored by Git. There is no `CI` docs
build configured.

Run tests in the pinned project environment:

```bash
nix-shell
qlot install
qlot exec ros -e '(asdf:test-system "40ants-ai-evals")'
```
Build the generated `README` and `HTML` documentation with the pinned local
documentation dependencies:

```bash
qlot exec ros roswell/build-docs.ros
```
The repository's `APM` skill packages remain independently installable through
`APM`. Their package metadata and licensing are unchanged; the root Lisp
systems declare `Unlicense` separately.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-40API-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## API

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FAGENTS-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/AGENTS

<a id="x-28-23A-28-2822-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FAGENTS-22-29-20PACKAGE-29"></a>

#### [package](2d98) `40ants-ai-evals/agents`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FAGENTS-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FAGENTS-3APROFILE-FOR-20FUNCTION-29"></a>

##### [function](8c86) `40ants-ai-evals/agents:profile-for` agent flags &optional tools

Copy `AGENT`'s profile, recording only tools relevant to that agent.

<a id="x-2840ANTS-AI-EVALS-2FAGENTS-3APROVIDER-IDENTITY-20FUNCTION-29"></a>

##### [function](02fe) `40ants-ai-evals/agents:provider-identity` label

Decode current labels and historical Codex-only labels into agent and variant.

<a id="x-2840ANTS-AI-EVALS-2FAGENTS-3APROVIDER-LABEL-20FUNCTION-29"></a>

##### [function](b51d) `40ants-ai-evals/agents:provider-label` agent variant

Return an unambiguous provider label for one agent/skill combination.

<a id="x-2840ANTS-AI-EVALS-2FAGENTS-3ARENDER-TASK-20FUNCTION-29"></a>

##### [function](fac1) `40ants-ai-evals/agents:render-task` TASK AGENT &OPTIONAL (SKILL-NAME "writing-common-lisp")

Render explicit references so new suites have observable skill-read evidence.
Codex expands dollar references before `SDK` tool traces, which cannot prove a read.
Automatic routing tasks remain untouched, as does the original suite contract.

<a id="x-2840ANTS-AI-EVALS-2FAGENTS-3ASELECTED-AGENTS-20FUNCTION-29"></a>

##### [function](4c7b) `40ants-ai-evals/agents:selected-agents` flags

Resolve `--agent`; preserve Codex as the default for existing commands.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FAGENTS-3FVariables-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Variables

<a id="x-2840ANTS-AI-EVALS-2FAGENTS-3A-2APROFILES-2A-20-28VARIABLE-29-29"></a>

##### [variable](53e2) `40ants-ai-evals/agents:*profiles*` #<hash-table :test equal :count 2 {8007bbe343}>

Default agent profiles. [`profile-for`][62b3] returns a copy; callers may override one run's model.
`EFFORT` is a Codex setting and is never translated into an OpenCode reasoning option.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FCASE-RESOURCES-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/CASE-RESOURCES

<a id="x-28-23A-28-2830-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FCASE-RESOURCES-22-29-20PACKAGE-29"></a>

#### [package](c133) `40ants-ai-evals/case-resources`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FCASE-RESOURCES-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FCASE-RESOURCES-3ABASELINE-MANIFEST-20FUNCTION-29"></a>

##### [function](1c85) `40ants-ai-evals/case-resources:baseline-manifest` VARS &OPTIONAL (SPEC (FIELD VARS "fixtures"))

Use the frozen baseline including supervisor-added files, or normalize old vars.

<a id="x-2840ANTS-AI-EVALS-2FCASE-RESOURCES-3ACOPY-FIXTURES-20FUNCTION-29"></a>

##### [function](d1a4) `40ants-ai-evals/case-resources:copy-fixtures` vars workspace

Copy inputs from the selected input tree without decoding or following links.

<a id="x-2840ANTS-AI-EVALS-2FCASE-RESOURCES-3AFILE-METADATA-20FUNCTION-29"></a>

##### [function](f568) `40ants-ai-evals/case-resources:file-metadata` path

Describe regular-file bytes and executable bits without following symlinks.

<a id="x-2840ANTS-AI-EVALS-2FCASE-RESOURCES-3AFILE-REFERENCES-20FUNCTION-29"></a>

##### [function](3d0a) `40ants-ai-evals/case-resources:file-references` vars

Read a resource set or a historical array without expanding Promptfoo cases.

<a id="x-2840ANTS-AI-EVALS-2FCASE-RESOURCES-3AFIXTURE-MANIFEST-20FUNCTION-29"></a>

##### [function](c425) `40ants-ai-evals/case-resources:fixture-manifest` VARS &OPTIONAL (SPEC (FIELD VARS "fixtures"))

Read a fixture directory, or normalize a historical inline fixture object.

<a id="x-2840ANTS-AI-EVALS-2FCASE-RESOURCES-3AINPUT-FINGERPRINT-20FUNCTION-29"></a>

##### [function](8510) `40ants-ai-evals/case-resources:input-fingerprint` cases &key fixtures-only

Hash actual case resource bytes and modes from the selected input tree.

<a id="x-2840ANTS-AI-EVALS-2FCASE-RESOURCES-3AMANIFEST-EQUAL-P-20FUNCTION-29"></a>

##### [function](8aa8) `40ants-ai-evals/case-resources:manifest-equal-p` expected actual

Compare complete file sets, bytes and captured executable permissions.

<a id="x-2840ANTS-AI-EVALS-2FCASE-RESOURCES-3AMETADATA-EQUAL-P-20FUNCTION-29"></a>

##### [function](c016) `40ants-ai-evals/case-resources:metadata-equal-p` expected actual

Compare byte identity and permissions when that evidence is available.

<a id="x-2840ANTS-AI-EVALS-2FCASE-RESOURCES-3APRODUCT-PATH-P-20FUNCTION-29"></a>

##### [function](13cc) `40ants-ai-evals/case-resources:product-path-p` path

Exclude evaluation machinery from product file comparisons.

<a id="x-2840ANTS-AI-EVALS-2FCASE-RESOURCES-3ARESOLVE-RESOURCE-20FUNCTION-29"></a>

##### [function](713e) `40ants-ai-evals/case-resources:resolve-resource` vars reference &key directory

Resolve a suite-relative input, rejecting symlinks in every path component.

<a id="x-2840ANTS-AI-EVALS-2FCASE-RESOURCES-3ARESTORE-SAMPLE-20FUNCTION-29"></a>

##### [function](46f0) `40ants-ai-evals/case-resources:restore-sample` sample destination

Restore regular candidate files from verified archives, including binary inputs.

<a id="x-2840ANTS-AI-EVALS-2FCASE-RESOURCES-3ASAMPLE-MANIFEST-20FUNCTION-29"></a>

##### [function](7b2f) `40ants-ai-evals/case-resources:sample-manifest` sample

Describe product evidence, retaining compatibility with text-only archives.

<a id="x-2840ANTS-AI-EVALS-2FCASE-RESOURCES-3AVALIDATE-FIXTURES-20FUNCTION-29"></a>

##### [function](713c) `40ants-ai-evals/case-resources:validate-fixtures` vars

Validate fixture inputs before any paid evaluation starts.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FCASE-RESOURCES-3FVariables-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Variables

<a id="x-2840ANTS-AI-EVALS-2FCASE-RESOURCES-3A-2AINPUTS-ROOT-2A-20-28VARIABLE-29-29"></a>

##### [variable](a174) `40ants-ai-evals/case-resources:*inputs-root*` nil

Input tree for this operation; `NIL` uses the loaded harness.

<a id="x-2840ANTS-AI-EVALS-2FCASE-RESOURCES-3A-2ASAMPLE-DIRECTORY-2A-20-28VARIABLE-29-29"></a>

##### [variable](9f67) `40ants-ai-evals/case-resources:*sample-directory*` nil

Trusted archive directory of the sample being graded.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FCHECKS-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/CHECKS

<a id="x-28-23A-28-2822-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FCHECKS-22-29-20PACKAGE-29"></a>

#### [package](302f) `40ants-ai-evals/checks`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FCHECKS-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3ACACHED-20FUNCTION-29"></a>

##### [function](3528) `40ants-ai-evals/checks:cached` context key compute

Compute shared evidence once per sample, including a cached `NIL` result.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3ACONTEXT-SAMPLE-20FUNCTION-29"></a>

##### [function](7e9b) `40ants-ai-evals/checks:context-sample` context

Return immutable-by-convention sample evidence for a check.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3ACONTEXT-VARS-20FUNCTION-29"></a>

##### [function](db1e) `40ants-ai-evals/checks:context-vars` context

Return the test variables for a check.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3ADESCRIBE-CHECKS-20FUNCTION-29"></a>

##### [function](f749) `40ants-ai-evals/checks:describe-checks`

Return `JSON`-compatible schemas for the checks currently registered.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3AEXECUTE-PLAN-20FUNCTION-29"></a>

##### [function](09be) `40ants-ai-evals/checks:execute-plan` context plan

Execute independent handlers; `NIL` skips a check, a vector emits several results.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3ALOAD-CHECK-SYSTEMS-20FUNCTION-29"></a>

##### [function](6302) `40ants-ai-evals/checks:load-check-systems` systems

Load trusted `ASDF` extensions from explicit project paths or Qlot dependencies.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3AMAKE-CONTEXT-20FUNCTION-29"></a>

##### [function](5791) `40ants-ai-evals/checks:make-context` sample vars

Create a per-sample extension context with an isolated evidence cache.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3AMERGE-VARS-20FUNCTION-29"></a>

##### [function](fc5c) `40ants-ai-evals/checks:merge-vars` defaults overrides

Copy defaults then apply explicit object fields without mutating inputs.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3AOUTCOME-20FUNCTION-29"></a>

##### [function](c8d2) `40ants-ai-evals/checks:outcome` NAME PASS &KEY REASON (SCORE (IF PASS
    1.0d0
    0.0d0))

Return a mandatory pass decision and a score from 0 to 1, defaulting to 0 or 1.
A passing result may award partial credit; its reason remains available.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3AREGISTER-CHECK-20FUNCTION-29"></a>

##### [function](d267) `40ants-ai-evals/checks:register-check` id handler &key (parameters (dict)) (defaults (dict)) validate optional-parameters

Register `HANDLER`(context, parameters), typed parameters, defaults and optional fields.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3AREGISTER-PROFILE-20FUNCTION-29"></a>

##### [function](a022) `40ants-ai-evals/checks:register-profile` id specifications

Register a reusable ordered plan, owned by the registering package.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3AVALIDATE-PLAN-20FUNCTION-29"></a>

##### [function](e1c6) `40ants-ai-evals/checks:validate-plan` vars

Load extensions and resolve a typed plan before spending model calls.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FCLI-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/CLI

<a id="x-28-23A-28-2819-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FCLI-22-29-20PACKAGE-29"></a>

#### [package](2fd0) `40ants-ai-evals/cli`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FCLI-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FCLI-3AMAIN-20FUNCTION-29"></a>

##### [function](893d) `40ants-ai-evals/cli:main` arguments

Run the `CLI`, keeping machine-readable stdout clean for protocol commands.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FCOLLECTOR-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/COLLECTOR

<a id="x-28-23A-28-2825-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FCOLLECTOR-22-29-20PACKAGE-29"></a>

#### [package](e43e) `40ants-ai-evals/collector`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FCOLLECTOR-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FCOLLECTOR-3ACOLLECT-AND-GRADE-20FUNCTION-29"></a>

##### [function](0465) `40ants-ai-evals/collector:collect-and-grade` request

Archive provider evidence before grading, preserving agent identity and raw traces.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FENVIRONMENTS-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/ENVIRONMENTS

<a id="x-28-23A-28-2828-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FENVIRONMENTS-22-29-20PACKAGE-29"></a>

#### [package](a72f) `40ants-ai-evals/environments`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FENVIRONMENTS-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FENVIRONMENTS-3ACODEX-CONFIG-20FUNCTION-29"></a>

##### [function](69c7) `40ants-ai-evals/environments:codex-config` descriptor

Native Codex cli_config injection. Cwd is inherited after native copying.

<a id="x-2840ANTS-AI-EVALS-2FENVIRONMENTS-3AENVIRONMENT-VARIABLES-20FUNCTION-29"></a>

##### [function](af1e) `40ants-ai-evals/environments:environment-variables` descriptor &optional workspace

Environment inherited by the sample's `MCP` process.

<a id="x-2840ANTS-AI-EVALS-2FENVIRONMENTS-3AFINALIZE-20FUNCTION-29"></a>

##### [function](df07) `40ants-ai-evals/environments:finalize` workspace &key vars archive-directory

Collect sample-local state after the provider exits and optionally archive it.

<a id="x-2840ANTS-AI-EVALS-2FENVIRONMENTS-3AOPENCODE-CONFIG-20FUNCTION-29"></a>

##### [function](17ea) `40ants-ai-evals/environments:opencode-config` descriptor

Always select the pinned shell; add sample-local `MCP` servers when needed.

<a id="x-2840ANTS-AI-EVALS-2FENVIRONMENTS-3APREFLIGHT-20FUNCTION-29"></a>

##### [function](9ca8) `40ants-ai-evals/environments:preflight` profile &key (check-tools t)

Return pinned environment identity; fail before a run if tools are missing.

<a id="x-2840ANTS-AI-EVALS-2FENVIRONMENTS-3APREPARE-20FUNCTION-29"></a>

##### [function](7404) `40ants-ai-evals/environments:prepare` workspace vars

Materialize a copyable fixture descriptor; live state starts in the copied cwd.

<a id="x-2840ANTS-AI-EVALS-2FENVIRONMENTS-3APROFILE-NAME-20FUNCTION-29"></a>

##### [function](9efb) `40ants-ai-evals/environments:profile-name` value

Normalize the environment profile declared by a suite.

<a id="x-2840ANTS-AI-EVALS-2FENVIRONMENTS-3AWORKSPACE-INSTRUCTIONS-20FUNCTION-29"></a>

##### [function](5141) `40ants-ai-evals/environments:workspace-instructions`

Describe runtime facts without revealing any skill or assertion requirement.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FGRADING-2FCONTRACTS-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/GRADING/CONTRACTS

<a id="x-28-23A-28-2833-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FGRADING-2FCONTRACTS-22-29-20PACKAGE-29"></a>

#### [package](f780) `40ants-ai-evals/grading/contracts`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FGRADING-2FCONTRACTS-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FGRADING-2FCONTRACTS-3AGRADE-20FUNCTION-29"></a>

##### [function](fee5) `40ants-ai-evals/grading/contracts:grade` output vars &key sample-directory

Run the case's registered checks; infrastructure errors propagate to the collector.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FHISTORY-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/HISTORY

<a id="x-28-23A-28-2823-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FHISTORY-22-29-20PACKAGE-29"></a>

#### [package](9436) `40ants-ai-evals/history`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FHISTORY-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FHISTORY-3ACOMPARE-RUNS-20FUNCTION-29"></a>

##### [function](92ad) `40ants-ai-evals/history:compare-runs` before after &key allow-mismatch agent before-agent after-agent suite

Compare runs for `AGENT`, or select each side with `BEFORE-AGENT` and `AFTER-AGENT`.
Different agent selectors produce an agent/model comparison, not a skill regression.
`ALLOW-MISMATCH` prints fingerprint or same-agent profile differences instead of rejecting them.
Different suite identities are always rejected; `SUITE` restricts both selected runs.

<a id="x-2840ANTS-AI-EVALS-2FHISTORY-3AFIND-RUN-20FUNCTION-29"></a>

##### [function](0f5a) `40ants-ai-evals/history:find-run` id &rest options

Resolve `ID`s, labels and relative selectors, optionally restricted with `:SUITE`.
An optional positional history list preserves the original reader `API`. Exact `ID`s
remain selectable across suites so comparison can report a clear identity error.

<a id="x-2840ANTS-AI-EVALS-2FHISTORY-3AHISTORIES-20FUNCTION-29"></a>

##### [function](aedb) `40ants-ai-evals/history:histories` &OPTIONAL (RUNS-ROOT (AT (ROOT) ".evals/runs/"))

Read accumulated summaries in run `ID` order, including pre-migration runs.

<a id="x-2840ANTS-AI-EVALS-2FHISTORY-3AMAKE-SUMMARY-20FUNCTION-29"></a>

##### [function](3064) `40ants-ai-evals/history:make-summary` manifest exported status &optional (signal :null)

Build a summary from either supported Promptfoo export shape.

<a id="x-2840ANTS-AI-EVALS-2FHISTORY-3APRINT-HISTORY-20FUNCTION-29"></a>

##### [function](e104) `40ants-ai-evals/history:print-history` &key agent suite

List accumulated runs, optionally selecting `SUITE` and counting `AGENT` only.

<a id="x-2840ANTS-AI-EVALS-2FHISTORY-3APRINT-SUMMARY-20FUNCTION-29"></a>

##### [function](d889) `40ants-ai-evals/history:print-summary` summary

Print scores and failures with artifact location.

<a id="x-2840ANTS-AI-EVALS-2FHISTORY-3ASUMMARIZE-20FUNCTION-29"></a>

##### [function](f80b) `40ants-ai-evals/history:summarize` run-dir manifest status

Write a summary beside the original export; leave the database untouched.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/PROVIDERS/OPENCODE

<a id="x-28-23A-28-2834-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-22-29-20PACKAGE-29"></a>

#### [package](0b57) `40ants-ai-evals/providers/opencode`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3ACALL-AGENT-20FUNCTION-29"></a>

##### [function](32cd) `40ants-ai-evals/providers/opencode:call-agent` request

Run one prompt in a fresh workspace/session; retain full and partial raw evidence.
`CONFIG` requires runDir, server and working_dir (or `VARS`.workspaces.opencode.`VARIANT`).
Timeouts interrupt execution before collecting the projected export and durable `SSE` log.

<a id="x-2840ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3AMODEL-REFERENCE-20FUNCTION-29"></a>

##### [function](37e1) `40ants-ai-evals/providers/opencode:model-reference` model

Parse the v2 provider/model`#variant` reference without changing its model name.

<a id="x-2840ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3ANORMALIZE-TRANSCRIPT-20FUNCTION-29"></a>

##### [function](7ef4) `40ants-ai-evals/providers/opencode:normalize-transcript` TRANSCRIPT &OPTIONAL (SKILL-NAME "writing-common-lisp")

Normalize complete v2 export data, deduplicating message and tool identifiers.
Token counts include compaction calls; only completed target skill reads count.

<a id="x-2840ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3ASTART-SERVER-20FUNCTION-29"></a>

##### [function](5900) `40ants-ai-evals/providers/opencode:start-server` RUN-DIR &KEY (EXECUTABLE (OR (UIOP/OS:GETENV "SKILL\_EVAL\_OPENCODE\_BIN") "opencode"))

Start a private loopback OpenCode v2 server and import only the `ZAI` `API` key.
The serializable descriptor references private temporary state; [`stop-server`][7ed9] erases it.

<a id="x-2840ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3ASTOP-SERVER-20FUNCTION-29"></a>

##### [function](7511) `40ants-ai-evals/providers/opencode:stop-server` server

Stop the owned server and remove its private configuration, database and credentials.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3FVariables-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Variables

<a id="x-2840ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3A-2AHTTP-REQUEST-2A-20-28VARIABLE-29-29"></a>

##### [variable](695d) `40ants-ai-evals/providers/opencode:*http-request*` nil

Optional `HTTP` test hook receiving descriptor, method, path, body, timeout and raw-p.
The hook must return an already decoded `JSON` value, or text when `RAW-P` is true.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FRECOVERY-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/RECOVERY

<a id="x-28-23A-28-2824-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FRECOVERY-22-29-20PACKAGE-29"></a>

#### [package](e0a2) `40ants-ai-evals/recovery`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FRECOVERY-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FRECOVERY-3ACAPTURE-20FUNCTION-29"></a>

##### [function](b01f) `40ants-ai-evals/recovery:capture` workspace provider-dir vars normalized trace-path failure

Archive one native provider workspace independently of Promptfoo's deadline.
`VARS` must contain its exact `ID` and variant. Credentials and server state are never
copied: only the sample workspace and an already saved confined provider trace.

<a id="x-2840ANTS-AI-EVALS-2FRECOVERY-3ARECOVER-20FUNCTION-29"></a>

##### [function](f9b3) `40ants-ai-evals/recovery:recover` run-dir

Enrich local failed export rows from exact, unambiguous provider snapshots.
Original scores, success flags and Promptfoo's database are never modified.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FRUNNER-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/RUNNER

<a id="x-28-23A-28-2822-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FRUNNER-22-29-20PACKAGE-29"></a>

#### [package](99f4) `40ants-ai-evals/runner`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FRUNNER-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FRUNNER-3AGRADING-VARS-20FUNCTION-29"></a>

##### [function](c5f4) `40ants-ai-evals/runner:grading-vars` vars

Apply this suite's declared check defaults, keeping historical expectations intact.

<a id="x-2840ANTS-AI-EVALS-2FRUNNER-3AREPLAY-RUN-20FUNCTION-29"></a>

##### [function](679e) `40ants-ai-evals/runner:replay-run` run-dir

Regrade archived samples offline and save a report without changing old scores.

<a id="x-2840ANTS-AI-EVALS-2FRUNNER-3ARUN-EVAL-20FUNCTION-29"></a>

##### [function](40ca) `40ants-ai-evals/runner:run-eval` flags

Evaluate suites separately; retain a durable index for multi-suite batches.

<a id="x-2840ANTS-AI-EVALS-2FRUNNER-3AVALIDATE-OPTIONS-20FUNCTION-29"></a>

##### [function](05cb) `40ants-ai-evals/runner:validate-options` flags

Reject invalid options before creating any run or contacting the model.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FSUITES-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/SUITES

<a id="x-28-23A-28-2822-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FSUITES-22-29-20PACKAGE-29"></a>

#### [package](41eb) `40ants-ai-evals/suites`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FSUITES-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FSUITES-3ACATALOG-20FUNCTION-29"></a>

##### [function](cd34) `40ants-ai-evals/suites:catalog`

Read the project catalog, accepting old snapshots without a catalog.

<a id="x-2840ANTS-AI-EVALS-2FSUITES-3ADESCRIBE-SUITES-20FUNCTION-29"></a>

##### [function](3586) `40ants-ai-evals/suites:describe-suites`

Describe case counts without evaluating tools or contacting a model.

<a id="x-2840ANTS-AI-EVALS-2FSUITES-3AFIND-SUITE-20FUNCTION-29"></a>

##### [function](4aef) `40ants-ai-evals/suites:find-suite` &optional id

Resolve a suite, defaulting to the original writing-common-lisp suite.

<a id="x-2840ANTS-AI-EVALS-2FSUITES-3ASELECTED-SUITES-20FUNCTION-29"></a>

##### [function](c3e1) `40ants-ai-evals/suites:selected-suites` flags

<a id="x-2840ANTS-AI-EVALS-2FSUITES-3ASUITE-PATH-20FUNCTION-29"></a>

##### [function](91c8) `40ants-ai-evals/suites:suite-path` &optional id

Return the suite configuration's relative directory.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FUTIL-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/UTIL

<a id="x-28-23A-28-2820-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FUTIL-22-29-20PACKAGE-29"></a>

#### [package](479e) `40ants-ai-evals/util`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FUTIL-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AAT-20FUNCTION-29"></a>

##### [function](6a99) `40ants-ai-evals/util:at` directory relative

Resolve `RELATIVE` inside `DIRECTORY`.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ABOOL-20FUNCTION-29"></a>

##### [function](760d) `40ants-ai-evals/util:bool` value

Represent a Lisp predicate as an unambiguous `JSON` boolean.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ACOPY-DIRECTORY-20FUNCTION-29"></a>

##### [function](415b) `40ants-ai-evals/util:copy-directory` source destination &key ignore-editor-locks

Copy a plain tree without following symbolic links.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ADECODE-20FUNCTION-29"></a>

##### [function](d088) `40ants-ai-evals/util:decode` input

Decode `JSON` with distinct arrays, booleans and null values.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ADIGEST-FILE-20FUNCTION-29"></a>

##### [function](3be3) `40ants-ai-evals/util:digest-file` file

Return a file's `SHA-256` digest.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ADIGEST-TREE-20FUNCTION-29"></a>

##### [function](3880) `40ants-ai-evals/util:digest-tree` directory

Hash sorted relative paths and bytes using the legacy runner's format.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AENCODE-20FUNCTION-29"></a>

##### [function](5958) `40ants-ai-evals/util:encode` value

Encode a `JSON` value into a `UTF-8` compatible Lisp string.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AFIELD-20FUNCTION-29"></a>

##### [function](2b9d) `40ants-ai-evals/util:field` object &rest keys

Read nested `JSON` object fields, returning `NIL` for missing keys.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AJSON-EQUAL-P-20FUNCTION-29"></a>

##### [function](b06c) `40ants-ai-evals/util:json-equal-p` left right

Compare `JSON` values independently of object key order.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ANOW-20FUNCTION-29"></a>

##### [function](ca30) `40ants-ai-evals/util:now`

Return an `ISO` timestamp in `UTC`.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AREAD-JSON-20FUNCTION-29"></a>

##### [function](6f25) `40ants-ai-evals/util:read-json` file

Read `JSON` from `FILE`.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AREMOVE-DIRECTORY-20FUNCTION-29"></a>

##### [function](0269) `40ants-ai-evals/util:remove-directory` directory

Remove a directory created or owned by the harness.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AROOT-20FUNCTION-29"></a>

##### [function](7591) `40ants-ai-evals/util:root`

Return this loaded harness's project root, including archived harnesses.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ARUN-COMMAND-20FUNCTION-29"></a>

##### [function](63cf) `40ants-ai-evals/util:run-command` argv &key (directory (root)) input (timeout 120) log-prefix allow-failure

Run `ARGV` without a shell; capture logs and kill timed-out subprocesses.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ASAFE-RELATIVE-P-20FUNCTION-29"></a>

##### [function](c5cf) `40ants-ai-evals/util:safe-relative-p` relative

Recognize portable fixture paths confined to a workspace.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ASEQUENCE-LIST-20FUNCTION-29"></a>

##### [function](4959) `40ants-ai-evals/util:sequence-list` value

Convert a `JSON` array to a list; treat absent/null arrays as empty.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ATEMPORARY-DIRECTORY-20FUNCTION-29"></a>

##### [function](d811) `40ants-ai-evals/util:temporary-directory` &OPTIONAL (PREFIX "ai-evals")

Allocate a private directory under the operating system's temporary root.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ATREE-FILES-20FUNCTION-29"></a>

##### [function](f99a) `40ants-ai-evals/util:tree-files` directory &key exclude ignore-editor-locks

Return sorted relative files; reject symlinks before following directories.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ATRUE-P-20FUNCTION-29"></a>

##### [function](287e) `40ants-ai-evals/util:true-p` value

Recognize Lisp T or a decoded `JSON` true.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AUNIQUE-ID-20FUNCTION-29"></a>

##### [function](5ff2) `40ants-ai-evals/util:unique-id`

Return a fresh identifier allocated by the operating system.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AWRITE-JSON-20FUNCTION-29"></a>

##### [function](52e0) `40ants-ai-evals/util:write-json` file value

Persist a `JSON` document with a trailing newline.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AWRITE-TEXT-20FUNCTION-29"></a>

##### [function](e132) `40ants-ai-evals/util:write-text` file text

Write `UTF-8` `TEXT`, creating parent directories.


[ca79]: https://developers.openai.com/blog/eval-skills
[d7b8]: https://github.com/40ants/ai
[53e2]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/agents.lisp#L11
[2d98]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/agents.lisp#L2
[4c7b]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/agents.lisp#L20
[8c86]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/agents.lisp#L29
[b51d]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/agents.lisp#L49
[02fe]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/agents.lisp#L55
[fac1]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/agents.lisp#L65
[713c]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/case-resources.lisp#L113
[d1a4]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/case-resources.lisp#L128
[1c85]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/case-resources.lisp#L143
[13cc]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/case-resources.lisp#L154
[7b2f]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/case-resources.lisp#L166
[c016]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/case-resources.lisp#L181
[a174]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/case-resources.lisp#L19
[8aa8]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/case-resources.lisp#L193
[c133]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/case-resources.lisp#L2
[9f67]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/case-resources.lisp#L20
[46f0]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/case-resources.lisp#L201
[3d0a]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/case-resources.lisp#L240
[8510]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/case-resources.lisp#L249
[713e]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/case-resources.lisp#L31
[f568]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/case-resources.lisp#L56
[c425]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/case-resources.lisp#L90
[e1c6]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/checks.lisp#L193
[302f]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/checks.lisp#L2
[5791]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/checks.lisp#L205
[7e9b]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/checks.lisp#L211
[db1e]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/checks.lisp#L217
[fc5c]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/checks.lisp#L22
[3528]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/checks.lisp#L223
[c8d2]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/checks.lisp#L231
[09be]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/checks.lisp#L243
[f749]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/checks.lisp#L267
[d267]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/checks.lisp#L33
[a022]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/checks.lisp#L52
[6302]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/checks.lisp#L62
[893d]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/cli.lisp#L140
[2fd0]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/cli.lisp#L2
[e43e]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/collector.lisp#L2
[0465]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/collector.lisp#L217
[7404]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/environments.lisp#L145
[9efb]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/environments.lisp#L17
[a72f]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/environments.lisp#L2
[af1e]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/environments.lisp#L200
[69c7]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/environments.lisp#L223
[5141]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/environments.lisp#L24
[17ea]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/environments.lisp#L240
[df07]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/environments.lisp#L278
[9ca8]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/environments.lisp#L58
[fee5]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/grading/contracts.lisp#L14
[f780]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/grading/contracts.lisp#L2
[3064]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/history.lisp#L158
[9436]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/history.lisp#L2
[f80b]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/history.lisp#L220
[d889]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/history.lisp#L229
[e104]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/history.lisp#L307
[92ad]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/history.lisp#L326
[aedb]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/history.lisp#L69
[0f5a]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/history.lisp#L78
[7511]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/providers/opencode.lisp#L132
[37e1]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/providers/opencode.lisp#L146
[695d]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/providers/opencode.lisp#L19
[7ef4]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/providers/opencode.lisp#L191
[0b57]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/providers/opencode.lisp#L2
[32cd]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/providers/opencode.lisp#L364
[5900]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/providers/opencode.lisp#L87
[f9b3]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/recovery.lisp#L153
[b01f]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/recovery.lisp#L17
[e0a2]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/recovery.lisp#L2
[99f4]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/runner.lisp#L2
[679e]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/runner.lisp#L574
[05cb]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/runner.lisp#L62
[40ca]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/runner.lisp#L622
[c5f4]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/runner.lisp#L92
[cd34]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/suites.lisp#L12
[41eb]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/suites.lisp#L2
[4aef]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/suites.lisp#L36
[91c8]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/suites.lisp#L44
[c3e1]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/suites.lisp#L50
[3586]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/suites.lisp#L56
[d811]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L100
[0269]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L110
[63cf]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L118
[f99a]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L154
[415b]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L177
[3be3]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L191
[479e]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L2
[2b9d]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L20
[3880]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L205
[4959]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L219
[b06c]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L225
[c5cf]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L236
[287e]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L27
[760d]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L33
[d088]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L39
[5958]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L46
[6f25]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L52
[e132]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L58
[52e0]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L68
[7591]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L74
[6a99]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L80
[5ff2]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L86
[ca30]: https://github.com/40ants/ai/blob/18c41f4322f4b1e9ee80c7490453c45ea8ba390c/src/util.lisp#L93
[2c24]: https://github.com/40ants/ai/blob/master/evals/docs/adapter-protocol.md
[9e7b]: https://github.com/40ants/ai/blob/master/evals/docs/decisions/0001-common-lisp-with-promptfoo-js-adapter.md
[0ce0]: https://github.com/40ants/ai/blob/master/evals/docs/decisions/0002-extensible-checks.md
[3116]: https://github.com/40ants/ai/blob/master/evals/docs/decisions/0003-opencode-2.md
[06d2]: https://github.com/40ants/ai/blob/master/evals/docs/extending-checks.md
[e1fe]: https://github.com/40ants/ai/issues
[5fd6]: https://github.com/40ants/linter
[6975]: https://github.com/fukamachi/mallet
[5dac]: https://learn.chatgpt.com/docs/extend/mcp
[4457]: https://microsoft.github.io/apm/reference/cli/install/
[c15d]: https://quickdocs.org/asdf
[3a1f]: https://quickdocs.org/babel
[49b9]: https://quickdocs.org/cl-ppcre
[8347]: https://quickdocs.org/dexador
[90b9]: https://quickdocs.org/ironclad
[46a1]: https://quickdocs.org/local-time
[2103]: https://quickdocs.org/quri
[c41d]: https://quickdocs.org/serapeum
[aba2]: https://quickdocs.org/yason
[6455]: https://www.promptfoo.dev/docs/providers/openai-codex-sdk/
[62b3]: index.html#x-2840ANTS-AI-EVALS-2FAGENTS-3APROFILE-FOR-20FUNCTION-29
[7ed9]: index.html#x-2840ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3ASTOP-SERVER-20FUNCTION-29

* * *
###### [generated by [40ANTS-DOC](https://40ants.com/doc/)]
