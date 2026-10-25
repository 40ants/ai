---
name: deploy-40ants-project
description: Use when deploying, updating, or rolling back a 40ants pet-project service (e.g. pingvito) on a VPS host, when asked to "deploy to prod" or run lake to-prod, when setting up a service on a new host, changing service.env / systemd unit / Caddyfile, or troubleshooting a prod service behind Caddy in the /srv/services scheme.
---

# Deploying 40ants Projects

## Overview

Every service deploys into one per-service tree on the host:

```text
/home/art/projects/<name>/         # sources and development; prod never runs from here

/srv/services/<name>/
  releases/<YYYYMMDD-HHMMSS>/      # immutable release: bin/ + public/ + REVISION
  current -> releases/<rev>        # symlink to the active release
  config/service.env               # secrets, root:root, 0600
  config/<name>.service            # systemd unit; symlinked into /etc/systemd/system
  config/Caddyfile                 # site routes; imported by the main Caddyfile
  data/                            # SQLite and other mutable data, <name>:<name>, 0700
```

Deploy = build a self-sufficient binary in the dev checkout (`build.lisp` + Deploy
library), install it as a new timestamped revision, atomically flip `current`,
`systemctl restart`. Rollback = flip `current` back and restart. Nothing else
changes: `config/` and `data/` survive deploys as-is.

This skill is the canonical deployment document for 40ants pet-project services,
used from a project directory on a host (pilot: host `dev3`, service `pingvito`).
It supersedes the earlier `40ants-deployment/deploy.md` draft, which is not
published in any repository.

Key invariants:

- No Docker for services; Docker is only allowed for PostgreSQL.
- Revision name = UTC timestamp: `date -u +%Y%m%d-%H%M%S` (e.g. `20261025-101443`).
  Lexical order = chronological order.
- Keep last N revisions per project (`revisions-to-keep`, default 3); **never**
  delete the revision `current` points to.
- One Unix system user per service; process is sandboxed by systemd
  (`ProtectHome=read-only`, `ProtectSystem=strict`, `PrivateTmp=true`,
  `NoNewPrivileges=true`, write access only to `data/`).
- `ProtectHome=read-only`, not `true`: a full block on `/home` breaks
  interactive debugging of the live image (SLY's M-. cannot `truename`
  dev-checkout sources through SLYNK). Read-only keeps the write
  protection (`ProtectSystem=strict`); secrets like `~/.ssh` stay behind
  normal DAC permissions.

## When to Use

- "Deploy a new revision to prod", "обнови сервис", `lake to-prod`
- Roll back a bad release
- Set up a service on a host for the first time
- Change prod config: `service.env`, unit, Caddyfile
- Prod is down or misbehaves; check status, logs, live REPL

**When NOT to use:** the client-side pingvito skill (sending notifications);
anything involving other people's servers.

**Stale docs warning:** a project-local `.agents/skills/pingvito-deploy/SKILL.md`
may describe the OLD scheme (`/opt/pingvito`, `/var/lib/pingvito`, nginx, host
`dev`). That scheme is decommissioned — follow this skill instead.

## Scenario: routine deploy

`lake to-prod` is being reworked to do all of this; until it lands,
run the steps manually from the project checkout on the host (`ssh dev3`,
`cd ~/projects/<name>`). Never use the old `lake to-prod` behavior (copying the
binary to `roswell/*-prod` inside the dev tree) — prod must not depend on
`/home/art`.

1. **Build** (long: run under `nohup … &` with a log file, or a background tool):

   ```bash
   export PATH=/home/art/.local/bin:/home/art/.roswell/bin:$PATH
   qlot exec ros -L sbcl-bin/<pinned-version> run -- --non-interactive --load build.lisp
   ```

   `build.lisp` (convention) registers local systems, quickloads everything that
   must end up in the image, applies project quirks, and ends with
   `asdf:make :<name>`. The Deploy library produces `bin/<name>` + `bin/*.so` —
   all native libs load relative to the executable, so the release works under
   full sandboxing. `bin/` always travels as a whole directory.

