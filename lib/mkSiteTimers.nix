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
      hashString = builtins.hashString "sha256" domain;
      hashNum = builtins.foldl'
        (sum: c: sum + builtins.stringLength (toString c))
        0
        (builtins.split "" hashString);
      offset = hashNum - (builtins.div
        hashNum
        timerConfig.interval.seconds *
        timerConfig.interval.seconds);
    in {
      "${serviceUser}" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = timerConfig.initialDelay;
          OnUnitActiveSec = "${toString timerConfig.interval.minutes}m";
          RandomizedDelaySec = toString offset;
        };
      };
    };
in
builtins.foldl'
  (acc: domain: acc // (mkTimer domain sites.${domain}))
  {}
  (builtins.attrNames sites)
