#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$script_dir/common-lisp/skills"
target_dir="$PWD/.agents/skills"

if [[ ! -d "$source_dir" ]]; then
  echo "Source directory not found: $source_dir" >&2
  exit 1
fi

mkdir -p "$target_dir"

for skill_path in "$source_dir"/*; do
  skill_name="$(basename "$skill_path")"
  destination="$target_dir/$skill_name"

  rm -rf "$destination"
  cp -R "$skill_path" "$destination"
done

echo "Installed skills to $target_dir"
