{ pkgs, utils }:

domain: site:
let
  inherit (utils) shortHash mkServiceName;

  serviceUser = mkServiceName domain;
  serviceId = shortHash domain;

  repo_dir = "/var/lib/${serviceUser}/site-builder-${domain}";
  www_dir = "/var/www/${domain}";

  # Package required nix files
  nixFiles = pkgs.runCommand "site-builder-nix-files" { } ''
    mkdir -p $out/lib
    cp ${./mkSite.nix} $out/lib/mkSite.nix
    cp ${./utils.nix} $out/lib/utils.nix
    cp ${./jekyll-builder/default.nix} $out/lib/jekyll-builder.nix
  '';

  buildCommand = ''
    cd "${repo_dir}"
    site_dir=$(nix-build --no-out-link --expr "
      with import <nixpkgs> {};
      let
        mkSite = import ${nixFiles}/lib/mkSite.nix {
          inherit pkgs;
          utils = import ${nixFiles}/lib/utils.nix;
        };
      in mkSite "${domain}" {
        builder = if site ? builder then site.builder else "null";
        src = repo_dir;
      }
    ")
    echo "$site_dir"
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
in pkgs.writeShellApplication {
  name = "site-builder-${domain}";
  runtimeInputs = with pkgs;
    [ git nix ]
    ++ (if site.host == "neocities" then [ neocities-cli ] else [ ]);

  text = ''

    fail() {
      echo "Error: $1" >&2
      exit 1
    }

    # Ensure we're running as the correct user
    if [ "$(id -un)" != "${serviceUser}" ]; then
      fail "This script must be run as ${serviceUser}"
    fi

    # Create necessary directories
    mkdir -p "/var/lib/${serviceUser}/.cache"

    echo "Starting site builder for ${domain}"
    echo "Repository: ${site.gitRepo} (${site.branch})"

    needs_rebuild=0
    old_rev=""

    # Try to use existing repo if it exists and is valid
    if [ -d "${repo_dir}/.git" ]; then
      echo "Found existing repository, attempting to update..."
      cd "${repo_dir}" || fail "Could not change to repository directory"
      old_rev=$(git rev-parse HEAD)
      git fetch origin || fail "Failed to fetch from remote"

      if ! git show-ref --verify --quiet "refs/remotes/origin/${site.branch}"; then
        echo "Branch ${site.branch} not found in remote, checking local..."
        if ! git show-ref --verify --quiet "refs/heads/${site.branch}"; then
          fail "Branch ${site.branch} not found locally or remotely"
        fi
        git checkout "${site.branch}" || fail "Failed to checkout ${site.branch}"
      else
        echo "Using remote branch"
        git reset --hard "origin/${site.branch}" || fail "Failed to reset to ${site.branch}"
      fi
      git clean -fdx
    else
      echo "Cloning fresh repository..."
      rm -rf "${repo_dir}"
      git -c safe.directory='*' clone -b "${site.branch}" "${site.gitRepo}" "${repo_dir}" \
        || fail "Failed to clone repository"
      needs_rebuild=1
    fi

    cd "${repo_dir}" || fail "Could not change to repository directory"

    new_rev=$(git rev-parse HEAD)

    if [ "$old_rev" != "$new_rev" ]; then
      echo "Git revision changed from $old_rev to $new_rev"
      needs_rebuild=1
    fi

    if [ ! -d "${www_dir}" ] || [ -z "$(ls -A "${www_dir}" 2>/dev/null)" ]; then
      echo "Web directory is empty"
      needs_rebuild=1
    fi

    if [ $needs_rebuild -eq 1 ]; then
      echo "Changes detected - rebuilding..."

      source_dir=$(${buildCommand}) || fail "Build failed"

      chmod -R u+w "${www_dir}" || fail "Failed to set write permissions"
      find "${www_dir}" -mindepth 1 -delete || fail "Failed to clean www directory"

      if [ -n "$(ls -A "$source_dir")" ]; then
        cp -r "$source_dir"/* "${www_dir}/" || fail "Failed to copy files"
      else
        files=$(ls "$source_dir") || fail "Source dir doesn't exist"
        fail "Source directory $source_dir is empty: $files"
      fi

      ${deployCommand}

      echo "Site deployment complete (revision: $new_rev)"
    else
      echo "No changes detected, not rebuilding"
    fi
  '';
}
