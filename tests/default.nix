{ pkgs }:
let
  lib = pkgs.lib;
in
# Merge unit and integration tests
(import ./unit { inherit pkgs lib; }) //
(import ./integration { inherit pkgs lib; })
