{ pkgs, lib, utils }:
let
  lib = pkgs.lib;
  importTests = path: args: import path ({ inherit pkgs lib utils; } // args);
in importTests ./unit { } // importTests ./integration { }
