{ pkgs, utils }:

domain: site:
let
  inherit (utils) shortHash mkServiceName;

  serviceUser = mkServiceName domain;
  serviceId = shortHash domain;

  buildCommand = if site.builder or "nix" == "jekyll"
    then ''
      export NIX_USER_CONF_FILES="/var/lib/${serviceUser}/.config/nix/nix.conf"
      export XDG_CACHE_HOME="/var/lib/${serviceUser}/.cache"
      mkdir -p "$XDG_CACHE_HOME/nix/gitv3"
      nix build --no-link git+https://git.chobble.com/chobble/nix-jekyll-builder?ref=main#jekyllSite --override-input src . --print-out-paths
    ''
    else ''
      if [ -f "default.nix" ]; then
        nix-build --no-out-link --print-out-paths
      else
        pwd
      fi
    '';

  deployCommand = if site.host == "neocities" then
    if site ? dryRun && site.dryRun then ''
      echo "[DRY RUN] Would push to Neocities now"
    '' else ''
      echo "Pushing to Neocities"
      export NEOCITIES_API_KEY="${site.apiKey}"
      ${pkgs.neocities-cli}/bin/neocities push --prune /var/www/${domain}
    ''
  else ''
    # For Caddy, files are already in the correct place
    echo "Made /var/www/${domain} for Caddy serving"
  '';
in
pkgs.writeShellApplication {
  name = "site-builder-${domain}";
  runtimeInputs = with pkgs; [
    git
    nix
  ] ++ (if site.host == "neocities" then [ neocities-cli ] else []);

  text = ''
    repo_dir="/var/lib/${serviceUser}/site-builder-${domain}"
    www_dir="/var/www/${domain}"

    fail() {
      echo "Error: $1" >&2
      exit 1
    }

    # Ensure we're running as the correct user
    if [ "$(id -un)" != "${serviceUser}" ]; then
      fail "This script must be run as ${serviceUser}"
    fi

    echo "Starting site builder for ${domain}"
    echo "Repository: ${site.gitRepo} (${site.branch})"

    needs_rebuild=0
    old_rev=""

    # Try to use existing repo if it exists and is valid
    if [ -d "$repo_dir/.git" ]; then
      echo "Found existing repository, attempting to update..."
      cd "$repo_dir" || fail "Could not change to repository directory"
      old_rev=$(git rev-parse HEAD)
      git fetch origin || fail "Failed to fetch from remote"
      git reset --hard "origin/${site.branch}" || fail "Failed to reset to ${site.branch}"
      git clean -fdx
    else
      echo "Cloning fresh repository..."
      rm -rf "$repo_dir"
      git -c safe.directory='*' clone -b "${site.branch}" "${site.gitRepo}" "$repo_dir" \
        || fail "Failed to clone repository"
      needs_rebuild=1
    fi

    cd "$repo_dir" || fail "Could not change to repository directory"

    # Get new HEAD
    new_rev=$(git rev-parse HEAD)

    # Check if git revision changed
    if [ "$old_rev" != "$new_rev" ]; then
      echo "Git revision changed from $old_rev to $new_rev"
      needs_rebuild=1
    fi

    # Check if web directory is empty
    if [ ! -d "$www_dir" ] || [ -z "$(ls -A "$www_dir" 2>/dev/null)" ]; then
      echo "Web directory is empty"
      needs_rebuild=1
    fi

    if [ $needs_rebuild -eq 1 ]; then
      echo "Changes detected - rebuilding..."

      if [ -z "$www_dir" ]; then
        fail "www_dir is not set!"
      fi

      source_dir=$(${buildCommand}) || fail "Build failed"

      chmod -R u+w "$www_dir" || fail "Failed to set write permissions"
      find "$www_dir" -mindepth 1 -delete || fail "Failed to clean www directory"

      if [ -n "$(ls -A "$source_dir")" ]; then
        cp -r "$source_dir"/* "$www_dir/" || fail "Failed to copy files"
      else
        fail "Source directory is empty"
      fi

      # Create the .site-info file with service information
      cat > "$www_dir/.site-info" <<EOF
domain: ${domain}
service: ${serviceUser}
id: ${serviceId}
EOF

      ${deployCommand}

      echo "Site deployment complete (revision: $new_rev)"
    else
      echo "No changes detected, not rebuilding"
    fi
  '';
}
