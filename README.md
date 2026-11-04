<a id="x-2840ANTS-AI-SKILLS-DOCS-2FINDEX-3A-40README-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

# AI skills and behavioral tests

This repository contains the skills and their behavioral test suites. The reusable
40ants-ai-evals runner is maintained in a separate repository.

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FINDEX-3A-3A-40PACKAGES-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

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

<a id="x-2840ANTS-AI-SKILLS-DOCS-2FINDEX-3A-3A-40EVALUATIONS-2040ANTS-DOC-2FLOCATIVES-3ASECTION-29"></a>

## Evaluate these skills

This project contains twelve suites and 77 cases. Tests, fixtures, file-based
assertions and calibration tests are under evals. The project-specific environments
are in evals/environments, and assertions are in evals/checks.

The runner is a separate local Git checkout named 40ants-ai-evals beside this
repository. Its revision is pinned by evals/engine.lock.json and Nix fetchGit.
Set `AI`_`EVALS`_`SOURCE` to select another local checkout containing the pinned revision.
No repository has been published automatically. Other projects can reuse the library
with their own catalog, fixtures and assertion systems.

Enter nix-shell and use qlot exec ai-evals suites, checks, history, compare or replay.
The compatibility entry point qlot exec ros roswell/ai-evals.ros remains available.
A model run uses run with suite, filter, agent, group and repeat flags. Use view to
open the existing Promptfoo results `UI` on port 15500. History remains in .evals;
no archived snapshots or original model scores are migrated or overwritten.

Run project calibration tests with qlot exec ai-evals test. The separate library's
`ASDF` test system checks its protocols and an independent minimal consuming project.
Lisp libraries use qlfile.lock; Nix preserves the existing tool versions. The library
source revision is recorded independently from the consuming project's Git revision.


[5fd6]: https://github.com/40ants/linter
[6975]: https://github.com/fukamachi/mallet

* * *
###### [generated by [40ANTS-DOC](https://40ants.com/doc/)]
