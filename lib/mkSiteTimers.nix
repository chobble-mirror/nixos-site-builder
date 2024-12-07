{ pkgs, utils }:

sites:
let
  inherit (utils) mkServiceName;
  mkTimer = domain: cfg:
    let serviceUser = mkServiceName domain;
    in {
      "${serviceUser}" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5m";
          OnUnitActiveSec = "5m";
          RandomizedDelaySec = "5m";
        };
      };
    };
in builtins.foldl' (acc: domain: acc // (mkTimer domain sites.${domain})) { }
(builtins.attrNames sites)
