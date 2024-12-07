{ pkgs, lib, utils }:

with import ./lib.nix { inherit pkgs lib utils; };

let
  testLib = import ./lib.nix { inherit pkgs lib utils; };
  testRepoPath = toString (pkgs.runCommand "jekyll-test-files" {
    nativeBuildInputs = [ pkgs.git ];
  } ''
    mkdir -p $out
    cd $out

    # Create Jekyll site structure
    cat > Gemfile <<EOF
    ${builtins.readFile ./jekyll/Gemfile}
    EOF

    cat > Gemfile.lock <<EOF
    ${builtins.readFile ./jekyll/Gemfile.lock}
    EOF

    cat > gemset.nix <<EOF
    ${builtins.readFile ./jekyll/gemset.nix}
    EOF

    cat > _config.yml <<EOF
    title: Jekyll Test Site
    baseurl: ""
    url: ""
    EOF

    cat > index.md <<EOF
    ---
    layout: default
    ---
    # Jekyll Test Site

    This is a test page.
    EOF

    mkdir -p _layouts
    cat > _layouts/default.html <<EOF
    <!DOCTYPE html>
    <html>
      <head>
        <title>{{ site.title }}</title>
      </head>
      <body>
        {{ content }}
      </body>
    </html>
    EOF

    # Initialize git repo
    git init
    git config --local init.defaultBranch main
    git add .
    git -c user.email="test@example.com" -c user.name="Test User" commit -m "Initial commit"
    git branch -M main

    # Convert to bare repo after branch is set
    git config --bool core.bare true
    chmod -R 755 .
  '');
in {
  name = "site-builder-jekyll";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/site-builder.nix ];

    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      accept-flake-config = true;
      sandbox = false;
      keep-failed = true;
      show-trace = true;
      log-lines = 50;
      trusted-users = [ "root" "site-4bb116a1-builder" ];
      system-features = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
    };

    # Ensure the service user has access to nix configuration
    systemd.services."site-4bb116a1-builder" = {
      serviceConfig = {
        BindReadOnlyPaths = [ "/etc/nix/nix.conf" ];
        Environment =
          [ "NIX_CONFIG='experimental-features = nix-command flakes'" ];
      };
    };

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

    service_name = "site-" + machine.succeed(
      "echo -n jekyll.test | sha256sum | cut -c1-8"
    ).strip() + "-builder.service"

    machine.succeed(f"systemctl cat {service_name}")
    machine.succeed(f"systemctl start {service_name}")
    machine.wait_until_succeeds(
      f"systemctl show -p ActiveState {service_name} | grep -q 'ActiveState=inactive'"
    )

    machine.succeed("test -f /var/www/jekyll.test/index.html")
    machine.succeed("grep -q 'Jekyll Test Site' /var/www/jekyll.test/index.html")
  '';
}
