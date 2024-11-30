{ pkgs, utils }:
let
  lib = pkgs.lib;
in
# Merge unit and integration tests
(import ./unit { inherit pkgs lib utils; }) //
(import ./integration { inherit pkgs lib utils; })
