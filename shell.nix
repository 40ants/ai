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

  lispRuntime = pkgs.sbcl.withPackages (ps: [ ps.serapeum ]);
  sbcl = pkgs.writeShellScriptBin "sbcl" ''
    case "''${1:-}" in
      --version|--help) exec ${lispRuntime}/bin/sbcl "$@" ;;
    esac
    exec ${lispRuntime}/bin/sbcl --no-userinit --no-sysinit "$@"
  '';
  evalTools = [ toolchain pkgs.nodejs_22 sbcl pkgs.git pkgs.ripgrep apm
    pkgs.bashInteractive pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused
    pkgs.gnutar pkgs.which ];
in
assert pkgs.stdenv.hostPlatform.system == "aarch64-darwin";
pkgs.mkShell {
  packages = evalTools;
  SKILL_EVAL_TOOLCHAIN_DIR = "${toolchain}/lib/skill-eval-toolchain/node_modules";
  SKILL_EVAL_TOOL_PATH = "${pkgs.lib.makeBinPath evalTools}:/usr/bin:/bin:/usr/sbin:/sbin";
  PROMPTFOO_DISABLE_TELEMETRY = "1";
  PROMPTFOO_DISABLE_UPDATE = "1";
  shellHook = ''
    export SHELL="${pkgs.bashInteractive}/bin/bash"
    export PATH="$SKILL_EVAL_TOOL_PATH"
    export PROMPTFOO_CONFIG_DIR="$PWD/.evals/promptfoo"
    export APM_CACHE_DIR="$PWD/.evals/apm-cache"
    echo "Eval tools: promptfoo 0.125.1, Codex SDK/CLI 0.156.1, APM 0.31.0 (pinned Nix store)"
  '';
}