2. **Install the release** (as root; releases are root-owned):

   ```bash
   rev=$(date -u +%Y%m%d-%H%M%S)
   sudo install -d -m 0755 /srv/services/<name>/releases/$rev
   sudo cp -r bin public REVISION /srv/services/<name>/releases/$rev/
   ```

3. **Flip `current` atomically** (never `ln -sfn` — it leaves a window with no
   symlink at all):

   ```bash
   ln -s releases/$rev /srv/services/<name>/current.tmp
   sudo mv -Tf /srv/services/<name>/current.tmp /srv/services/<name>/current
   ```

4. **Unit changed?** `sudo systemctl daemon-reload` (only when `config/<name>.service` was edited).

5. **Restart and verify:**

   ```bash
   sudo systemctl restart <name>
   systemctl is-active <name>                    # active, no restart loop
   systemctl show <name> -p NRestarts
   curl -fsS http://127.0.0.1:<app-port>/        # local app check (pingvito: 8081)
   curl -fsS https://<domain>/                   # through Caddy: site, API, WebSocket
   sudo journalctl -u <name> -n 50 --no-pager    # no errors on startup
   ```

6. **Cleanup:** delete oldest `releases/*` beyond the keep-limit (default 3),
   keeping `current`'s target. Never touch `config/`, `data/`.

## Scenario: rollback

```bash
ls -1 /srv/services/<name>/releases/          # pick the previous revision
readlink /srv/services/<name>/current         # confirm what is active now
# atomic flip to releases/<old-rev> (same mv -Tf pattern), then:
sudo systemctl restart <name>
# re-run the verify step above
```

`config/` and `data/` are not part of rollback; a bad migration may need
restoring `data/` from backup (SQLite: `VACUUM INTO` dumps).

## Scenario: first service on a host

One-time per host: `sudo ufw allow 80,443/tcp`; install Caddy from the official
apt repository (do not start it while nginx still holds 80/443).

Per service (the steps below form the full checklist):

```bash
sudo useradd --system --home /nonexistent --shell /usr/sbin/nologin <name>
sudo install -d -m 0755 /srv/services/<name>/{releases,config}
sudo install -d -o <name> -g <name> -m 0700 /srv/services/<name>/data
# deploy first release (scenario above), then create the env file
# (migrate secrets from their old /etc location; never print contents):
sudo touch /srv/services/<name>/config/service.env
sudo chmod 0600 /srv/services/<name>/config/service.env
sudo $EDITOR /srv/services/<name>/config/service.env
sudo ln -s /srv/services/<name>/config/<name>.service /etc/systemd/system/<name>.service
sudo systemctl daemon-reload && sudo systemctl enable --now <name>
```

Unit template: `User`/`Group` = `<name>`, `WorkingDirectory` and
`ExecStart` go through `/srv/services/<name>/current`, `EnvironmentFile` points
to `config/service.env`, plus the four sandbox directives and
`ReadWritePaths=/srv/services/<name>/data`. `data/` is 0700.

Nginx → Caddy switchover: put `import /srv/services/*/config/Caddyfile` into the
main `/etc/caddy/Caddyfile`, validate, stop nginx, `systemctl enable --now caddy`,
verify cert + redirect + site, then decommission the old nginx site config.

Per-service `config/Caddyfile` (real pingvito example): site block with filtered
access log, `redir` for `/api` → `/api/`, `handle_path /api/*` stripping the
prefix to `reverse_proxy 127.0.0.1:8081`, and `file_server` rooted at
`/srv/services/<name>/current/public`. One subdomain per service; path prefixes
only when a shared origin is required.

## Scenario: config changes

| File | Procedure |
|---|---|
| `config/service.env` | Edit as root (never print contents), `sudo systemctl restart <name>` |
| `config/<name>.service` | Edit, `daemon-reload`, `restart <name>` |
| `config/Caddyfile` | Edit, validate (see below), `sudo systemctl reload caddy` |

