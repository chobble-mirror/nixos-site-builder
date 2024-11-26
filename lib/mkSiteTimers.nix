{ pkgs }:

sites:
let
  mkTimer = domain: cfg:
    let
      sanitizedDomain = builtins.replaceStrings ["."] ["-"] domain;
    in {
      "${sanitizedDomain}-builder" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "1min";
          OnUnitActiveSec = "1h";
        };
      };
    };
in
builtins.foldl' (acc: domain:
  acc // (mkTimer domain sites.${domain})
) {} (builtins.attrNames sites)
