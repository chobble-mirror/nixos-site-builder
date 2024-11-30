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

        handle_errors {
          rewrite * /{err.status_code}.html
          file_server
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
