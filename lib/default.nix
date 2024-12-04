{ pkgs }:
let
  utils = import ./utils.nix;
in
{
  mkSiteServices = import ./mkSiteServices.nix { inherit pkgs utils; };
  mkSiteTimers = import ./mkSiteTimers.nix { inherit pkgs utils; };
  mkSiteUsers = import ./mkSiteUsers.nix { inherit pkgs utils; };
  mkSiteGroups = import ./mkSiteGroups.nix { inherit pkgs utils; };
  mkSiteTmpfiles = import ./mkSiteTmpfiles.nix { inherit pkgs utils; };
  mkSiteVhosts = import ./mkSiteVhosts.nix { inherit pkgs utils; };
  mkSiteBuilder = import ./mkSiteBuilder.nix { inherit pkgs utils; };
  mkSiteCommands = import ./mkSiteCommands.nix { inherit pkgs utils; };
}
