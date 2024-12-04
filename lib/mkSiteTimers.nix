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
      minutes = builtins.toString (builtins.div offset 60 + 100);
      seconds = builtins.toString (offset - (builtins.div offset 60 * 60) + 100);
      paddedMinutes = builtins.substring 1 2 minutes;
      paddedSeconds = builtins.substring 1 2 seconds;
    in {
      "${serviceUser}" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = timerConfig.initialDelay;
          OnUnitActiveSec = "*:${paddedMinutes}:${paddedSeconds}";
        };
      };
    };
in
builtins.foldl'
  (acc: domain: acc // (mkTimer domain sites.${domain}))
  {}
  (builtins.attrNames sites)
