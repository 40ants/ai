<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-40README-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

# 40ants-ai-evals — Reproducible skill evaluations in Common Lisp.

<a id="40-ants-ai-evals-asdf-system-details"></a>

## 40ANTS-AI-EVALS ASDF System Details

* Version: 0.2.0
* Description: Reproducible skill evaluations through Promptfoo
* Licence: Unlicense
* Author: Alexander Artemenko
* Homepage: [https://github.com/40ants/ai][d7b8]
* Bug tracker: [https://github.com/40ants/ai/issues][e1fe]
* Source control: [GIT][d7b8]
* Depends on: [asdf][c15d], [babel][3a1f], [cl-ppcre][49b9], [dexador][8347], [ironclad][90b9], [local-time][46a1], [serapeum][c41d], [yason][aba2]

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
validated before model calls. The built-in rules retain their previous scores.

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
(`0.2.0`) as well as the release notes. The docs system's dependencies stay
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

#### [package](0745) `40ants-ai-evals/agents`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FAGENTS-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FAGENTS-3APROFILE-FOR-20FUNCTION-29"></a>

##### [function](f4ff) `40ants-ai-evals/agents:profile-for` agent flags &optional tools

Copy `AGENT`'s profile, recording only tools relevant to that agent.

<a id="x-2840ANTS-AI-EVALS-2FAGENTS-3APROVIDER-IDENTITY-20FUNCTION-29"></a>

##### [function](c521) `40ants-ai-evals/agents:provider-identity` label

Decode current labels and historical Codex-only labels into agent and variant.

<a id="x-2840ANTS-AI-EVALS-2FAGENTS-3APROVIDER-LABEL-20FUNCTION-29"></a>

##### [function](194c) `40ants-ai-evals/agents:provider-label` agent variant

Return an unambiguous provider label for one agent/skill combination.

<a id="x-2840ANTS-AI-EVALS-2FAGENTS-3ARENDER-TASK-20FUNCTION-29"></a>

##### [function](696e) `40ants-ai-evals/agents:render-task` task agent

Adapt explicit native skill references while leaving the requested task intact.

<a id="x-2840ANTS-AI-EVALS-2FAGENTS-3ASELECTED-AGENTS-20FUNCTION-29"></a>

##### [function](9a25) `40ants-ai-evals/agents:selected-agents` flags

Resolve `--agent`; preserve Codex as the default for existing commands.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FAGENTS-3FVariables-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Variables

<a id="x-2840ANTS-AI-EVALS-2FAGENTS-3A-2APROFILES-2A-20-28VARIABLE-29-29"></a>

##### [variable](7848) `40ants-ai-evals/agents:*profiles*` #<hash-table :test equal :count 2 {80081eadc3}>

Default agent profiles. [`profile-for`][62b3] returns a copy; callers may override one run's model.
`EFFORT` is a Codex setting and is never translated into an OpenCode reasoning option.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FCHECKS-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/CHECKS

<a id="x-28-23A-28-2822-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FCHECKS-22-29-20PACKAGE-29"></a>

#### [package](9722) `40ants-ai-evals/checks`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FCHECKS-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3ACACHED-20FUNCTION-29"></a>

##### [function](b74c) `40ants-ai-evals/checks:cached` context key compute

Compute shared evidence once per sample, including a cached `NIL` result.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3ACONTEXT-SAMPLE-20FUNCTION-29"></a>

##### [function](cf84) `40ants-ai-evals/checks:context-sample` context

Return immutable-by-convention sample evidence for a check.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3ACONTEXT-VARS-20FUNCTION-29"></a>

##### [function](335f) `40ants-ai-evals/checks:context-vars` context

Return the test variables for a check.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3ADESCRIBE-CHECKS-20FUNCTION-29"></a>

##### [function](4989) `40ants-ai-evals/checks:describe-checks`

Return `JSON`-compatible schemas for the checks currently registered.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3AEXECUTE-PLAN-20FUNCTION-29"></a>

##### [function](6352) `40ants-ai-evals/checks:execute-plan` context plan

Execute independent handlers; `NIL` skips a check, a vector emits several results.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3ALOAD-CHECK-SYSTEMS-20FUNCTION-29"></a>

##### [function](19ed) `40ants-ai-evals/checks:load-check-systems` systems

Load trusted `ASDF` extensions from explicit project paths or Qlot dependencies.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3AMAKE-CONTEXT-20FUNCTION-29"></a>

##### [function](7a24) `40ants-ai-evals/checks:make-context` sample vars

Create a per-sample extension context with an isolated evidence cache.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3AMERGE-VARS-20FUNCTION-29"></a>

##### [function](50b9) `40ants-ai-evals/checks:merge-vars` defaults overrides

Copy defaults then apply explicit object fields without mutating inputs.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3AOUTCOME-20FUNCTION-29"></a>

##### [function](b530) `40ants-ai-evals/checks:outcome` name pass &key reason

Return one boolean check result with an optional failure explanation.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3AREGISTER-CHECK-20FUNCTION-29"></a>

##### [function](4ab2) `40ants-ai-evals/checks:register-check` id handler &key (parameters (dict)) (defaults (dict)) validate

Register `HANDLER`(context, parameters), with required typed parameters and defaults.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3AREGISTER-PROFILE-20FUNCTION-29"></a>

##### [function](f0a9) `40ants-ai-evals/checks:register-profile` id specifications

Register a reusable ordered plan, owned by the registering package.

<a id="x-2840ANTS-AI-EVALS-2FCHECKS-3AVALIDATE-PLAN-20FUNCTION-29"></a>

##### [function](e689) `40ants-ai-evals/checks:validate-plan` vars

Load extensions and resolve a typed plan before spending model calls.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FCLI-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/CLI

<a id="x-28-23A-28-2819-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FCLI-22-29-20PACKAGE-29"></a>

#### [package](6f9f) `40ants-ai-evals/cli`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FCLI-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FCLI-3AMAIN-20FUNCTION-29"></a>

##### [function](92fe) `40ants-ai-evals/cli:main` arguments

Run the `CLI`, keeping machine-readable stdout clean for protocol commands.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FCOLLECTOR-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/COLLECTOR

<a id="x-28-23A-28-2825-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FCOLLECTOR-22-29-20PACKAGE-29"></a>

#### [package](8f57) `40ants-ai-evals/collector`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FCOLLECTOR-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FCOLLECTOR-3ACOLLECT-AND-GRADE-20FUNCTION-29"></a>

##### [function](eb0e) `40ants-ai-evals/collector:collect-and-grade` request

Archive provider evidence before grading, preserving agent identity and raw traces.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FGRADING-2FCONTRACTS-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/GRADING/CONTRACTS

<a id="x-28-23A-28-2833-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FGRADING-2FCONTRACTS-22-29-20PACKAGE-29"></a>

#### [package](d98f) `40ants-ai-evals/grading/contracts`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FGRADING-2FCONTRACTS-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FGRADING-2FCONTRACTS-3AGRADE-20FUNCTION-29"></a>

##### [function](a106) `40ants-ai-evals/grading/contracts:grade` output vars

Run the case's registered checks; infrastructure errors propagate to the collector.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FHISTORY-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/HISTORY

<a id="x-28-23A-28-2823-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FHISTORY-22-29-20PACKAGE-29"></a>

#### [package](476c) `40ants-ai-evals/history`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FHISTORY-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FHISTORY-3ACOMPARE-RUNS-20FUNCTION-29"></a>

##### [function](818f) `40ants-ai-evals/history:compare-runs` before after &key allow-mismatch agent before-agent after-agent

Compare runs for `AGENT`, or select each side with `BEFORE-AGENT` and `AFTER-AGENT`.
Different agent selectors produce an agent/model comparison, not a skill regression.
`ALLOW-MISMATCH` prints suite or same-agent profile differences instead of rejecting them.

<a id="x-2840ANTS-AI-EVALS-2FHISTORY-3AFIND-RUN-20FUNCTION-29"></a>

##### [function](1203) `40ants-ai-evals/history:find-run` id &optional (all (histories))

Resolve an exact `ID`, unique label, latest or previous.

<a id="x-2840ANTS-AI-EVALS-2FHISTORY-3AHISTORIES-20FUNCTION-29"></a>

##### [function](669e) `40ants-ai-evals/history:histories` &OPTIONAL (RUNS-ROOT (AT (ROOT) ".evals/runs/"))

Read accumulated summaries in run `ID` order, including pre-migration runs.

<a id="x-2840ANTS-AI-EVALS-2FHISTORY-3AMAKE-SUMMARY-20FUNCTION-29"></a>

##### [function](93ab) `40ants-ai-evals/history:make-summary` manifest exported status &optional (signal :null)

Build a summary from either supported Promptfoo export shape.

<a id="x-2840ANTS-AI-EVALS-2FHISTORY-3APRINT-HISTORY-20FUNCTION-29"></a>

##### [function](2d97) `40ants-ai-evals/history:print-history` &key agent

List accumulated runs, optionally counting rows for `AGENT` only.

<a id="x-2840ANTS-AI-EVALS-2FHISTORY-3APRINT-SUMMARY-20FUNCTION-29"></a>

##### [function](136e) `40ants-ai-evals/history:print-summary` summary

Print scores and failures with artifact location.

<a id="x-2840ANTS-AI-EVALS-2FHISTORY-3ASUMMARIZE-20FUNCTION-29"></a>

##### [function](8f0b) `40ants-ai-evals/history:summarize` run-dir manifest status

Write a summary beside the original export; leave the database untouched.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/PROVIDERS/OPENCODE

<a id="x-28-23A-28-2834-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-22-29-20PACKAGE-29"></a>

#### [package](ce21) `40ants-ai-evals/providers/opencode`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3ACALL-AGENT-20FUNCTION-29"></a>

##### [function](70e7) `40ants-ai-evals/providers/opencode:call-agent` request

Run one prompt in a fresh workspace/session; retain full and partial raw evidence.
`CONFIG` requires runDir, server and working_dir (or `VARS`.workspaces.opencode.`VARIANT`).
Timeouts interrupt execution before collecting the projected export and durable `SSE` log.

<a id="x-2840ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3AMODEL-REFERENCE-20FUNCTION-29"></a>

##### [function](aa20) `40ants-ai-evals/providers/opencode:model-reference` model

Parse the v2 provider/model`#variant` reference without changing its model name.

<a id="x-2840ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3ANORMALIZE-TRANSCRIPT-20FUNCTION-29"></a>

##### [function](8935) `40ants-ai-evals/providers/opencode:normalize-transcript` transcript

Normalize complete v2 export data, deduplicating message and tool identifiers.
Token counts include compaction calls; only completed target skill reads count.

<a id="x-2840ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3ASTART-SERVER-20FUNCTION-29"></a>

##### [function](5a24) `40ants-ai-evals/providers/opencode:start-server` RUN-DIR &KEY (EXECUTABLE (OR (UIOP/OS:GETENV "SKILL\_EVAL\_OPENCODE\_BIN") "opencode"))

Start a private loopback OpenCode v2 server and import only the `ZAI` `API` key.
The serializable descriptor references private temporary state; [`stop-server`][7ed9] erases it.

<a id="x-2840ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3ASTOP-SERVER-20FUNCTION-29"></a>

##### [function](d4ac) `40ants-ai-evals/providers/opencode:stop-server` server

Stop the owned server and remove its private configuration, database and credentials.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3FVariables-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Variables

<a id="x-2840ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3A-2AHTTP-REQUEST-2A-20-28VARIABLE-29-29"></a>

##### [variable](9615) `40ants-ai-evals/providers/opencode:*http-request*` nil

Optional `HTTP` test hook receiving descriptor, method, path, body, timeout and raw-p.
The hook must return an already decoded `JSON` value, or text when `RAW-P` is true.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FRUNNER-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/RUNNER

<a id="x-28-23A-28-2822-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FRUNNER-22-29-20PACKAGE-29"></a>

#### [package](ad97) `40ants-ai-evals/runner`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FRUNNER-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FRUNNER-3AGRADING-VARS-20FUNCTION-29"></a>

##### [function](3825) `40ants-ai-evals/runner:grading-vars` vars

Apply this suite's declared check defaults, keeping historical expectations intact.

<a id="x-2840ANTS-AI-EVALS-2FRUNNER-3AREPLAY-RUN-20FUNCTION-29"></a>

##### [function](170f) `40ants-ai-evals/runner:replay-run` run-dir

Regrade archived samples offline and save a report without changing old scores.

<a id="x-2840ANTS-AI-EVALS-2FRUNNER-3ARUN-EVAL-20FUNCTION-29"></a>

##### [function](8ca2) `40ants-ai-evals/runner:run-eval` flags

Snapshot a run and evaluate selected agent profiles on the same check plans.

<a id="x-2840ANTS-AI-EVALS-2FRUNNER-3AVALIDATE-OPTIONS-20FUNCTION-29"></a>

##### [function](6e72) `40ants-ai-evals/runner:validate-options` flags

Reject invalid options before creating any run or contacting the model.

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-4040ANTS-AI-EVALS-2FUTIL-3FPACKAGE-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

### 40ANTS-AI-EVALS/UTIL

<a id="x-28-23A-28-2820-29-20BASE-CHAR-20-2E-20-2240ANTS-AI-EVALS-2FUTIL-22-29-20PACKAGE-29"></a>

#### [package](faad) `40ants-ai-evals/util`

<a id="x-2840ANTS-AI-EVALS-DOCS-2FINDEX-3A-3A-7C-4040ANTS-AI-EVALS-2FUTIL-3FFunctions-SECTION-7C-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

#### Functions

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AAT-20FUNCTION-29"></a>

##### [function](6841) `40ants-ai-evals/util:at` directory relative

Resolve `RELATIVE` inside `DIRECTORY`.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ABOOL-20FUNCTION-29"></a>

##### [function](0910) `40ants-ai-evals/util:bool` value

Represent a Lisp predicate as an unambiguous `JSON` boolean.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ACOPY-DIRECTORY-20FUNCTION-29"></a>

##### [function](8b9c) `40ants-ai-evals/util:copy-directory` source destination

Copy a plain tree without following symbolic links.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ADECODE-20FUNCTION-29"></a>

##### [function](9f5c) `40ants-ai-evals/util:decode` input

Decode `JSON` with distinct arrays, booleans and null values.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ADIGEST-FILE-20FUNCTION-29"></a>

##### [function](3f92) `40ants-ai-evals/util:digest-file` file

Return a file's `SHA-256` digest.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ADIGEST-TREE-20FUNCTION-29"></a>

##### [function](bc71) `40ants-ai-evals/util:digest-tree` directory

Hash sorted relative paths and bytes using the legacy runner's format.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AENCODE-20FUNCTION-29"></a>

##### [function](ea1e) `40ants-ai-evals/util:encode` value

Encode a `JSON` value into a `UTF-8` compatible Lisp string.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AFIELD-20FUNCTION-29"></a>

##### [function](bdad) `40ants-ai-evals/util:field` object &rest keys

Read nested `JSON` object fields, returning `NIL` for missing keys.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AJSON-EQUAL-P-20FUNCTION-29"></a>

##### [function](9e16) `40ants-ai-evals/util:json-equal-p` left right

Compare `JSON` values independently of object key order.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ANOW-20FUNCTION-29"></a>

##### [function](00cf) `40ants-ai-evals/util:now`

Return an `ISO` timestamp in `UTC`.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AREAD-JSON-20FUNCTION-29"></a>

##### [function](e357) `40ants-ai-evals/util:read-json` file

Read `JSON` from `FILE`.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AREMOVE-DIRECTORY-20FUNCTION-29"></a>

##### [function](a5c9) `40ants-ai-evals/util:remove-directory` directory

Remove a directory created or owned by the harness.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AROOT-20FUNCTION-29"></a>

##### [function](3f56) `40ants-ai-evals/util:root`

Return this loaded harness's project root, including archived harnesses.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ARUN-COMMAND-20FUNCTION-29"></a>

##### [function](d2ad) `40ants-ai-evals/util:run-command` argv &key (directory (root)) input (timeout 120) log-prefix allow-failure

Run `ARGV` without a shell; capture logs and kill timed-out subprocesses.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ASAFE-RELATIVE-P-20FUNCTION-29"></a>

##### [function](8763) `40ants-ai-evals/util:safe-relative-p` relative

Recognize portable fixture paths confined to a workspace.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ASEQUENCE-LIST-20FUNCTION-29"></a>

##### [function](d6f2) `40ants-ai-evals/util:sequence-list` value

Convert a `JSON` array to a list; treat absent/null arrays as empty.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ATEMPORARY-DIRECTORY-20FUNCTION-29"></a>

##### [function](3e7e) `40ants-ai-evals/util:temporary-directory` &OPTIONAL (PREFIX "ai-evals")

Allocate a private directory under the operating system's temporary root.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ATREE-FILES-20FUNCTION-29"></a>

##### [function](61ee) `40ants-ai-evals/util:tree-files` directory &key exclude

Return sorted relative files; reject symlinks before following directories.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3ATRUE-P-20FUNCTION-29"></a>

##### [function](adff) `40ants-ai-evals/util:true-p` value

Recognize Lisp T or a decoded `JSON` true.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AUNIQUE-ID-20FUNCTION-29"></a>

##### [function](dcc9) `40ants-ai-evals/util:unique-id`

Return a fresh identifier allocated by the operating system.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AWRITE-JSON-20FUNCTION-29"></a>

##### [function](ef6d) `40ants-ai-evals/util:write-json` file value

Persist a `JSON` document with a trailing newline.

<a id="x-2840ANTS-AI-EVALS-2FUTIL-3AWRITE-TEXT-20FUNCTION-29"></a>

##### [function](8400) `40ants-ai-evals/util:write-text` file text

Write `UTF-8` `TEXT`, creating parent directories.


[ca79]: https://developers.openai.com/blog/eval-skills
[d7b8]: https://github.com/40ants/ai
[7848]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/agents.lisp#L11
[0745]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/agents.lisp#L2
[9a25]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/agents.lisp#L20
[f4ff]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/agents.lisp#L29
[194c]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/agents.lisp#L49
[c521]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/agents.lisp#L55
[696e]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/agents.lisp#L65
[e689]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/checks.lisp#L179
[7a24]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/checks.lisp#L191
[cf84]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/checks.lisp#L197
[9722]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/checks.lisp#L2
[335f]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/checks.lisp#L203
[b74c]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/checks.lisp#L209
[50b9]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/checks.lisp#L21
[b530]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/checks.lisp#L217
[6352]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/checks.lisp#L225
[4989]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/checks.lisp#L243
[4ab2]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/checks.lisp#L32
[f0a9]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/checks.lisp#L48
[19ed]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/checks.lisp#L58
[92fe]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/cli.lisp#L129
[6f9f]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/cli.lisp#L2
[8f57]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/collector.lisp#L2
[eb0e]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/collector.lisp#L63
[a106]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/grading/contracts.lisp#L13
[d98f]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/grading/contracts.lisp#L2
[93ab]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/history.lisp#L143
[476c]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/history.lisp#L2
[8f0b]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/history.lisp#L201
[136e]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/history.lisp#L210
[2d97]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/history.lisp#L286
[818f]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/history.lisp#L305
[669e]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/history.lisp#L63
[1203]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/history.lisp#L72
[d4ac]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/providers/opencode.lisp#L127
[aa20]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/providers/opencode.lisp#L141
[9615]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/providers/opencode.lisp#L16
[8935]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/providers/opencode.lisp#L172
[ce21]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/providers/opencode.lisp#L2
[70e7]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/providers/opencode.lisp#L284
[5a24]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/providers/opencode.lisp#L82
[ad97]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/runner.lisp#L2
[8ca2]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/runner.lisp#L364
[170f]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/runner.lisp#L439
[6e72]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/runner.lisp#L49
[3825]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/runner.lisp#L78
[3e7e]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L100
[a5c9]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L110
[d2ad]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L118
[61ee]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L154
[8b9c]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L174
[3f92]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L185
[bc71]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L199
[faad]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L2
[bdad]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L20
[d6f2]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L213
[9e16]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L219
[8763]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L230
[adff]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L27
[0910]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L33
[9f5c]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L39
[ea1e]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L46
[e357]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L52
[8400]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L58
[ef6d]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L68
[3f56]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L74
[6841]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L80
[dcc9]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L86
[00cf]: https://github.com/40ants/ai/blob/20f1742c6a6b31aa4b0a665379ccb21fcfaec135/src/util.lisp#L93
[2c24]: https://github.com/40ants/ai/blob/master/evals/docs/adapter-protocol.md
[9e7b]: https://github.com/40ants/ai/blob/master/evals/docs/decisions/0001-common-lisp-with-promptfoo-js-adapter.md
[0ce0]: https://github.com/40ants/ai/blob/master/evals/docs/decisions/0002-extensible-checks.md
[3116]: https://github.com/40ants/ai/blob/master/evals/docs/decisions/0003-opencode-2.md
[06d2]: https://github.com/40ants/ai/blob/master/evals/docs/extending-checks.md
[e1fe]: https://github.com/40ants/ai/issues
[5fd6]: https://github.com/40ants/linter
[6975]: https://github.com/fukamachi/mallet
[4457]: https://microsoft.github.io/apm/reference/cli/install/
[c15d]: https://quickdocs.org/asdf
[3a1f]: https://quickdocs.org/babel
[49b9]: https://quickdocs.org/cl-ppcre
[8347]: https://quickdocs.org/dexador
[90b9]: https://quickdocs.org/ironclad
[46a1]: https://quickdocs.org/local-time
[c41d]: https://quickdocs.org/serapeum
[aba2]: https://quickdocs.org/yason
[6455]: https://www.promptfoo.dev/docs/providers/openai-codex-sdk/
[62b3]: index.html#x-2840ANTS-AI-EVALS-2FAGENTS-3APROFILE-FOR-20FUNCTION-29
[7ed9]: index.html#x-2840ANTS-AI-EVALS-2FPROVIDERS-2FOPENCODE-3ASTOP-SERVER-20FUNCTION-29

* * *
###### [generated by [40ANTS-DOC](https://40ants.com/doc/)]
