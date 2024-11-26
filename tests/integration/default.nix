{ pkgs, lib }:

{
  basicSite = pkgs.nixosTest (import ./basic-site.nix { inherit pkgs lib; });
  # Add more integration tests here
}
