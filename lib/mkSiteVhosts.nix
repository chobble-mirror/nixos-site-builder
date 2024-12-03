{ pkgs, utils }:

sites:
let
  mkVhost = domain: cfg:
    let
      host = cfg.host or "caddy";
    in
    if host != "caddy" then {} else
    let
      protocol = if cfg.useHTTPS then "https" else "http";
    in {
    "${protocol}://${domain}" = {
      listenAddresses = ["0.0.0.0"];
      extraConfig = ''
        root * /var/www/${domain}
        file_server
        encode gzip zstd

        handle_errors {
          rewrite * /{err.status_code}.html
          file_server
        }

        log {
          output file /var/log/caddy/access-${domain}.log {
            roll_size 100mb
            roll_keep 1
            roll_keep_for 24h
          }
          format filter {
			      request>headers>User-Agent delete
						request>headers>Cookie delete
						request>remote_ip ip_mask 16 32
						request>client_ip ip_mask 16 32
		      }
        }

        @static {
          path_regexp \.(ico|css|js|gif|jpg|jpeg|png|svg|webp|woff)$
        }
        header @static Cache-Control max-age=5184000
      '';
    };
  } // (if cfg.wwwRedirect then {
    "${protocol}://www.${domain}" = {
      listenAddresses = ["0.0.0.0"];
      extraConfig = ''
        redir ${protocol}://${domain}{uri} permanent
      '';
    };
  } else {});
in
builtins.foldl' (acc: domain:
  acc // (mkVhost domain sites.${domain})
) {} (builtins.attrNames sites)
