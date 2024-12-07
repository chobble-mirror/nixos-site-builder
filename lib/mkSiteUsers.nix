{ pkgs, utils }:

sites:
let
  inherit (utils) mkServiceName;

  mkUser = domain: cfg:
    let serviceUser = mkServiceName domain;
    in {
      ${serviceUser} = {
        isSystemUser = true;
        group = serviceUser;
        description = "${domain} website builder service user";
      };
    };
in builtins.foldl' (acc: domain: acc // (mkUser domain sites.${domain})) { }
(builtins.attrNames sites)
