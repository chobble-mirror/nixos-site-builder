{ pkgs, lib }:

let
  runTest = name: test: test { inherit pkgs lib; };
in {
  mkSiteGroups = runTest "mkSiteGroups" (import ./mk-site-groups.nix);
  mkSiteServices = runTest "mkSiteServices" (import ./mk-site-services.nix);
  mkSiteVhosts = runTest "mkSiteVhosts" (import ./mk-site-vhosts.nix);
  # Add more unit tests here
}
