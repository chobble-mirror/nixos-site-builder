{ pkgs }:

sites:
let
  shortHash = domain:
    builtins.substring 0 8 (builtins.hashString "sha256" domain);

  mkTmpfiles = domain: cfg:
    let
      sanitizedDomain = builtins.replaceStrings ["."] ["-"] domain;
      serviceUser = "site-${shortHash domain}-builder";
    in [
      "d /var/lib/${serviceUser} 0755 ${serviceUser} ${serviceUser}"
      "d /var/www/${domain} 0755 ${serviceUser} ${serviceUser}"
      "Z /var/www/${domain} 0755 ${serviceUser} ${serviceUser}"
    ];
in
builtins.foldl' (acc: domain:
  acc ++ (mkTmpfiles domain sites.${domain})
) [] (builtins.attrNames sites)
