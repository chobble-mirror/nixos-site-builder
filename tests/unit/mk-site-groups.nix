{ pkgs, lib }:

let
  mkSiteGroups = import ../../lib/mkSiteGroups.nix { inherit pkgs; };

  testSites = {
    "example.com" = {
      gitRepo = "https://github.com/example/site.git";
      wwwRedirect = true;
    };
  };

  result = mkSiteGroups testSites;
  expected = {
    "example-com-builder" = {};
  };
in
pkgs.runCommand "test-mk-site-groups" {} ''
  if [[ "${builtins.toJSON result}" != "${builtins.toJSON expected}" ]]; then
    echo "Test failed!"
    echo "Expected: ${builtins.toJSON expected}"
    echo "Got: ${builtins.toJSON result}"
    exit 1
  fi
  touch $out
''
