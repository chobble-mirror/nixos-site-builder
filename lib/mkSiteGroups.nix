{ pkgs, utils }:

sites:
let
  inherit (utils) shortHash;

  mkGroup = domain: cfg:
    let
      sanitizedDomain = builtins.replaceStrings ["."] ["-"] domain;
      # Use format: "site-{hash}-builder" (max 23 chars)
      serviceUser = "site-${shortHash domain}-builder";
    in {
      ${serviceUser} = {};
    };
in
builtins.foldl' (acc: domain:
  acc // (mkGroup domain sites.${domain})
) {} (builtins.attrNames sites)
