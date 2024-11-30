{ pkgs, lib }:

{
  basicSite = pkgs.nixosTest (import ./basic-site.nix { inherit pkgs lib; });
  multipleSites = pkgs.nixosTest (import ./multiple-sites.nix { inherit pkgs lib; });
  neocitiesTest = pkgs.nixosTest (import ./neocities-site.nix { inherit pkgs lib; });
}
