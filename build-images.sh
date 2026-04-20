#!/bin/bash

#
# Copyright (C) 2023 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

# Terminate on error
set -e

# Prepare variables for later use
images=()
# The image will be pushed to GitHub container registry
repobase="${REPOBASE:-ghcr.io/nethserver}"
# Configure the image name
reponame="checkmk-agent"

# CheckMK server configuration
CHECKMK_SERVER="${CHECKMK_SERVER:-https://monitor.nethlab.it/monitoring}"
CHECKMK_VERSION="${CHECKMK_VERSION:-2.4.0p26}"

# Create container from Rocky Linux 9 minimal
echo "Creating container from Rocky Linux 9..."
container=$(buildah from docker.io/rockylinux:9-minimal)

# Install base packages
echo "Installing base packages..."
buildah run "${container}" microdnf install -y python3 git socat curl

# Download and install CheckMK agent from Nethesis server
echo "Installing CheckMK agent ${CHECKMK_VERSION}..."
buildah run "${container}" sh -c "
    curl -fsSL ${CHECKMK_SERVER}/check_mk/agents/check-mk-agent-${CHECKMK_VERSION}-1.noarch.rpm \
        -o /tmp/check-mk-agent.rpm && \
    rpm -ivh /tmp/check-mk-agent.rpm && \
    rm -f /tmp/check-mk-agent.rpm
"

# Clone checkmk-tools repository and deploy NS8 scripts
echo "Deploying NS8 monitoring scripts..."
buildah run "${container}" sh -c "
    git clone https://github.com/nethesis/checkmk-tools.git /opt/checkmk-tools && \
    mkdir -p /usr/lib/check_mk_agent/local && \
    for script in /opt/checkmk-tools/script-check-ns8/full/*.py; do \
        base=\$(basename \"\$script\" .py); \
        cp \"\$script\" \"/usr/lib/check_mk_agent/local/\$base\"; \
        chmod +x \"/usr/lib/check_mk_agent/local/\$base\"; \
    done
"

# Build UI (NodeJS builder)
if ! buildah containers --format "{{.ContainerName}}" | grep -q nodebuilder-checkmk-agent; then
    echo "Pulling NodeJS runtime..."
    buildah from --name nodebuilder-checkmk-agent -v "${PWD}:/usr/src:Z" docker.io/library/node:24.14.1-slim
fi

echo "Build static UI files with node..."
buildah run \
    --workingdir=/usr/src/ui \
    --env="NODE_OPTIONS=--openssl-legacy-provider" \
    nodebuilder-checkmk-agent \
    sh -c "yarn install && yarn build"

# Add imageroot directory to the container image
buildah add "${container}" imageroot /imageroot
buildah add "${container}" ui/dist /ui

# Configure socat entrypoint for CheckMK agent
buildah run "${container}" sh -c "echo '#!/bin/bash
exec socat TCP-LISTEN:6556,reuseaddr,fork,keepalive EXEC:/usr/sbin/check_mk_agent' > /entrypoint.sh"
buildah run "${container}" chmod +x /entrypoint.sh

# Setup the entrypoint and labels for NS8 rootful container
buildah config --entrypoint=/entrypoint.sh \
    --label="org.nethserver.tcp-ports-demand=1" \
    --label="org.nethserver.rootfull=1" \
    --label="org.nethserver.images=docker.io/rockylinux:9-minimal" \
    "${container}"
# Commit the image
buildah commit "${container}" "${repobase}/${reponame}"

# Append the image URL to the images array
images+=("${repobase}/${reponame}")

#
# NOTICE:
#
# It is possible to build and publish multiple images.
#
# 1. create another buildah container
# 2. add things to it and commit it
# 3. append the image url to the images array
#

#
# Setup CI when pushing to Github. 
# Warning! docker::// protocol expects lowercase letters (,,)
if [[ -n "${CI}" ]]; then
    # Set output value for Github Actions
    printf "images=%s\n" "${images[*],,}" >> "${GITHUB_OUTPUT}"
else
    # Just print info for manual push
    printf "Publish the images with:\n\n"
    for image in "${images[@],,}"; do printf "  buildah push %s docker://%s:%s\n" "${image}" "${image}" "${IMAGETAG:-latest}" ; done
    printf "\n"
fi
