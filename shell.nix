# Fetch only the committed evaluator revision; uncommitted sibling edits are ignored.
let
  lock = builtins.fromJSON (builtins.readFile ./evals/engine.lock.json);
  override = builtins.getEnv "AI_EVALS_SOURCE";
  source = if override != "" then override else toString ./. + "/" + lock.source;
  engine = builtins.fetchGit { url = source; rev = lock.revision; };
in import (engine + "/shell.nix") {
  projectRoot = toString ./.;
  engineRevision = lock.revision;
}
