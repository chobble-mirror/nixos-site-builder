{ pkgs, lib, utils, ... }:

with import ./lib.nix { inherit pkgs lib; };

let
  testLib = import ./lib.nix { inherit pkgs lib; };
  testSite = testLib.mkTestSite {
    name = "jekyll";
    content = ''
      ---
      layout: default
      title: Jekyll Test
      ---
      # Jekyll Test Site
    '';
  };
  testRepoPath = testLib.mkTestRepo testSite;
in {
  name = "site-builder-jekyll";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/site-builder.nix ];

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    networking.hosts."127.0.0.1" = [ "jekyll.test" ];

    environment.etc."gitconfig".text = ''
      [safe]
        directory = *
    '';

    services.site-builder = {
      enable = true;
      sites."jekyll.test" = {
        gitRepo = "file://${testRepoPath}";
        wwwRedirect = false;
        useHTTPS = false;
        builder = "jekyll";
      };
    };

    virtualisation = {
      memorySize = 1024;
      diskSize = 2048;
    };

    environment.systemPackages = [ pkgs.git pkgs.curl ];

    systemd.tmpfiles.rules = [
      "d /var/www 0755 root root -"
      "d /var/www/jekyll.test 0755 caddy caddy -"
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    # Get service name
    service_name = "site-" + machine.succeed(
      "echo -n jekyll.test | sha256sum | cut -c1-8"
    ).strip() + "-builder"

    # Check service configuration before starting
    machine.succeed(f"systemctl cat {service_name}.service")

    # Ensure directories exist and have correct permissions
    machine.succeed("ls -la /var/www/")
    machine.succeed("ls -la /var/lib/")

    # Try to start service with more detailed error reporting
    machine.succeed(f"systemctl start {service_name}.service || (journalctl -u {service_name}.service && exit 1)")

    # Wait for service to complete (since it's oneshot)
    machine.wait_until_succeeds(
      f"systemctl show -p ActiveState {service_name}.service | grep -q 'ActiveState=inactive'"
    )

    # Check status and logs regardless of outcome
    machine.succeed(f"systemctl status {service_name}.service || true")
    machine.succeed(f"journalctl -u {service_name}.service")

    # Original tests
    machine.succeed("test -f /var/www/jekyll.test/index.html")
    machine.succeed("grep -q 'Jekyll Test Site' /var/www/jekyll.test/index.html")
  '';
}
