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
          output file "/var/log/caddy/access-${domain}.log" {
            roll_keep_for 1d
            roll_size 10MiB
          }
          format transform `{request>remote_ip} - {request>user_id} [{ts}] "{request>method} {request>uri} {request>proto}" {status} {size} "{request>headers>Referer>[0]}" "{request>headers>User-Agent>[0]}"` {
            time_format "02/Jan/2006:15:04:05 -0700"
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
