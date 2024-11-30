{ pkgs }:

{
  mkSiteServices = import ./mkSiteServices.nix { inherit pkgs; };
  mkSiteTimers = import ./mkSiteTimers.nix { inherit pkgs; };
  mkSiteUsers = import ./mkSiteUsers.nix { inherit pkgs; };
  mkSiteGroups = import ./mkSiteGroups.nix { inherit pkgs; };
  mkSiteTmpfiles = import ./mkSiteTmpfiles.nix { inherit pkgs; };
  mkSiteVhosts = import ./mkSiteVhosts.nix { inherit pkgs; };
  mkSiteBuilder = import ./mkSiteBuilder.nix { inherit pkgs; };
  mkSiteCommands = import ./mkSiteCommands.nix { inherit pkgs; };
}
