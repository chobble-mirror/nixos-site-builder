{ pkgs, utils }:
let
  lib = pkgs.lib;
  importTests = path: import path { inherit pkgs lib utils; };
in
importTests ./unit //
importTests ./integration
