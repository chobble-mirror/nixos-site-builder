{ pkgs, lib }:

let
  mkSiteServices = import ../../lib/mkSiteServices.nix { inherit pkgs; };

  mockBuilder = pkgs.writeScriptBin "site-builder" "";

  testSites = {
    "example.com" = {
      gitRepo = "https://github.com/example/site.git";
      wwwRedirect = true;
    };
  };

  result = mkSiteServices testSites mockBuilder;

  # Test specific attributes we care about
  tests = [
    {
      name = "has-service";
      test = builtins.hasAttr "example-com-builder" result;
      expected = true;
    }
    {
      name = "has-environment";
      test = builtins.hasAttr "environment" result."example-com-builder";
      expected = true;
    }
  ];
in
pkgs.runCommand "test-mk-site-services" {} ''
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
