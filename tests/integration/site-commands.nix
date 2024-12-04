{ pkgs, lib, utils }:

with import ./lib.nix { inherit pkgs lib; };

let
  testLib = import ./lib.nix { inherit pkgs lib; };
  testSite = testLib.mkTestSite {
    name = "command-test";
    content = "<h1>Command Test Site</h1>";
  };
  testRepoPath = testLib.mkTestRepo testSite;
  inherit (utils) shortHash;
  serviceUser = "site-${shortHash "example.test"}-builder";

  siteCommand = import ../../lib/mkSiteCommands.nix { inherit pkgs utils; } {
    "example.test" = {
      gitRepo = "file://${testRepoPath}";
      wwwRedirect = false;
      useHTTPS = false;
    };
  };
in {
  name = "site-builder-commands";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/site-builder.nix ];

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

    # Create required users and groups
    users.users.${serviceUser} = {
      isSystemUser = true;
      group = serviceUser;
      home = "/var/lib/${serviceUser}";
      createHome = true;
    };

    users.groups.${serviceUser} = {};

    # Enable the service for testing
    systemd.services.${serviceUser} = {
      wantedBy = [ "multi-user.target" ];
    };

    virtualisation = {
      memorySize = 1024;
      diskSize = 2048;
    };

    environment.systemPackages = with pkgs; [
      git
      curl
      siteCommand
    ];

    systemd.tmpfiles.rules = [
      "d /var/www 0755 root root -"
      "d /var/www/example.test 0755 ${serviceUser} ${serviceUser} -"
      "d /var/lib/${serviceUser} 0755 ${serviceUser} ${serviceUser} -"
      "d /var/lib/${serviceUser}/site-builder-example.test 0755 ${serviceUser} ${serviceUser} -"
    ];
  };


  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("Test site command list"):
        output = machine.succeed("site list")
        assert "example.test" in output, "Domain not found in site list"
        assert "active" in output, "Active status not found in site list"
        assert "${serviceUser}" in output, "Service ID not found in site list"

    with subtest("Test site command status"):
        output = machine.succeed("site status example.test || [[ $? == 3 ]]")
        assert "${serviceUser}.service" in output, "Service status not shown"

    with subtest("Test initial service state"):
        # Start the service and wait for it to complete
        machine.succeed("systemctl start ${serviceUser}.service")
        machine.wait_until_succeeds(
            "systemctl show -p ActiveState ${serviceUser}.service | grep -q 'ActiveState=inactive'"
        )

        # Verify the service completed successfully
        machine.succeed(
            "systemctl show -p Result ${serviceUser}.service | grep -q 'Result=success'"
        )

        # Check that the site files were deployed
        machine.wait_until_succeeds("test -f /var/www/example.test/.site-info")
        machine.succeed("test -f /var/www/example.test/index.html")

    with subtest("Test site info file"):
        info = machine.succeed("cat /var/www/example.test/.site-info")
        assert "domain: example.test" in info, "Domain not found in site info"
        assert "service: ${serviceUser}" in info, "Service not found in site info"
        assert "id: ${shortHash "example.test"}" in info, "ID not found in site info"

    with subtest("Test site command restart"):
        machine.succeed("site restart example.test")
        # Wait for the restart to complete
        machine.wait_until_succeeds(
            "systemctl show -p ActiveState ${serviceUser}.service | grep -q 'ActiveState=inactive'"
        )
        machine.succeed(
            "systemctl show -p Result ${serviceUser}.service | grep -q 'Result=success'"
        )

    with subtest("Test invalid commands"):
        machine.fail("site status invalid.test")
        machine.fail("site invalid-command example.test")

    with subtest("Verify site content"):
        content = machine.succeed("cat /var/www/example.test/index.html")
        assert "<h1>Command Test Site</h1>" in content, "Expected content not found"
  '';
}
