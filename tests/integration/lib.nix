{ pkgs, lib }:
let
  self = {
    # Helper to create a test site with specific content
    mkTestSite = { name, content }:
      pkgs.writeTextDir "index.html" ''
        <!DOCTYPE html>
        <html>
          <body>
            ${content}
          </body>
        </html>
      '';

    mkTestRepo = input:
      toString (pkgs.runCommand "test-repo" {
        buildInputs = [ pkgs.git ];
        inherit input;
        GIT_COMMITTER_NAME = "Test User";
        GIT_COMMITTER_EMAIL = "test@example.com";
        GIT_AUTHOR_NAME = "Test User";
        GIT_AUTHOR_EMAIL = "test@example.com";
        HOME = "/build";
        NIX_BUILD_TOP = "/build";
      } ''
        mkdir -p $HOME
        mkdir $out
        cd $out
        cp -r $input/* .
        git config --global init.defaultBranch main
        git init
        git add .
        git commit -m "Initial commit"
        chmod -R 755 .
      '');

    testSite = domain: ''
      # Check site files
      machine.succeed("test -f /var/www/${domain}/index.html")
      machine.succeed("test -s /var/www/${domain}/index.html")

      # Test HTTP response
      machine.succeed("curl -f http://${domain}/index.html > /tmp/${domain}-content")
    '';
  };
in self
