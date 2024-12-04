{ pkgs, utils }:

sites:
let
  inherit (utils) shortHash;

  # Create a mapping of domains to service IDs
  domainMap = builtins.foldl' (acc: domain:
    acc // { ${domain} = "site-${shortHash domain}-builder"; }
  ) {} (builtins.attrNames sites);

  # Create the command script
  script = pkgs.writeShellScriptBin "site" ''
    set -e

    usage() {
      echo "Usage: site <command> <domain>"
      echo "Commands:"
      echo "  status  - Show service status for domain"
      echo "  restart - Rebuild site for domain"
      echo "  list    - List all managed domains"
      echo ""
      echo "Example: site status example.com"
      exit 1
    }

    if [ $# -lt 1 ]; then
      usage
    fi

    command="$1"
    domain="$2"

    # Create domain to service mapping
    declare -A services=(
      ${builtins.concatStringsSep "\n      " (
        builtins.attrValues (builtins.mapAttrs (domain: service:
          ''["${domain}"]="${service}"''
        ) domainMap)
      )}
    )

    case "$command" in
    "list")
      echo "Managed sites:"
      ${builtins.concatStringsSep "\n        " (
        builtins.map (domain: ''
          service="''${services[${domain}]}"
          status=$(systemctl is-active "$service.service" || echo "inactive")
          last_run=$(systemctl show "$service.service" \
            --property=ExecMainStartTimestamp | cut -d= -f2 | \
            xargs -I{} date -d "{}" +"%H:%M:%S")
          next_run=$(systemctl list-timers "$service.timer" --no-pager | \
            grep "$service" | awk '{print $3}' | \
            xargs -I{} date -d "{}" +"%H:%M:%S" || echo "")
          next_fmt=''${next_run:+" (next: $next_run)"}
          echo "  [$status] ${domain} (service: $service)"
          echo "    Last run: $last_run$next_fmt"
        '') (builtins.attrNames sites)
      )}
    ;;
    "status"|"restart")
      if [ -z "$domain" ]; then
        echo "Error: Domain is required"
        usage
      fi
      if [ -z "''${services[$domain]}" ]; then
        echo "Error: Domain '$domain' not found"
        echo "Use 'site list' to see available domains"
        exit 1
      fi
      if [ "$command" = "status" ]; then
        systemctl status -n 30 --no-pager -l "''${services[$domain]}"
      else
        systemctl restart "''${services[$domain]}"
      fi
      ;;
    *)
      echo "Error: Unknown command '$command'"
      usage
      ;;
    esac
  '';
in
script
