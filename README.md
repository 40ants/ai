# APM Skill Packages

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

macOS / Linux:

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

If you want to validate plugin structure with the OpenAI scaffold validator:

```bash
python3 /Users/art/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py /Users/art/projects/lisp/ai/plugins/common-lisp-skills
python3 /Users/art/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py /Users/art/projects/lisp/ai/plugins/tools
```

Note: this validator requires `PyYAML` in the active Python environment.

## Test Skills with Promptfoo

The first behavioral suite is for `writing-common-lisp`. The skill itself is
unchanged. The suite asks Codex to edit disposable projects through Promptfoo's
native Codex SDK provider, captures its turn and output files, then reads and
runs the Lisp with SBCL and Serapeum.

### 1. Enter the pinned environment

```bash
cd /Users/art/projects/lisp/ai
nix-shell
```

`shell.nix` pins nixpkgs by commit and SHA-256, Promptfoo **0.125.1**, Codex
SDK and CLI **0.156.1**, APM **0.31.0**, Node.js **22.23.4**, and SBCL **2.6.8**
with Serapeum. `nix/promptfoo/package-lock.json` pins the published npm packages
and their complete dependency graph; Nix also checks the downloaded dependency
hash. The native provider requires SDK `^0.156.1`, so its matching CLI replaces
the previous 0.165.0 CLI only inside this shell. The new Promptfoo uses libSQL;
the old better-sqlite3 rebuild workaround is removed. The shell targets Apple
Silicon macOS. Nix downloads dependencies to its store without installing global npm
packages or changing a Homebrew installation/user Nix profile.

The shell uses a PATH made from those Nix packages plus macOS system utilities.
Homebrew/Roswell executables are excluded, and SBCL user initialization is
disabled so a personal Quicklisp setup cannot affect results.

Check the tools yourself:

```bash
promptfoo --version
codex --version
apm --version
sbcl --version
node --version
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

Open `evals/writing-common-lisp/promptfooconfig.yaml`:

- `prompts` selects the user request (`{{task}}`).
- `providers` uses Promptfoo's built-in `openai:codex-sdk` provider.
- `copy_working_dir: copy` gives every call/repeat a fresh workspace, retained
  until assertions finish and then removed by Promptfoo.
- `defaultTest.assert` archives files using `evals/lib/workspace-grade.cjs`,
  then applies the unchanged domain rules in `evals/lib/grade.cjs`.

`cases.json` supplies inputs and expectations. For example, `package-path`
asks for `src/models/score.lisp` in system `demo`. The expected package is
`demo/src/models/score`; SBCL also verifies that `add-score` adds correctly.
Expectations live outside the prompt, so the agent does not see the answer key.

There are **9 development cases** and **2 holdout cases**. Coverage includes
package paths, public exports/docstrings, signatures, LOOP style, exhaustive
dispatch, error reporting, unused parameters, hook contracts, project overrides,
protected `.qlot/` dependencies, and a negative Python routing case.

The runner prepares fixture templates with a Git root and a snapshot of the
tested skill. Promptfoo creates a fresh copy for each sample. The runner uses
a temporary Codex home with no personal configuration, and disables user and
admin skills for this process. It reuses existing Codex file-based login
state; no API key or paid model grader is needed. Each run still consumes the
model allowance of that login. If file-based authentication is unavailable,
authenticate the pinned Codex CLI with `codex login` first.

### 3. Calibrate the grader before trusting it

```bash
node --test evals/lib/*.test.cjs
promptfoo validate config -c evals/writing-common-lisp/promptfooconfig.yaml
```

The calibration suite checks known-good code and intentional defects, including
wrong arithmetic despite correct style. Passing calibration is evidence about
the grader, not evidence that the skill passed a real model evaluation.

### 4. Run one case, then establish a baseline

```bash
node evals/run.mjs run --label smoke --filter package-path
node evals/run.mjs run --label baseline
```

The second command runs all development cases. Exit code zero requires every
expected sample to be present and passing, with no infrastructure errors. A
failed requirement is a useful result: inspect the artifact before changing
either the skill or its test. Do not weaken an assertion just to turn it green.

Routing evidence comes from Promptfoo's native `metadata.skillCalls`. It is
still a heuristic based on direct `SKILL.md` reads, not a first-class SDK skill
invocation event. Our previous command-matching heuristic and custom provider
have been removed. For a suspicious routing failure, inspect `turn.json`.

### 5. Read the accumulated history

```bash
node evals/run.mjs history
node evals/run.mjs view
```

The viewer serves the project's persistent Promptfoo database at
`http://127.0.0.1:15500`. Its run list retains earlier evaluations. Use Ctrl-C to
stop the viewer. No Promptfoo Cloud account or result sharing is configured.

Every run also gets a unique directory under `.evals/runs/` containing:

```text
manifest.json          Git revision/status, tool versions, model/effort,
                       case list, repeat count, skill hash and suite hash
skill/                 Exact skill directory used by that run
harness/               Snapshot of eval code, tests, shell.nix and npm lockfile
results.json           Full Promptfoo export
summary.json           Per-case results, failures/errors, efficiency statistics
fixtures/              Immutable starting project templates for native copies
samples/<sample-id>/   Actual prompt, turn.json, sample.json, generated files
```

Both passing and failing runs remain in history. Authentication files stay in
temporary runtime directories and are not copied into these artifacts. The
working copy is removed by Promptfoo after each sample; the authentication
directory is removed after the run. Generated files and turns remain archived.
Old runs keep their original JSONL artifacts and remain readable in history.

Before the 0.125.1 migration, a consistent SQLite backup was saved under
`.evals/backups/before-promptfoo-0.125.1-*/promptfoo.db`. Existing database rows
and run folders are preserved. Re-enter `nix-shell` after pulling this upgrade;
an already-open shell still has the previous tools on its PATH. Establish a
new baseline with the upgraded harness before assessing further skill edits.

`.evals/` is ignored by Git. Back up **the whole directory**, including the
Promptfoo database, if you need history to survive deletion of this checkout or
a disk failure. Local accumulation is not an off-machine backup.

### 6. Compare a change with any earlier version

```bash
# After making one intentional change to SKILL.md:
node evals/run.mjs run --label candidate
node evals/run.mjs compare baseline candidate

