{ pkgs }:

sites:
let
  shortHash = domain:
    builtins.substring 0 8 (builtins.hashString "sha256" domain);

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
