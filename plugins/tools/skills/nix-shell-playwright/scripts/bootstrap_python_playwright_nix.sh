#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <project-dir> [browser-path]" >&2
  exit 1
fi

project_dir="$1"
browser_path="${2:-${PLAYWRIGHT_BROWSER_PATH:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}}"

# Reuse existing project configuration instead of silently replacing it.
for output in shell.nix run_smoke_test.sh; do
  if [[ -e "$project_dir/$output" || -L "$project_dir/$output" ]]; then
    echo "Refusing to overwrite $project_dir/$output; reuse the project environment." >&2
    exit 2
  fi
done

mkdir -p "$project_dir"

cat >"$project_dir/shell.nix" <<EOF
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = [
    pkgs.python313
    pkgs.python313Packages.playwright
  ];

  shellHook = ''
    export PLAYWRIGHT_BROWSER_PATH="${browser_path}"
  '';
}
EOF

cat >"$project_dir/run_smoke_test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

nix-shell --run 'python3 smoke_test.py'
EOF

chmod +x "$project_dir/run_smoke_test.sh"

echo "Wrote $project_dir/shell.nix"
echo "Wrote $project_dir/run_smoke_test.sh"
