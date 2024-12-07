{ pkgs, lib, utils }:

let
  tests = {
    siteCommands = ./mk-site-commands.nix;
    siteGroups = ./mk-site-groups.nix;
    siteServices = ./mk-site-services.nix;
    siteVhosts = ./mk-site-vhosts.nix;
  };
in builtins.mapAttrs (name: path: import path { inherit pkgs lib utils; }) tests
