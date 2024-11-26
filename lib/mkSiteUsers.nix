{ pkgs }:

sites:
let
  mkUser = domain: cfg:
    let
      sanitizedDomain = builtins.replaceStrings ["."] ["-"] domain;
      serviceUser = "${sanitizedDomain}-builder";
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
