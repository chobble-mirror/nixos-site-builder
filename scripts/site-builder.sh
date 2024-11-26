#!/usr/bin/env bash
set -euo pipefail

# Expected environment variables:
# SITE_DOMAIN - domain of the site (e.g., example.com)
# GIT_REPO - git repository URL

echo "Starting site builder for ${SITE_DOMAIN}"
echo "Git repo: ${GIT_REPO}"

REPO_DIR="/var/tmp/site-builder-${SITE_DOMAIN}"
WORK_DIR=$(mktemp -d)
trap 'rm -rf ${WORK_DIR}' EXIT

needs_rebuild=0
old_rev=""

# Try to use existing repo if it exists and is valid
if [ -d "${REPO_DIR}/.git" ]; then
    echo "Found existing repository, attempting to update..."
    cd "${REPO_DIR}"
    old_rev=$(git rev-parse HEAD)

    if git fetch origin; then
        git reset --hard origin/master
        git clean -fdx
    else
        echo "Update failed, falling back to fresh clone"
        rm -rf "${REPO_DIR}"
        git -c safe.directory='*' clone "${GIT_REPO}" "${REPO_DIR}"
        needs_rebuild=1
    fi
else
    echo "Cloning fresh repository..."
    rm -rf "${REPO_DIR}"
    git -c safe.directory='*' clone "${GIT_REPO}" "${REPO_DIR}"
    needs_rebuild=1
fi

cd "${REPO_DIR}"

# Get new HEAD
new_rev=$(git rev-parse HEAD)

# Check if git revision changed
if [ "$old_rev" != "$new_rev" ]; then
    echo "Git revision changed from $old_rev to $new_rev"
    needs_rebuild=1
fi

# Check if web directory is empty
if [ ! -d "/var/www/${SITE_DOMAIN}" ] || [ -z "$(ls -A "/var/www/${SITE_DOMAIN}" 2>/dev/null)" ]; then
    echo "Web directory is empty"
    needs_rebuild=1
fi

if [ $needs_rebuild -eq 1 ]; then
    echo "Changes detected - rebuilding..."

    # Build the site using nix-build if a default.nix exists
    if [ -f "default.nix" ]; then
        echo "Building with nix-build..."
        latest_build=$(nix-build --no-out-link)

        # Deploy to web directory
        rm -rf "/var/www/${SITE_DOMAIN:?}"/*
        cp -r "${latest_build}"/* "/var/www/${SITE_DOMAIN}/"
    else
        echo "No default.nix found, copying files directly..."
        rm -rf "/var/www/${SITE_DOMAIN:?}"/*
        cp -r [^.]* "/var/www/${SITE_DOMAIN}/"
    fi

    echo "Site deployment complete"
else
    echo "No changes detected, not rebuilding"
fi
