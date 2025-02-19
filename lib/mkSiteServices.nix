{
  pkgs,
  utils,
  mkSiteBuilder ? import ./mkSiteBuilder.nix { inherit pkgs utils; },
}:

sites:
let
  inherit (utils) mkServiceName;

  mkService =
    domain: cfg:
    let
      serviceUser = mkServiceName domain;
      siteBuilder = mkSiteBuilder domain cfg;
    in
    {
      "${serviceUser}" = {
        description = "Build ${domain} website";
        path = with pkgs; [
          bash
          curl
          git
          nix
        ];
        environment = {
          NIX_PATH = "nixpkgs=${pkgs.path}";
          SITE_DOMAIN = domain;
          GIT_REPO = cfg.gitRepo;
          SERVICE_USER = serviceUser;
        };

        script = "${siteBuilder}/bin/site-builder-${domain}";

        serviceConfig = {
          CapabilityBoundingSet = "";
          IPAddressAllow = [
            "0.0.0.0/0"
            "::/0"
          ];
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateNetwork = false;
          PrivateTmp = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectSystem = "strict";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
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
          DynamicUser = "yes";
          User = serviceUser;
          Group = serviceUser;
        };
      };
    };
in
builtins.foldl' (acc: domain: acc // (mkService domain sites.${domain})) { } (
  builtins.attrNames sites
)
