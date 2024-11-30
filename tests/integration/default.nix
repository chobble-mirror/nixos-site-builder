{ pkgs, lib, utils }:

{
  basicSite = pkgs.nixosTest (import ./basic-site.nix { inherit pkgs lib utils; });
  multipleSites = pkgs.nixosTest (import ./multiple-sites.nix { inherit pkgs lib utils; });
  neocities = pkgs.nixosTest (import ./neocities-site.nix { inherit pkgs lib utils; });
  siteCommands = pkgs.nixosTest (import ./site-commands.nix { inherit pkgs lib utils; });
}
