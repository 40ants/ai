let
  pkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/885ba4d038f10c3d17d7a92e8c3cc185b99c9158.tar.gz";
    sha256 = "0zr2ig7bf6y7lngd06smfgpx0033yza3l9rp0i718pb0gmks5z3v";
  }) {};

  # Published, already-built packages. The lockfile pins every transitive
  # dependency; npmDepsHash verifies downloads. SDK and CLI must match the
  # compatibility range enforced by Promptfoo's native Codex provider.
  toolchain = pkgs.buildNpmPackage {
    pname = "skill-eval-toolchain";
    version = "0.125.1";
    src = ./nix/promptfoo;
    nodejs = pkgs.nodejs_22;
    npmDepsHash = "sha256-lMDKBNYTDx7nmH1Nar+EOCfv1O5ZWp5ze1hS/XsXAJk=";
    dontNpmBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin" "$out/lib/skill-eval-toolchain"
      cp -R node_modules "$out/lib/skill-eval-toolchain/"
      ln -s "$out/lib/skill-eval-toolchain/node_modules/.bin/promptfoo" "$out/bin/promptfoo"
      ln -s "$out/lib/skill-eval-toolchain/node_modules/.bin/codex" "$out/bin/codex"
      runHook postInstall
    '';
  };

  apm = pkgs.stdenvNoCC.mkDerivation {
    pname = "apm";
    version = "0.31.0";
    src = pkgs.fetchurl {
      url = "https://github.com/microsoft/apm/releases/download/v0.31.0/apm-darwin-arm64.tar.gz";
      sha256 = "109yl79icgqns3sjipri8hjr2i9dgnpl6krqzljxjg2v6nkmp61v";
    };
    sourceRoot = "apm-darwin-arm64";
    installPhase = ''
      mkdir -p "$out/bin" "$out/libexec/apm"
      cp -R . "$out/libexec/apm/"
      ln -s "$out/libexec/apm/apm" "$out/bin/apm"
    '';
    dontFixup = true;
  };

  # Qlot itself is bootstrapped from the same pinned nixpkgs. Application
  # libraries are resolved exclusively from the project's qlfile.lock.
  qlotRuntime = pkgs.sbcl.withPackages (ps: [ (ps.qlot.overrideAttrs (old: {
    systems = [ "qlot" "qlot/cli" ];
    # The generic Lisp builder removes bundled .asd files. Qlot needs this
    # one to bootstrap project-local Quicklisp, so restore it after install.
    postInstall = (old.postInstall or "") + ''
      cp ${pkgs.sbclPackages.qlot.src}/quicklisp-client/quicklisp/quicklisp.asd \
        "$out/quicklisp-client/quicklisp/quicklisp.asd"
    '';
    preBuild = (old.preBuild or "") + ''
      export XDG_CACHE_HOME="$TMPDIR/qlot-cache"
      export XDG_CONFIG_HOME="$TMPDIR/qlot-config"
      mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
    '';
  })) ]);
  qlot = pkgs.writeShellScriptBin "qlot" ''
    # Native providers copy fixtures without a dependency tree. Reuse only the
    # declared project distribution while preserving the candidate's cwd.
    if [ "''${1:-}" = exec ] && [ ! -f .qlot/setup.lisp ] && [ -n "''${SKILL_EVAL_DEPENDENCY_ROOT:-}" ]; then
      shift
      export QUICKLISP_HOME="$SKILL_EVAL_DEPENDENCY_ROOT/.qlot/"
      export ROSWELL_HOME="''${ROSWELL_HOME:-$SKILL_EVAL_DEPENDENCY_ROOT/.evals/roswell}"
      unset CL_SOURCE_REGISTRY ASDF_OUTPUT_TRANSLATIONS
      case "''${1##*/}" in
        ros)
          shift
          exec ros "$@"
          ;;
      esac
      exec "$@"
    fi
    # Qlot's native exec checks the project, then prepends .qlot/bin. Restore
    # pinned dispatch for the child, including nested exec inside sh/pipelines.
    # Our SBCL/Roswell wrappers already load the project Quicklisp explicitly.
    if [ "''${1:-}" = exec ] && [ "$#" -gt 1 ] && [ -n "''${SKILL_EVAL_TOOL_PATH:-}" ]; then
      case "$2" in
        --*) ;;
        *) shift; set -- exec ${pkgs.coreutils}/bin/env "PATH=$SKILL_EVAL_TOOL_PATH" "$@" ;;
      esac
    fi
    exec ${qlotRuntime}/bin/sbcl --noinform --no-userinit --no-sysinit \
      --non-interactive --eval '(require :asdf)' \
      --eval '(asdf:initialize-output-translations `(:output-translations (t (,(uiop:ensure-directory-pathname (uiop:getenv "XDG_CACHE_HOME")) :implementation)) :ignore-inherited-configuration))' \
      --eval '(asdf:initialize-source-registry `(:source-registry (:directory ,(merge-pathnames ".qlot/quicklisp/" (uiop:getcwd))) :inherit-configuration))' \
      --eval '(let ((*standard-output* *error-output*)) (asdf:load-system "qlot/cli"))' \
      --eval '(qlot/cli:main)' -- "$@"
  '';
  # Native qlot exec prepends .qlot/bin. Keep recursive invocations on the
  # pinned tool wrappers, including ASDF tests started without our main CLI.
  ros = pkgs.writeShellScriptBin "ros" ''
    if [ -n "''${SKILL_EVAL_TOOL_PATH:-}" ]; then
      export PATH="$SKILL_EVAL_TOOL_PATH"
    fi
    case "''${1:-}" in
      --version|--help) exec ${pkgs.roswell}/bin/ros "$@" ;;
    esac
    exec ${pkgs.roswell}/bin/ros -Q -l ${./nix/lisp-init.lisp} "$@"
  '';
  sbcl = pkgs.writeShellScriptBin "sbcl" ''
    if [ -n "''${SKILL_EVAL_TOOL_PATH:-}" ]; then
      export PATH="$SKILL_EVAL_TOOL_PATH"
    fi
    case "''${1:-}" in
      --version|--help) exec ${pkgs.sbcl}/bin/sbcl "$@" ;;
      --noinform) shift ;;
    esac
    exec ${pkgs.sbcl}/bin/sbcl --noinform --no-userinit --no-sysinit --load ${./nix/lisp-init.lisp} "$@"
  '';
  environments = import ./nix/eval-environments.nix { inherit pkgs; };
  evalTools = environments.packages ++ [ toolchain pkgs.nodejs_22 sbcl ros qlot pkgs.curl pkgs.openssl pkgs.git pkgs.ripgrep apm
    pkgs.bashInteractive pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused
    pkgs.gnutar pkgs.which pkgs.opencode ];
