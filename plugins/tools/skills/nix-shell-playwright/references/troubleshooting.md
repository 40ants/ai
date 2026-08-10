# Troubleshooting

## `nix-shell` cannot connect to `/nix/var/nix/daemon-socket/socket`

Cause: the command is running inside a sandboxed environment that cannot talk to the Nix daemon.

Action: rerun `nix-shell` with escalation or outside the sandbox.

## `pkgs.chromium` is unavailable on `aarch64-darwin`

Cause: some `nixpkgs` revisions do not ship Chromium for Apple Silicon macOS.

Action: use a locally installed browser and export `PLAYWRIGHT_BROWSER_PATH`, for example:

```bash
export PLAYWRIGHT_BROWSER_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
```

Or pass the path to `bootstrap_python_playwright_nix.sh`.

## `python3 -m http.server` cannot bind a local port

Cause: sandbox rules can block local binds.

Action: prefer `file://` for static pages. If HTTP is required, rerun the server with escalation.

## Playwright is installed but screenshots are missing

Check:

1. `smoke_test.py` exists in the project root
2. `run_smoke_test.sh` runs `python3 smoke_test.py`
3. The HTML paths passed to `generate_static_smoke_test.py` are correct
4. The browser path in `PLAYWRIGHT_BROWSER_PATH` points to a real executable
