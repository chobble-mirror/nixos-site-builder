{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.site-builder;

  siteBuilder = pkgs.writeScriptBin "site-builder"
    (builtins.readFile ../scripts/site-builder.sh);

  siteLib = import ../lib { inherit pkgs; };
in {
  options.services.site-builder = {
    enable = mkEnableOption "static site builder service";

    sites = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          gitRepo = mkOption {
            type = types.str;
            description = "Git repository URL";
            example = "https://github.com/example/site.git";
          };
          wwwRedirect = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to redirect www subdomain to naked domain";
          };
          useHTTPS = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to use HTTPS for this site";
          };
        };
      });
      default = {};
      description = mdDoc ''
        Attribute set of sites to build and serve.
        Each site is configured with a git repository and optional settings.
      '';
      example = literalExpression ''
        {
          "example.com" = {
            gitRepo = "https://github.com/example/site.git";
            wwwRedirect = true;
          };
        }
      '';
    };

    caddy = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable and configure Caddy web server";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.sites != {};
        message = "At least one site must be configured when site-builder is enabled";
      }
    ];

    systemd.services = siteLib.mkSiteServices cfg.sites siteBuilder;
    systemd.timers = siteLib.mkSiteTimers cfg.sites;
    users.users = siteLib.mkSiteUsers cfg.sites;
    users.groups = siteLib.mkSiteGroups cfg.sites;
    systemd.tmpfiles.rules = siteLib.mkSiteTmpfiles cfg.sites;

    services.caddy = mkIf cfg.caddy.enable {
      enable = true;
      virtualHosts = siteLib.mkSiteVhosts cfg.sites;
    };
  };
}
