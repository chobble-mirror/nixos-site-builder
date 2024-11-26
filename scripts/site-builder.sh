
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

# Clone repository with safe directory settings
echo "Cloning repository..."
git -c safe.directory='*' clone "${GIT_REPO}" "${WORK_DIR}/site"
cd "${WORK_DIR}/site"

# Build site (this is where you'd run your static site generator if needed)
echo "Building site..."

# Deploy to web directory
echo "Deploying to /var/www/${SITE_DOMAIN}/"
rm -rf "/var/www/${SITE_DOMAIN:?}/"*
# Only copy visible files and directories, excluding .git
cp -r [^.]* "/var/www/${SITE_DOMAIN}/"

echo "Site deployment complete"
