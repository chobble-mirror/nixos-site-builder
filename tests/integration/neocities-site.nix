# tests/integration/neocities-site.nix
{ pkgs, lib }:

with import ./lib.nix { inherit pkgs lib; };

let
  testLib = import ./lib.nix { inherit pkgs lib; };
  testSite = testLib.mkTestSite {
    name = "neocities";
    content = "<h1>Neocities Test Site</h1>";
  };
  testRepoPath = testLib.mkTestRepo testSite;
in {
  name = "site-builder-neocities";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/site-builder.nix ];

    environment.etc."gitconfig".text = ''
      [safe]
          directory = *
    '';

    services.site-builder = {
      enable = true;
      caddy.enable = false;
      sites."neocities.test" = {
        gitRepo = "file://${testRepoPath}";
        wwwRedirect = false;
        useHTTPS = false;
        host = "neocities";
        apiKey = "dummy-key";
        dryRun = true;
      };
    };

    virtualisation = {
      memorySize = 1024;
      diskSize = 2048;
    };

    environment.systemPackages = [ pkgs.git ];

    systemd.tmpfiles.rules = [
      "d /var/www 0755 root root -"
      "d /var/www/neocities.test 0755 root root -"
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    # Get the service unit file content
    unit_file = machine.succeed("systemctl cat neocities-test-builder.service")

    # Basic service checks
    assert "Type=oneshot" in unit_file, "Incorrect service type"
    assert "neocities-test-builder" in unit_file, "Service name not found"

    # Check that the www directory exists
    machine.succeed("test -d /var/www/neocities.test")

    # Verify that Caddy is not running and has no config
    machine.fail("systemctl is-active caddy.service")
    machine.fail("test -f /etc/caddy/Caddyfile")

    # Start the builder service and wait for it to complete
    machine.succeed("systemctl start neocities-test-builder.service")

    # Verify the site files are built
    machine.succeed("test -f /var/www/neocities.test/index.html")
    content = machine.succeed("cat /var/www/neocities.test/index.html")
    assert "Test Site" in content, "Expected content not found in index.html"
  '';
}
