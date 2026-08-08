# Common Lisp Skills

`common-lisp-skills` is a Codex/APM-compatible plugin that packages a set of reusable skills for practical Common Lisp development.

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

The plugin payload is located in:

- `plugins/common-lisp-skills/`

The repo-local marketplace entry is located in:

- `.agents/plugins/marketplace.json`

## Installation

Install the repository as a local marketplace:

```bash
codex plugin marketplace add /Users/art/projects/lisp/ai
```

Then install the plugin from that marketplace:

```bash
codex plugin add common-lisp-skills@40Ants
```

## Updating

After pulling changes or editing the plugin locally, reinstall it:

```bash
codex plugin add common-lisp-skills@40Ants
```

If Codex does not pick up updated skills in the current conversation, start a new thread.

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
