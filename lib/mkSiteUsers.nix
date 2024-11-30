{ pkgs, utils }:

sites:
let
  inherit (utils) shortHash;

  mkUser = domain: cfg:
    let
      serviceUser = "site-${shortHash domain}-builder";
    in {
      ${serviceUser} = {
        isSystemUser = true;
        group = serviceUser;
        description = "${domain} website builder service user";
      };
    };
in
builtins.foldl' (acc: domain:
  acc // (mkUser domain sites.${domain})
) {} (builtins.attrNames sites)
