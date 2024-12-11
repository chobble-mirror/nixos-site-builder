{
  pkgs,
  utils,
  customCaddy,
}:
let
  lib = pkgs.lib;
  importTests =
    path:
    import path {
      inherit
        pkgs
        lib
        utils
        customCaddy
        ;
    };
in
importTests ./unit // importTests ./integration
