# Additional sample environments use the same nixpkgs as the harness.
{ pkgs }:
let
  python = pkgs.python313.withPackages (ps: [ ps.playwright ]);
  chromium = pkgs.playwright-driver.components.chromium;
  browser = "${chromium}/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing";
  # The shell tool may request login mode. Explicitly disable profiles and rc
  # files, and discard startup-file variables before entering the pinned Bash.
  evalShell = pkgs.writeTextFile {
    name = "skill-eval-shell";
    destination = "/bin/skill-eval-shell";
    executable = true;
    text = ''
      #!${pkgs.bashInteractive}/bin/bash -p
      set -eu
      : "''${SKILL_EVAL_TOOL_PATH:?Missing pinned evaluation tool path}"
      unset BASH_ENV ENV
      export PATH="$SKILL_EVAL_TOOL_PATH"
      . ${./sample-environment.sh}
      export SHELL="''${SKILL_EVAL_SHELL:-$0}"
      case "''${1:-}" in
        -l|--login) shift ;;
        -lc|-cl) shift; set -- -c "$@" ;;
      esac
      # Enter Qlot for the complete command, including every pipeline segment.
      exec qlot exec ${pkgs.bashInteractive}/bin/bash --noprofile --norc "$@"
    '';
  };
  linter = pkgs.writeShellScriptBin "40ants-linter" ''
    exec sbcl --noinform --non-interactive \
      --eval '(uiop:with-muffled-conditions ((quote (warning))) (asdf:load-system "40ants-linter"))' \
      --eval '(let ((args (uiop:command-line-arguments))) (apply (function uiop:symbol-call) :40ants-linter/main :main (if (equal (first args) "--") (rest args) args)))' -- "$@"
  '';
  mallet = pkgs.writeShellScriptBin "mallet" ''
    exec sbcl --noinform --non-interactive \
      --eval '(uiop:with-muffled-conditions ((quote (warning))) (asdf:load-system "mallet"))' \
      --eval '(let* ((args (uiop:command-line-arguments)) (uiop:*command-line-arguments* (if (equal (first args) "--") (rest args) args))) (uiop:symbol-call :mallet :main))' -- "$@"
  '';
in {
  packages = [ python linter mallet evalShell (pkgs.lib.getBin pkgs.nix) ];
  env = {
    SKILL_EVAL_SHELL = "${evalShell}/bin/skill-eval-shell";
    NIX_PATH = "nixpkgs=${pkgs.path}";
    SKILL_EVAL_NIXPKGS_PATH = toString pkgs.path;
    PLAYWRIGHT_BROWSER_PATH = browser;
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH = browser;
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    SKILL_EVAL_PYTHON_VERSION = pkgs.python313.version;
    SKILL_EVAL_SBCL_VERSION = pkgs.sbcl.version;
    SKILL_EVAL_ROSWELL_VERSION = pkgs.roswell.version;
    SKILL_EVAL_PYTHON = "${python}/bin/python3";
    SKILL_EVAL_CHROMIUM_REVISION = "${pkgs.playwright-driver.browsersJSON.chromium.revision}";
    SKILL_EVAL_CHROMIUM_VERSION = "${pkgs.playwright-driver.browsersJSON.chromium.browserVersion}";
    SKILL_EVAL_PLAYWRIGHT_VERSION = pkgs.python313Packages.playwright.version;
    SKILL_EVAL_ENVIRONMENT_NIXPKGS = "885ba4d038f10c3d17d7a92e8c3cc185b99c9158.tar.gz";
  };
}
