#!/usr/bin/env bash
set -euo pipefail

# Expected environment variables:
# SITE_DOMAIN - domain of the site (e.g., example.com)
# GIT_REPO - git repository URL

# Debug output
echo "Starting site builder for ${SITE_DOMAIN}"
echo "Git repo: ${GIT_REPO}"

# Create working directory
WORK_DIR=$(mktemp -d)
trap 'rm -rf ${WORK_DIR}' EXIT

# Store current HEAD if it exists
old_rev=""
if [ -d "/var/lib/site-builder/${SITE_DOMAIN}/repo/.git" ]; then
    cd "/var/lib/site-builder/${SITE_DOMAIN}/repo"
    old_rev=$(git rev-parse HEAD)

    # Update repo
    echo "Updating existing repository..."
    git fetch origin
    git reset --hard origin/master
    git clean -fdx
else
    # Fresh clone with safe directory settings
    echo "Cloning repository..."
    mkdir -p "/var/lib/site-builder/${SITE_DOMAIN}"
    rm -rf "/var/lib/site-builder/${SITE_DOMAIN}/repo"
    git -c safe.directory='*' clone "${GIT_REPO}" "/var/lib/site-builder/${SITE_DOMAIN}/repo"
    cd "/var/lib/site-builder/${SITE_DOMAIN}/repo"
fi

# Get new HEAD
new_rev=$(git rev-parse HEAD)

needs_rebuild=0

# Check if rebuild is needed
if [ "$old_rev" != "$new_rev" ]; then
    echo "Git revision changed from $old_rev to $new_rev"
    needs_rebuild=1
fi

if [ ! -d "/var/www/${SITE_DOMAIN}" ] || [ -z "$(ls -A "/var/www/${SITE_DOMAIN}" 2>/dev/null)" ]; then
    echo "Web directory is empty"
    needs_rebuild=1
fi

if [ $needs_rebuild -eq 1 ]; then
    echo "Changes detected - rebuilding..."
    export HOME="/var/lib/site-builder/${SITE_DOMAIN}"

    # Build the site using nix-build if a default.nix exists
    if [ -f "default.nix" ]; then
        echo "Building with nix-build..."
        latest_build=$(nix-build --no-out-link)

        # Clear the existing site and copy the new one
        rm -rf "/var/www/${SITE_DOMAIN:?}"/*
        cp -r "${latest_build}"/* "/var/www/${SITE_DOMAIN}/"
    else
        echo "No default.nix found, copying files directly..."
        # Clear the existing site
        rm -rf "/var/www/${SITE_DOMAIN:?}"/*
        # Only copy visible files and directories, excluding .git
        cp -r [^.]* "/var/www/${SITE_DOMAIN}/"
    fi

    echo "Site deployment complete"
else
    echo "No changes detected, not rebuilding"
fi
