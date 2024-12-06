{ pkgs }:
let
  utils = import ./utils.nix;
  files = builtins.attrNames (builtins.readDir ./.);
  mkFiles = builtins.filter (f: builtins.match "mk.*\.nix" f != null) files;
  importModule = file: import (./. + "/${file}") { inherit pkgs utils; };
in
builtins.listToAttrs (map
  (file: {
    name = builtins.substring 0 (builtins.stringLength file - 4) file;
    value = importModule file;
  })
  mkFiles)
