let
  pkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/885ba4d038f10c3d17d7a92e8c3cc185b99c9158.tar.gz";
    sha256 = "0zr2ig7bf6y7lngd06smfgpx0033yza3l9rp0i718pb0gmks5z3v";
  }) {};

  # Node 24.19+ can abort in the older better-sqlite3 bundled by this
  # Promptfoo release. Compile native addons against the pinned Node 22 LTS.
  promptfoo = pkgs.promptfoo.override {
    buildNpmPackage = args: pkgs.buildNpmPackage (finalAttrs:
      (if builtins.isFunction args then args finalAttrs else args)
      // { nodejs = pkgs.nodejs_22; });
  };

  # The upstream binaries preserve the versions used by these evals. Nothing is
  # installed into Homebrew, ~/.local/bin or a user Nix profile.
  codex = pkgs.stdenvNoCC.mkDerivation {
    pname = "codex-cli";
    version = "0.165.0";
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-0.165.0-darwin-arm64.tgz";
      sha256 = "15qgba59146jd3n86i048xwbis5gfkfma6r2s3j2lvbbrfmv14d9";
    };
    sourceRoot = "package";
    installPhase = ''
      mkdir -p "$out/bin" "$out/libexec"
      cp -R vendor "$out/libexec/"
      ln -s "$out/libexec/vendor/aarch64-apple-darwin/bin/codex" "$out/bin/codex"
    '';
    dontFixup = true;
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
  evalTools = [ promptfoo pkgs.nodejs_22 sbcl pkgs.git pkgs.ripgrep apm codex
    pkgs.bashInteractive pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused
    pkgs.gnutar pkgs.which ];
in
assert pkgs.stdenv.hostPlatform.system == "aarch64-darwin";
pkgs.mkShell {
  packages = evalTools;
  SKILL_EVAL_TOOL_PATH = "${pkgs.lib.makeBinPath evalTools}:/usr/bin:/bin:/usr/sbin:/sbin";
  PROMPTFOO_DISABLE_TELEMETRY = "1";
  PROMPTFOO_DISABLE_UPDATE = "1";
  shellHook = ''
    export SHELL="${pkgs.bashInteractive}/bin/bash"
    export PATH="$SKILL_EVAL_TOOL_PATH"
    export PROMPTFOO_CONFIG_DIR="$PWD/.evals/promptfoo"
    export APM_CACHE_DIR="$PWD/.evals/apm-cache"
    echo "Eval tools: promptfoo 0.118.14, Codex 0.165.0, APM 0.31.0 (pinned Nix store)"
  '';
}