# Or use exact IDs printed by history:
node evals/run.mjs compare previous latest
```

Use unique labels or exact run IDs. Comparison checks that the test suite,
selected cases, repetitions, model, effort and tool versions match. It refuses
to treat incompatible runs as a direct regression comparison. For an intentional
exploration, `--allow-mismatch` prints the differences explicitly.

You can evaluate an old skill from **any Git commit** with today's test suite:

```bash
node evals/run.mjs run --label historical --ref HEAD
```

Replace `HEAD` with a real commit hash or tag from `git log`. The runner extracts
only that commit's skill directory; it never checks out a different branch or
changes the current skill. To evaluate a separate experimental copy, use
`--skill-dir /absolute/path/to/writing-common-lisp` instead of `--ref`.

Model names such as `gpt-6-sol` are server-managed aliases, so pinned client
tools do not freeze the model weights. Keep model/effort constant when measuring
a skill change; use an exact model snapshot if the provider makes one available.

### 7. Separate consistency, value and generalization

```bash
# Estimate variability: 9 cases × 3 independent samples.
node evals/run.mjs run --label baseline-repeat --repeat 3

# Matched control: with and without the skill, on fresh workspaces.
node evals/run.mjs run --label ablation --ablation

# Evaluate the held-out scenarios after selecting an instruction change.
node evals/run.mjs run --label holdout-check --group holdout --repeat 3

# Or run both development and holdout cases together.
node evals/run.mjs run --label full --group all
```

In ablation mode, the control receives the same task without an explicit
`Use $writing-common-lisp` request, and the tested skill is absent. Other checks
remain the same, except skill-read evidence does not apply to that control.
This shows whether the instructions add value beyond the model's existing
Common Lisp knowledge. It is a paired observational comparison, not a claim of
statistical significance from a single sample.

The report retains passes, assertion failures, infrastructure errors, median
tokens, command count and elapsed time separately. ChatGPT-login usage has no
reliable per-call USD price here; `costUsd: null` means unknown, not zero.
The native provider may display an estimated API cost in Promptfoo's UI. That
estimate is not a charge or a measurement of ChatGPT subscription billing.

### 8. Add a regression case before editing instructions

1. Reproduce a real failure as one entry in `cases.json`.
2. Write the expected behavior independently of the agent's current output.
3. Add an objective assertion/functional check and calibrate it with a passing
   and failing example in `grade.test.cjs`.
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
