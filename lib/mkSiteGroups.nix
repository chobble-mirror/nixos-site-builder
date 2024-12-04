{ pkgs, utils }:

sites:
let
  inherit (utils) mkServiceName;

  mkGroup = domain: cfg:
    let
      serviceUser = mkServiceName domain;
    in {
      ${serviceUser} = {};
    };
in
builtins.foldl' (acc: domain:
  acc // (mkGroup domain sites.${domain})
) {} (builtins.attrNames sites)
