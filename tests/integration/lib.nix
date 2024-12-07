{ pkgs, lib, utils }: {
  # Helper to create a test site with specific content
  mkTestSite = { name, content ? "<h1>Test Site</h1>" }:
    pkgs.writeTextDir "index.html" ''
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
      # Create a temporary working directory
      workdir=$(mktemp -d)
      cd "$workdir"

      # Initialize the working repository
      git init
      git config --local init.defaultBranch main
      cp -r $src/* .
      git add .
      git -c user.name="Test User" -c user.email="test@example.com" commit -m "Initial commit"
      git branch -M main

      # Create the bare repository
      mkdir $out
      cd $out
      git init --bare
      git symbolic-ref HEAD refs/heads/main

      # Push from working repo to bare repo
      cd "$workdir"
      git remote add origin "$out"
      git push origin main:refs/heads/main

      # Cleanup
      rm -rf "$workdir"
      chmod -R 755 $out
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
