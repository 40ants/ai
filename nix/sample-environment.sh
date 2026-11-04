# Literal per-sample overrides; business policy is computed by Common Lisp.
# Sourced after every pinned PATH reset, including nested qlot invocations.
eval_env_directory="$PWD"
while :; do
  eval_env_file="$eval_env_directory/.eval-shell-env"
  if [ -e "$eval_env_file" ] || [ -L "$eval_env_file" ]; then
    if [ -L "$eval_env_file" ] || [ ! -f "$eval_env_file" ]; then
      echo 'Invalid sample environment file' >&2
      exit 2
    fi
    while IFS= read -r -d '' eval_env_binding; do
      case "$eval_env_binding" in
        PATH=*|SKILL_EVAL_TOOL_PATH=*|PLAYWRIGHT_BROWSER_PATH=*|PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=*)
          export "$eval_env_binding" ;;
        *) echo 'Unexpected sample environment binding' >&2; exit 2 ;;
      esac
    done < "$eval_env_file"
    break
  fi
  [ ! -e "$eval_env_directory/.git" ] || break
  [ "$eval_env_directory" != / ] || break
  eval_env_directory="${eval_env_directory%/*}"
  [ -n "$eval_env_directory" ] || eval_env_directory=/
done
unset eval_env_directory eval_env_file eval_env_binding
