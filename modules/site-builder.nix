{ config, lib, pkgs, ... }:

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
        default = "master";
        description = "Git branch to track";
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
        type = types.enum [ "caddy" "neocities" ];
        default = "caddy";
        description = "Hosting service to use (caddy or neocities)";
      };
      apiKey = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "API key for the hosting service (if required)";
      };
    };
  };

  mkSiteBuilder = domain: site:
    let
      sanitizedDomain = builtins.replaceStrings ["."] ["-"] domain;
      serviceUser = "${sanitizedDomain}-builder";
      deployCommand = if site.host == "neocities" then ''
        echo "Deploying to Neocities..."
        export NEOCITIES_API_KEY="${site.apiKey}"
        ${pkgs.neocities-cli}/bin/neocities push --prune /var/www/${domain}
      '' else ''
        # For Caddy, files are already in the correct place
        echo "Files deployed for Caddy serving"
      '';
    in
    pkgs.writeShellApplication {
      name = "site-builder-${domain}";
      runtimeInputs = with pkgs; [
        git
        nix
      ]  ++ (if site.host == "neocities" then [ neocities-cli ] else []);

      text = ''
        repo_dir="/var/lib/${serviceUser}/site-builder-${domain}"
        www_dir="/var/www/${domain}"

        fail() {
          echo "Error: $1" >&2
          exit 1
        }

        # Ensure we're running as the correct user
        if [ "$(id -un)" != "${serviceUser}" ]; then
          fail "This script must be run as ${serviceUser}"
        fi

        echo "Starting site builder for ${domain}"
        echo "Repository: ${site.gitRepo} (${site.branch})"

        needs_rebuild=0
        old_rev=""

        # Try to use existing repo if it exists and is valid
        if [ -d "$repo_dir/.git" ]; then
          echo "Found existing repository, attempting to update..."
          cd "$repo_dir" || fail "Could not change to repository directory"
          old_rev=$(git rev-parse HEAD)
          git fetch origin || fail "Failed to fetch from remote"
          git reset --hard "origin/${site.branch}" || fail "Failed to reset to ${site.branch}"
          git clean -fdx
        else
          echo "Cloning fresh repository..."
          rm -rf "$repo_dir"
          git -c safe.directory='*' clone -b "${site.branch}" "${site.gitRepo}" "$repo_dir" \
            || fail "Failed to clone repository"
          needs_rebuild=1
        fi

        cd "$repo_dir" || fail "Could not change to repository directory"

        # Get new HEAD
        new_rev=$(git rev-parse HEAD)

        # Check if git revision changed
        if [ "$old_rev" != "$new_rev" ]; then
          echo "Git revision changed from $old_rev to $new_rev"
          needs_rebuild=1
        fi

        # Check if web directory is empty
        if [ ! -d "$www_dir" ] || [ -z "$(ls -A "$www_dir" 2>/dev/null)" ]; then
          echo "Web directory is empty"
          needs_rebuild=1
        fi

        if [ $needs_rebuild -eq 1 ]; then
          echo "Changes detected - rebuilding..."

          if [ -z "$www_dir" ]; then
            fail "www_dir is not set!"
          fi

          chmod -R u+w "$www_dir" || fail "Failed to set write permissions"
          find "$www_dir" -mindepth 1 -delete || fail "Failed to clean www directory"

          # Build the site using nix-build if a default.nix exists
          if [ -f "default.nix" ]; then
            echo "Building with nix-build..."
            latest_build=$(nix-build --no-out-link) || fail "nix-build failed"
            cp -r "$latest_build"/* "$www_dir/" || fail "Failed to copy build output"
          else
            echo "No default.nix found, copying files directly..."
            cp -r ./* "$www_dir/" || fail "Failed to copy files"
          fi

          ${deployCommand}

          echo "Site deployment complete (revision: $new_rev)"
        else
          echo "No changes detected, not rebuilding"
        fi
      '';
    };

  # Import the library functions
  siteLib = import ../lib { inherit pkgs; };

  # Create a builder derivation for each site
  siteBuilders = mapAttrs mkSiteBuilder cfg.sites;

  in {
    options.services.site-builder = {
      enable = mkEnableOption (mdDoc "static site builder service");

      sites = mkOption {
        type = types.attrsOf siteConfig;
        default = {};
        description = mdDoc ''
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
          description = mdDoc "Whether to enable and configure Caddy web server";
        };
      };

      # Add a new option to expose the builder function
      _mkSiteBuilder = mkOption {
        internal = true;
        visible = false;
        readOnly = true;
        default = mkSiteBuilder;
      };
    };

    config = mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.sites != {};
          message = "At least one site must be configured when site-builder is enabled";
        }
      ];

      # Use the existing library functions with the site-specific builders
      systemd.services = siteLib.mkSiteServices cfg.sites siteBuilders;
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
