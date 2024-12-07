{ pkgs, lib, utils }:

let
  # Import the actual implementation
  siteLib = import ../../lib { inherit pkgs; };
  inherit (siteLib) mkSiteServices;
  inherit (utils) mkServiceName;

  testSites = {
    "example.com" = {
      gitRepo = "https://github.com/example/site.git";
      branch = "main";
      wwwRedirect = true;
      useHTTPS = true;
      host = "caddy";
    };
  };

  serviceUser = mkServiceName "example.com";
  result = mkSiteServices testSites;

  normalizeService = service:
    let
      # Remove the script field and normalize paths
      cleanService = removeAttrs service [ "script" ];

      # Convert derivation paths to strings
      normalizePaths = x:
        if builtins.isList x then
          map normalizePaths x
        else if builtins.isAttrs x then
          lib.mapAttrs (name: normalizePaths) x
        else if builtins.typeOf x == "path" then
          toString x
        else
          x;
    in normalizePaths cleanService;

  normalizedResult = lib.mapAttrs (name: normalizeService) result;
  expectedService = {
    ${serviceUser} = {
      description = "Build example.com website";
      path = with pkgs; [ bash curl git nix ];
      environment = {
        NIX_PATH =
          "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos:/nix/var/nix/profiles/per-user/root/channels";
        SITE_DOMAIN = "example.com";
        GIT_REPO = "https://github.com/example/site.git";
        SERVICE_USER = serviceUser;
      };
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
        ReadWritePaths = [ "/var/lib/${serviceUser}" "/var/www/example.com" ];
        BindReadOnlyPaths = [
          "/etc/resolv.conf"
          "/etc/ssl"
          "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        ];
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        Type = "oneshot";
        User = serviceUser;
        Group = serviceUser;
      };
    };
  };

  # Normalize the expected service too
  normalizedExpected = lib.mapAttrs (name: normalizeService) expectedService;

  # Convert to JSON for stable string comparison
  resultJson = builtins.toJSON normalizedResult;
  expectedJson = builtins.toJSON normalizedExpected;

  # Create temporary files with the JSON content
  expectedFile = pkgs.writeText "expected.json" expectedJson;
  resultFile = pkgs.writeText "result.json" resultJson;

in pkgs.runCommand "test-mk-site-services" {
  buildInputs = [ pkgs.jq pkgs.diffutils ];
  inherit resultJson expectedJson;
  inherit (result.${serviceUser}) script;
} ''
  # Compare the JSON structures
  if ! diff -u \
    <(jq . ${expectedFile}) \
    <(jq . ${resultFile}); then
    echo "Service structure test failed!"
    exit 1
  fi

  # Check the script path
  if [[ ! "$script" =~ ^/nix/store/.*-site-builder-example.com/bin/site-builder-example.com$ ]]; then
    echo "Script path test failed!"
    echo "Expected script path matching: /nix/store/*-site-builder-example.com/bin/site-builder-example.com"
    echo "Got: $script"
    exit 1
  fi

  touch $out
''
