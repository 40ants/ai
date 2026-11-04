---
name: nix-shell-playwright
description: Create and use a Python Playwright environment via nix-shell for local web testing. Use when Playwright is missing, when a project needs reproducible browser smoke tests, or when static HTML/pages should be checked through a generated smoke_test.py and nix-shell helper scripts.
---

# Nix Shell Playwright

Use this skill to make Python Playwright reproducible in a project with `nix-shell`, especially for local smoke tests.

## Workflow

1. Decide whether the target is static or server-backed.
2. Inspect the project environment first. Keep an existing `shell.nix` and its
   pinned versions. Use `scripts/bootstrap_python_playwright_nix.sh <project-dir>
   [browser-path]` only when its output files are absent: the helper overwrites
   them. If `PLAYWRIGHT_BROWSER_PATH` is supplied, pass that exact path as the
   second argument rather than replacing it with a machine-specific default.
3. For static pages, run `scripts/generate_static_smoke_test.py --output <project-dir>/smoke_test.py --paths index.html ...`.
4. Run `./run_smoke_test.sh` through the project runner. Use a prepared browser
   MCP runner when the environment provides one, preserving its real exit status
   and output.
5. Review `test-shots/` using an image-reading tool when available. If this
   model/session cannot view images, report that limitation and verify navigation,
   page assertions, generated files and viewport dimensions through Playwright.
   Do not claim visual inspection from a homemade PNG decoder or pixel-color
   heuristic, and do not retry a disconnected desktop browser.

## Static Pages

Prefer `file://` navigation for static pages. It avoids local server setup and avoids sandbox issues around binding a port.

Generate the smoke test with:

```bash
python3 .agents/skills/nix-shell-playwright/scripts/generate_static_smoke_test.py \
  --output ./smoke_test.py \
  --paths index.html about.html contacts.html
```

The generated test captures desktop and mobile screenshots into `test-shots/`.

## Server-Backed Apps

If the app needs HTTP, keep `shell.nix` from this skill and write a Playwright script that targets the local URL. If a local server must bind to a port, be ready to request escalation outside the sandbox.

## macOS / Nix Notes

On `aarch64-darwin`, do not assume `pkgs.chromium` is available in `nixpkgs`. Prefer a locally installed browser and point `PLAYWRIGHT_BROWSER_PATH` at it.

Use the default macOS fallback in this order when reasonable:

1. `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`
2. `/Applications/Chromium.app/Contents/MacOS/Chromium`
3. Another browser path supplied explicitly to the bootstrap script

If `nix-shell` fails on the daemon socket in the sandbox, rerun with escalation. See `references/troubleshooting.md`.

## Resources

### scripts/

- `bootstrap_python_playwright_nix.sh`: Write `shell.nix` and `run_smoke_test.sh`
- `generate_static_smoke_test.py`: Generate a static `smoke_test.py` with desktop/mobile screenshots

### references/

- `troubleshooting.md`: Common failures from real usage in this session
