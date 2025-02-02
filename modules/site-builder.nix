{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.site-builder;

  # Define custom types for better type safety
  siteConfig = types.submodule {
    options = {
      gitRepo = mkOption {
        type = types.str;
        description = "Git repository URL";
        example = "https://github.com/example/site.git";
      };
      branch = mkOption {
        type = types.str;
        default = "main";
        description = "Git branch to track";
      };
      builder = mkOption {
        type = types.enum [
          "nix"
          "jekyll"
        ];
        default = "nix";
        description = "Site builder to use. Either 'nix' (default) or 'jekyll'";
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
      host = mkOption {
        type = types.enum [
          "caddy"
          "neocities"
        ];
        default = "caddy";
        description = "Hosting service to use (caddy or neocities)";
      };
      subfolder = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Subfolder within the repository to use as the site root";
        example = "public";
      };
      apiKey = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "API key for the hosting service (if required)";
      };
      dryRun = mkOption {
        type = types.bool;
        default = false;
        description = "If true, skip actual deployment (useful for testing)";
      };
    };
  };

  # Import the library functions
  siteLib = import ../lib { inherit pkgs; };

  hasCaddySites = sites: lib.any (cfg: (cfg.host or "caddy") == "caddy") (builtins.attrValues sites);

in
{
  options.services.site-builder = {
    enable = mkEnableOption ("static site builder service");

    sites = mkOption {
      type = types.attrsOf siteConfig;
      default = { };
      description = ''
        Attribute set of sites to build and serve.
        Each site is configured with a git repository and optional settings.
      '';
      example = literalExpression ''
        {
          "example.com" = {
            gitRepo = "https://github.com/example/site.git";
            branch = "main";
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

    environment.systemPackages = [ (siteLib.mkSiteCommands cfg.sites) ];
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.sites != { };
        message = "At least one site must be configured when site-builder is enabled";
      }
      {
        assertion = !hasCaddySites cfg.sites || cfg.caddy.enable;
        message = ''Caddy must be enabled when a site has host="caddy"'';
      }
    ];

    systemd.services = siteLib.mkSiteServices cfg.sites;
    systemd.timers = siteLib.mkSiteTimers cfg.sites;
    users.users = siteLib.mkSiteUsers cfg.sites;
    users.groups = siteLib.mkSiteGroups cfg.sites;
    systemd.tmpfiles.rules = siteLib.mkSiteTmpfiles cfg.sites;

    services.caddy = mkIf (cfg.caddy.enable && hasCaddySites cfg.sites) {
      enable = true;
      virtualHosts = siteLib.mkSiteVhosts cfg.sites;
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddyserver/transform-encoder@v0.0.0-20241223111140-47f376e021ef" ];
        hash = "sha256-v+7HOhXcJXwmVyev3+5a6oVFhXqKCnCqYdvNZrvAgVw=";
      };
    };

    environment.systemPackages = [ (siteLib.mkSiteCommands cfg.sites) ];
  };
}
