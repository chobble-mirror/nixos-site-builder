#!/usr/bin/env bash
set -euo pipefail

# Expected environment variables:
# SITE_DOMAIN - domain of the site (e.g., example.com)
# GIT_REPO - git repository URL

# Convert domain to service user name
SANITIZED_DOMAIN=$(echo "${SITE_DOMAIN}" | tr '.' '-')
SERVICE_USER="${SANITIZED_DOMAIN}-builder"

# Ensure we're running as the correct user
if [ "$(id -un)" != "${SERVICE_USER}" ]; then
  echo "This script must be run as ${SERVICE_USER}"
  exit 1
fi

echo "Starting site builder for ${SITE_DOMAIN}"
echo "Git repo: ${GIT_REPO}"

REPO_DIR="/var/lib/${SERVICE_USER}/site-builder-${SITE_DOMAIN}"

needs_rebuild=0
old_rev=""

# Try to use existing repo if it exists and is valid
if [ -d "${REPO_DIR}/.git" ]; then
  echo "Found existing repository, attempting to update..."
  cd "${REPO_DIR}"
  old_rev=$(git rev-parse HEAD)
  git reset --hard origin/master
  git clean -fdx
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

  chmod -R u+w "/var/www/${SITE_DOMAIN:?}"
  rm -rf "/var/www/${SITE_DOMAIN:?}"/*

  # Build the site using nix-build if a default.nix exists
  if [ -f "default.nix" ]; then
    echo "Building with nix-build..."
    latest_build=$(nix-build --no-out-link)
    cp -r "${latest_build}"/* "/var/www/${SITE_DOMAIN}/"
  else
    echo "No default.nix found, copying files directly..."
    cp -r [^.]* "/var/www/${SITE_DOMAIN}/"
  fi

  echo "Site deployment complete"
else
  echo "No changes detected, not rebuilding"
fi
