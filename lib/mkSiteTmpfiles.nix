{ pkgs, utils }:

sites:
let
  inherit (utils) mkServiceName;

  mkTmpfiles = domain: cfg:
    let serviceUser = mkServiceName domain;
    in [
      "d /var/lib/${serviceUser} 0755 ${serviceUser} ${serviceUser}"
      "d /var/www/${domain} 0755 ${serviceUser} ${serviceUser}"
      "Z /var/www/${domain} 0755 ${serviceUser} ${serviceUser}"
    ];
in builtins.foldl' (acc: domain: acc ++ (mkTmpfiles domain sites.${domain})) [ ]
(builtins.attrNames sites)
