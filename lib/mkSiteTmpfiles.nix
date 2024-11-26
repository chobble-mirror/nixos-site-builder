{ pkgs }:

sites:
let
  mkTmpfiles = domain: cfg:
    let
      sanitizedDomain = builtins.replaceStrings ["."] ["-"] domain;
      serviceUser = "${sanitizedDomain}-builder";
    in [
      "d /var/lib/${serviceUser} 0755 ${serviceUser} ${serviceUser}"
      "d /var/www/${domain} 0755 ${serviceUser} ${serviceUser}"
    ];
in
builtins.foldl' (acc: domain:
  acc ++ (mkTmpfiles domain sites.${domain})
) [] (builtins.attrNames sites)
