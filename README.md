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
- linting Common Lisp projects with Mallet and 40ants-linter

### `tools`

Includes skills for:

- bootstrapping a reproducible Playwright environment with `nix-shell`
- generating static smoke tests for local HTML pages
- running local browser-based smoke tests with screenshot capture

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
