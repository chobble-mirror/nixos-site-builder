{ pkgs }:

sites:
let
  shortHash = domain:
    builtins.substring 0 8 (builtins.hashString "sha256" domain);

  mkTimer = domain: cfg:
    let
      serviceUser = "site-${shortHash domain}-builder";
    in {
      "${serviceUser}" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "5min";
        };
      };
    };
in
builtins.foldl' (acc: domain:
  acc // (mkTimer domain sites.${domain})
) {} (builtins.attrNames sites)
