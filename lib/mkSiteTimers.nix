{ pkgs, utils }:

sites:
let
  inherit (utils) shortHash;

  timerConfig = rec {
    interval = rec {
      minutes = 5;
      seconds = minutes * 60;
    };
    initialDelay = "5min";
  };

  mkTimer = domain: cfg:
    let
      serviceUser = "site-${shortHash domain}-builder";
    in {
      "${serviceUser}" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = timerConfig.initialDelay;
          OnUnitActiveSec = "${toString timerConfig.interval.minutes}m";
          RandomizedDelaySec = timerConfig.interval.seconds;
        };
      };
    };
in
builtins.foldl'
  (acc: domain: acc // (mkTimer domain sites.${domain}))
  {}
  (builtins.attrNames sites)
