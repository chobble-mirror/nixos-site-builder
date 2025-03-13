{
  pkgs,
  lib,
  utils,
}:

with import ./lib.nix { inherit pkgs lib; };

let
  testLib = import ./lib.nix { inherit pkgs lib; };
  testSite = testLib.mkTestSite {
    name = "basic";
    content = "<h1>Basic Test Site</h1>";
  };
  testRepoPath = testLib.mkTestRepo testSite;
  inherit (utils) mkServiceName;
  serviceUser = mkServiceName "example.test";
in
{
  name = "site-builder-basic";

  nodes.machine =
    { config, pkgs, ... }:
    {
      imports = [
        ../../modules/site-builder.nix
      ];

      networking.hosts."127.0.0.1" = [ "example.test" ];

      environment.etc."gitconfig".text = ''
        [safe]
          directory = *
      '';

      services.site-builder = {
        enable = true;
        sites."example.test" = {
          gitRepo = "file://${testRepoPath}";
          wwwRedirect = false;
          useHTTPS = false;
        };
      };

      virtualisation = {
        memorySize = 1024;
        diskSize = 2048;
      };

      environment.systemPackages = [
        pkgs.git
        pkgs.curl
      ];

      systemd.tmpfiles.rules = [
        "d /var/www 0755 root root -"
        "d /var/www/example.test 0755 caddy caddy -"
      ];
    };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    # Test service
    machine.succeed("systemctl start ${serviceUser}.service")
    # machine.succeed("systemctl is-system-running --wait")
    machine.succeed("systemctl is-active ${serviceUser}.service || [ $? -eq 3 ]")

    # Test Caddy
    machine.wait_for_unit("caddy.service")

    # Test site
    ${testLib.testSite "example.test"}
    machine.succeed("grep -q 'Basic Test Site' /tmp/example.test-content")
  '';
}
