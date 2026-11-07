{ pkgs ? import <nixpkgs> {} }:
# EVAL_KEEP_CUSTOM_SETTING=present
pkgs.mkShell { packages = [ pkgs.python311 pkgs.python311Packages.playwright ]; }
