{ pkgs, utils }:

sites:
let
  mkVhost =
    domain: cfg:
    let
      host = cfg.host or "caddy";
      mkLogFormat = domain: ''
        output file /var/log/caddy/${domain}.log {
          roll_size 1mb
          roll_keep 1
          roll_keep_for 24h
        }
      '';
    in
    if host != "caddy" then
      { }
    else
      let
        protocol = if cfg.useHTTPS then "https" else "http";
      in
      {
        "${protocol}://${domain}" = {
          listenAddresses = [ "0.0.0.0" ];
          extraConfig = ''
            root * /var/www/${domain}
            file_server
            encode gzip zstd

            handle_errors {
              rewrite * /{err.status_code}.html
              file_server
            }

            @static {
              path_regexp \.(ico|css|js|gif|jpg|jpeg|png|svg|webp|woff|woff2)$
            }
            header @static Cache-Control max-age=31536000

            @uptime_kuma header_regexp User-Agent ^Uptime-Kuma
            log_skip @uptime_kuma
          '';
          logFormat = mkLogFormat domain;
        };
      }
      // (
        if cfg.wwwRedirect then
          {
            "${protocol}://www.${domain}" = {
              listenAddresses = [ "0.0.0.0" ];
              extraConfig = ''
                redir ${protocol}://${domain}{uri} permanent
              '';
              logFormat = mkLogFormat domain;
            };
          }
        else
          { }
      );
in
builtins.foldl' (acc: domain: acc // (mkVhost domain sites.${domain})) { } (
  builtins.attrNames sites
)