in
assert pkgs.opencode.version == "2.2.1";
assert pkgs.stdenv.hostPlatform.system == "aarch64-darwin";
pkgs.mkShell (environments.env // {
  packages = evalTools;
  SKILL_EVAL_TOOLCHAIN_DIR = "${toolchain}/lib/skill-eval-toolchain/node_modules";
  SKILL_EVAL_TOOL_PATH = "${pkgs.lib.makeBinPath evalTools}:/usr/bin:/bin:/usr/sbin:/sbin";
  PROMPTFOO_DISABLE_TELEMETRY = "1";
  PROMPTFOO_DISABLE_UPDATE = "1";
  shellHook = ''
    export SHELL="$SKILL_EVAL_SHELL"
    export PATH="$SKILL_EVAL_TOOL_PATH"
    export PROMPTFOO_CONFIG_DIR="$PWD/.evals/promptfoo"
    unset CL_SOURCE_REGISTRY ASDF_OUTPUT_TRANSLATIONS QUICKLISP_HOME
    export XDG_CONFIG_HOME="$PWD/.evals/config"
    export XDG_DATA_HOME="$PWD/.evals/data"
    export ROSWELL_HOME="$PWD/.evals/roswell"
    export XDG_CACHE_HOME="$PWD/.evals/cache"
    export QLOT_CACHE_DIRECTORY="$PWD/.evals/qlot-cache"
    export SKILL_EVAL_PROJECT_ROOT="$PWD"
    export SKILL_EVAL_DEPENDENCY_ROOT="$PWD"
    export APM_CACHE_DIR="$PWD/.evals/apm-cache"
    echo "Eval tools: promptfoo 0.125.1, Codex SDK/CLI 0.156.1, OpenCode 2.2.1, APM 0.31.0, Roswell ${pkgs.roswell.version}, Qlot ${pkgs.sbclPackages.qlot.version} (pinned Nix store)"
  '';
})
