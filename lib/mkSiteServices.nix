{ pkgs, mkSiteBuilder ? import ./mkSiteBuilder.nix { inherit pkgs; } }:

sites:
let
  mkSiteBuilder = import ./mkSiteBuilder.nix { inherit pkgs; };

  shortHash = domain:
    builtins.substring 0 8 (builtins.hashString "sha256" domain);

  mkService = domain: cfg:
    let
      sanitizedDomain = builtins.replaceStrings ["."] ["-"] domain;
      serviceUser = "site-${shortHash domain}-builder";
      siteBuilder = mkSiteBuilder domain cfg;
    in {
      "${serviceUser}" = {
        description = "Build ${domain} website";
        path = with pkgs; [
          bash
          curl
          git
          nix
        ];
        environment = {
          NIX_PATH = "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos:/nix/var/nix/profiles/per-user/root/channels";
          SITE_DOMAIN = domain;
          GIT_REPO = cfg.gitRepo;
          SERVICE_USER = serviceUser;
        };

        script = "${siteBuilder}/bin/site-builder-${domain}";

        serviceConfig = {
          CapabilityBoundingSet = "";
          IPAddressAllow = [ "0.0.0.0/0" "::/0" ];
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateNetwork = false;
          PrivateTmp = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectSystem = "strict";
          RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
          RestrictNamespaces = true;
          RestrictRealtime = true;

          ReadWritePaths = [
            "/var/lib/${serviceUser}"
            "/var/www/${domain}"
          ];

          BindReadOnlyPaths = [
            "/etc/resolv.conf"
            "/etc/ssl"
            "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
          ];

          Type = "oneshot";
          User = serviceUser;
          Group = serviceUser;
        };
      };
    };
in
builtins.foldl' (acc: domain:
  acc // (mkService domain sites.${domain})
) {} (builtins.attrNames sites)
