{ pkgs, lib, utils }:

let
  mkSiteCommands = import ../../lib/mkSiteCommands.nix { inherit pkgs utils; };

  testSites = {
    "example.com" = {
      gitRepo = "https://github.com/example/site.git";
      wwwRedirect = true;
    };
    "test.org" = {
      gitRepo = "https://github.com/test/site.git";
      wwwRedirect = false;
    };
  };
  inherit (utils) shortHash;
  result = mkSiteCommands testSites;
in
pkgs.runCommand "test-mk-site-commands" {
  buildInputs = [ pkgs.bash ];
  script = "${result}/bin/site";
} ''
  # Create a function to run tests
  run_test() {
    local name="$1"
    local command="$2"
    local expected="$3"
    local output

    echo "Running test: $name"
    output=$($command 2>&1) || true
    if ! echo "$output" | grep -q "$expected"; then
      echo "Test failed: $name"
      echo "Expected to find: $expected"
      echo "Got output: $output"
      exit 1
    fi
  }

  # Test help output
  run_test "help" \
    "$script" \
    "Usage: site <command> <domain>"

  # Test list command
  run_test "list command" \
    "$script list" \
    "example.com (service: site-${shortHash "example.com"}-builder)"

  # Test invalid command
  run_test "invalid command" \
    "$script invalid-command example.com" \
    "Error: Unknown command"

  # Test invalid domain
  run_test "invalid domain" \
    "$script status invalid.domain" \
    "Error: Domain 'invalid.domain' not found"

  touch $out
''
