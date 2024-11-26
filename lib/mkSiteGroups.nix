{ pkgs }:

sites:
let
  mkGroup = domain: cfg:
    let
      sanitizedDomain = builtins.replaceStrings ["."] ["-"] domain;
      serviceUser = "${sanitizedDomain}-builder";
    in {
      ${serviceUser} = {};
    };
in
builtins.foldl' (acc: domain:
  acc // (mkGroup domain sites.${domain})
) {} (builtins.attrNames sites)
