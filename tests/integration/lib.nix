{ pkgs, lib }: {
  # Helper to create a test site with specific content
  mkTestSite =
    { name, content ? "<h1>Test Site</h1>", filename ? "index.html" }:
    pkgs.writeTextDir "${filename}" ''
      <!DOCTYPE html>
      <html>
        <body>
          ${content}
        </body>
      </html>
    '';

  # Helper to create a git repo from a site
  mkTestRepo = site:
    toString (pkgs.runCommand "test-repo" {
      buildInputs = [ pkgs.git ];
      src = site;
      GIT_COMMITTER_NAME = "Test User";
      GIT_COMMITTER_EMAIL = "test@example.com";
      GIT_AUTHOR_NAME = "Test User";
      GIT_AUTHOR_EMAIL = "test@example.com";
    } ''
      mkdir $out
      cd $out
      cp -r $src/* .
      git init
      git checkout -b main # Create and switch to main branch explicitly
      git add .
      git -c user.name="Test User" -c user.email="test@example.com" commit -m "Initial commit"
      git config --bool core.bare true
      chmod -R 755 .
    '');

  # Common test assertions as a function
  testSite = domain: ''
    # Check site files
    machine.succeed("test -f /var/www/${domain}/index.html")
    machine.succeed("test -s /var/www/${domain}/index.html")

    # Test HTTP response
    machine.succeed("curl -f http://${domain}/index.html > /tmp/${domain}-content")
  '';
}
