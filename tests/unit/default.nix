{ pkgs, lib }:

let
  runTest = name: test: pkgs.callPackage test { inherit lib; };
in {
  mkSiteGroups = runTest "mkSiteGroups" (import ./mk-site-groups.nix);
  mkSiteServices = runTest "mkSiteServices" (import ./mk-site-services.nix);
  mkSiteVhosts = runTest "mkSiteVhosts" (import ./mk-site-vhosts.nix);
  mkSiteCommands = runTest "mkSiteCommands" (import ./mk-site-commands.nix);
}