Validate Caddy **as the caddy user**, never as root — root validation creates
root-owned log files the worker process then cannot open:

```bash
sudo -u caddy caddy validate --config /etc/caddy/Caddyfile
```

`/var/lib/caddy` is the persistent certificate store: never clean it during
deploys, or you hit Let's Encrypt rate limits.

## Scenario: prod troubleshooting

- Long remote operations: `nohup … &` with a log file, check with
  `kill -0 <pid>`; never wrap waiting in one long SSH call.
- Edit remote files locally (`write` → `scp`), never `sed`/heredoc over SSH.
- Status: `systemctl status <name>`, `systemctl show <name> -p MainPID -p NRestarts`,
  `sudo journalctl -u <name> -f`.
- Live REPL first, journal archaeology second: with `MCP_PORT` set in
  `service.env` the app runs an MCP eval server on localhost; reach it through
  an SSH tunnel and inspect threads/backtraces in the running image.
- Binary "works in dev, dies in prod" → almost always libs reachable only via
  `/home/art`. With `ProtectHome=read-only` such libs now load silently, but
  releases still must be self-sufficient: the dev checkout may move or vanish.
  Check release self-sufficiency:

  ```bash
  cp -r /srv/services/<name>/current /tmp/<name>-check
  sudo -u <name> /tmp/<name>-check/bin/<name> --help
  sudo -u <name> env LD_DEBUG=libs /tmp/<name>-check/bin/<name> --help 2>&1 \
    | grep -oE "/home/[^ ]*\.so" | sort -u   # offending absolute paths
  ```

  Fix by rebuilding with Deploy (`build.lisp`), not by bind-mounting caches.

## Quick Reference

| Task | Command / path |
|---|---|
| New revision name | `date -u +%Y%m%d-%H%M%S` (UTC) |
| Build on host | `qlot exec ros -L sbcl-bin/<pin> run -- --non-interactive --load build.lisp` |
| Flip `current` | `ln -s releases/$rev …/current.tmp && sudo mv -Tf …/current.tmp …/current` |
| Deploy lifecycle | build → install release → flip → restart → verify → cleanup (keep 3, never current) |
| Service ops | `systemctl status/restart <name>`; `journalctl -u <name> -f` |
| Logs | service → journald (stdout/stderr); access → `/var/log/caddy/` |
| Caddy check | `sudo -u caddy caddy validate --config /etc/caddy/Caddyfile` |
| Secrets | `config/service.env`, root:root 0600; never print, never overwrite from repo examples |
| Backups | SQLite: `sqlite3 … "VACUUM INTO '…'"`; PostgreSQL (Docker): `docker exec … pg_dump` |

## Common Mistakes

| Mistake | Correct action |
|---|---|
| `ln -sfn` to switch `current` | Not atomic; use the `current.tmp` + `mv -Tf` pattern |
| Deploying by `git pull` + rebuild in place, or running prod from `/home/art` | Install immutable `releases/<rev>`; prod runs only through `current` |
| Deleting the active revision during cleanup | Never remove the revision `current` points to |
| `caddy validate` as root | Validate as `caddy` user; root creates unopenable log files |
| Wiping `/var/lib/caddy` on deploys | It holds LE certificates; republishing hits rate limits |
| Copying nginx `proxy_set_header`/timeouts into Caddy | Caddy sets `X-Forwarded-*` itself; add timeouts only deliberately |
| Fixing missing libs with bind-mounts of `/home/art` caches | Rebuild via `build.lisp` so Deploy bundles `.so` into `bin/` |
| Editing remote unit/env with `sed` over SSH | Edit locally, `scp`, then `daemon-reload`/`restart` |
| Keeping env vars inside the unit text | Only `EnvironmentFile=config/service.env` |

## Related skills

For evaluating forms in the running prod image once the MCP tunnel is up:
**using-common-lisp-repl**. For project tests before deploying: **testing-with-rove**.
