{ pkgs, lib, utils }:

with import ./lib.nix { inherit pkgs lib; };

let
  testLib = import ./lib.nix { inherit pkgs lib; };
  site1 = testLib.mkTestSite {
    name = "site1";
    content = "<h1>First Test Site</h1>";
  };
  site2 = testLib.mkTestSite {
    name = "site2";
    content = "<h1>Second Test Site</h1>";
  };
  repo1Path = testLib.mkTestRepo site1;
  repo2Path = testLib.mkTestRepo site2;
in {
  name = "site-builder-multiple";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/site-builder.nix ];

    networking.hosts."127.0.0.1" = [
      "first.test"
      "www.first.test"
      "second.test"
    ];

    environment.etc."gitconfig".text = ''
      [safe]
          directory = *
    '';

    services.site-builder = {
      enable = true;
      sites = {
        "first.test" = {
          gitRepo = "file://${repo1Path}";
          wwwRedirect = true;
          useHTTPS = false;
        };
        "second.test" = {
          gitRepo = "file://${repo2Path}";
          wwwRedirect = false;
          useHTTPS = false;
        };
      };
    };

    virtualisation = {
      memorySize = 1024;
      diskSize = 2048;
    };

    environment.systemPackages = [ pkgs.git pkgs.curl ];

    systemd.tmpfiles.rules = [
      "d /var/www 0755 root root -"
      "d /var/www/first.test 0755 caddy caddy -"
      "d /var/www/second.test 0755 caddy caddy -"
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    first_service = "site-" + machine.succeed(
      "echo -n first.test | sha256sum | cut -c1-8"
    ).strip() + "-builder"
    second_service = "site-" + machine.succeed(
      "echo -n second.test | sha256sum | cut -c1-8"
    ).strip() + "-builder"

    # Test services
    machine.succeed(f"systemctl start {first_service}.service")
    machine.succeed(f"systemctl start {second_service}.service")
    machine.succeed("systemctl is-system-running --wait")
    machine.succeed(f"systemctl is-active {first_service}.service || [ $? -eq 3 ]")
    machine.succeed(f"systemctl is-active {second_service}.service || [ $? -eq 3 ]")

    # Test Caddy
    machine.wait_for_unit("caddy.service")

    # Test sites
    ${testLib.testSite "first.test"}
    machine.succeed("grep -q 'First Test Site' /tmp/first.test-content")

    ${testLib.testSite "second.test"}
    machine.succeed("grep -q 'Second Test Site' /tmp/second.test-content")

    # Test www redirect for first.test
    machine.succeed(
      "curl -f -L http://www.first.test/index.html > /tmp/www-redirect-content"
    )
    machine.succeed("grep -q 'First Test Site' /tmp/www-redirect-content")
  '';
}
