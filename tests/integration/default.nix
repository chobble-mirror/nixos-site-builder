{ pkgs, lib }:

{
  basicSite = pkgs.nixosTest (import ./basic-site.nix { inherit pkgs lib; });
  multipleSites = pkgs.nixosTest (import ./multiple-sites.nix { inherit pkgs lib; });
  neocities = pkgs.nixosTest (import ./neocities-site.nix { inherit pkgs lib; });
  siteCommands = pkgs.nixosTest (import ./site-commands.nix { inherit pkgs lib; });
}
