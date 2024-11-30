{ pkgs }:

sites:
let
  # Function to create a shortened hash of a string
  shortHash = str:
    builtins.substring 0 8 (builtins.hashString "sha256" str);

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
