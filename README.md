# Common Lisp Skills

`common-lisp-skills` is a reusable skill bundle for practical Common Lisp development.

The recommended installation method is APM (Agent Package Manager), because APM can install these skills directly from GitHub into multiple agent runtimes, including Codex and OpenCode.

It includes skills for:

- writing Common Lisp code
- working with the REPL
- testing with Rove
- handling JSON
- logging with `log4cl`
- defining CLOS classes
- writing 40ants-doc documentation
- avoiding common Lisp pitfalls
- clearing stale ASDF fasl cache

## Repository Layout

The APM-installable plugin bundle is located in:

- `plugins/common-lisp-skills/`

The repo-local Codex marketplace entry is located in:

- `.agents/plugins/marketplace.json`

## Install from GitHub with APM

APM is the recommended way to consume this package from another project.

1. Install APM.

macOS / Linux:

```bash
curl -sSL https://aka.ms/apm-unix | sh
```

Windows (PowerShell):

```bash
irm https://aka.ms/apm-windows | iex
```

2. From the root of your own project, install this package from GitHub for your target agent.

### Example: install all Common Lisp skills for Codex

```bash
apm install 40ants/ai/plugins/common-lisp-skills --target codex
```

### Example: install all Common Lisp skills for OpenCode

```bash
apm install 40ants/ai/plugins/common-lisp-skills --target opencode
```

### Example: install for both Codex and OpenCode

```bash
apm install 40ants/ai/plugins/common-lisp-skills --target codex,opencode
```

### Example: install only the Common Lisp writing skill

If you are in another project and only want the writing skill:

```bash
apm install 40ants/ai/plugins/common-lisp-skills --target codex --skill writing-common-lisp
```

Later, if you want the full bundle again:

```bash
apm install 40ants/ai/plugins/common-lisp-skills --target codex --skill '*'
```

APM installs into the target runtime's native directories. According to the current APM docs, `codex` deploys to `.codex/` plus `.agents/` for skills, and `opencode` deploys to `.opencode/`.

After installation, start a new agent session or thread so the new skills are available for invocation.

### Persist it in your project's `apm.yml`

Instead of running the full command each time, you can declare the package in your project's `apm.yml`:

```yaml
name: my-project
version: 0.1.0

dependencies:
  apm:
    - 40ants/ai/plugins/common-lisp-skills
```

Then run:

```bash
apm install --target codex
```

## Local Development and Codex Marketplace Option

If you are developing this repository locally, it also includes a Codex marketplace entry for local testing.

Register the repository as a local marketplace:

```bash
codex plugin marketplace add /Users/art/projects/lisp/ai
```

Then install the plugin:

```bash
codex plugin add common-lisp-skills@40Ants
```

## Updating in Another Project

If your project depends on this package through APM, rerun install in your own project:

```bash
apm install --target codex
```

Or, if you installed it directly as a package reference:

```bash
apm install 40ants/ai/plugins/common-lisp-skills --target opencode
```

If your agent does not pick up updated skills in the current session, start a new thread or session.

## Development Notes

- Plugin manifest: `plugins/common-lisp-skills/.codex-plugin/plugin.json`
- Skills directory: `plugins/common-lisp-skills/skills/`
- Marketplace manifest: `.agents/plugins/marketplace.json`

## Local Validation

If you want to validate the plugin structure with the OpenAI scaffold validator:

```bash
python3 /Users/art/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py /Users/art/projects/lisp/ai/plugins/common-lisp-skills
```

Note: this validator requires `PyYAML` in the active Python environment.
