{ pkgs, lib, utils }:

let
  mkSiteVhosts = import ../../lib/mkSiteVhosts.nix { inherit pkgs utils; };

  testSites = {
    "example.com" = {
      gitRepo = "https://github.com/example/site.git";
      wwwRedirect = true;
      useHTTPS = false;
    };
    "neocities.example" = {
      gitRepo = "https://github.com/example/site.git";
      wwwRedirect = false;
      useHTTPS = false;
      host = "neocities";
      apiKey = "dummy-key";
    };
    "explicit-caddy.example" = {
      gitRepo = "https://github.com/example/site.git";
      wwwRedirect = false;
      useHTTPS = false;
      host = "caddy";
    };
  };

  result = mkSiteVhosts testSites;

  tests = [
    {
      name = "default-caddy-has-vhost";
      test = builtins.hasAttr "http://example.com" result;
      expected = true;
    }
    {
      name = "default-caddy-has-www-redirect";
      test = builtins.hasAttr "http://www.example.com" result;
      expected = true;
    }
    {
      name = "neocities-no-vhost";
      test = builtins.hasAttr "http://neocities.example" result;
      expected = false;
    }
    {
      name = "explicit-caddy-has-vhost";
      test = builtins.hasAttr "http://explicit-caddy.example" result;
      expected = true;
    }
  ];
in
pkgs.runCommand "test-mk-site-vhosts" {} ''
  ${lib.concatMapStrings (t: ''
    if [[ "${builtins.toJSON t.test}" != "${builtins.toJSON t.expected}" ]]; then
      echo "Test '${t.name}' failed!"
      echo "Expected: ${builtins.toJSON t.expected}"
      echo "Got: ${builtins.toJSON t.test}"
      exit 1
    fi
  '') tests}
  touch $out
''
