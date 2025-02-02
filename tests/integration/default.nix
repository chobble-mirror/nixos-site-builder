{
  pkgs,
  lib,
  utils,
}:

let
  tests = {
    basic = ./basic-site.nix;
    # jekyll = ./jekyll-site.nix;
    neocities = ./neocities-site.nix;
    multiple = ./multiple-sites.nix;
    commands = ./site-commands.nix;
  };
in
builtins.mapAttrs (
  name: path:
  pkgs.nixosTest (
    import path {
      inherit
        pkgs
        lib
        utils
        ;
    }
  )
) tests
