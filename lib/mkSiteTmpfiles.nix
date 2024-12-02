{ pkgs, utils }:

sites:
let
  inherit (utils) shortHash;

  mkTmpfiles = domain: cfg:
    let
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
