#!/bin/bash

#
# Copyright (C) 2023 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

set -e
images=()

repobase="${REPOBASE:-ghcr.io/nethserver}"

# Build CheckMK agent runtime image from Containerfile
echo "Building CheckMK agent runtime image..."
podman build -t ${repobase}/checkmk-agent-runtime .
images+=("${repobase}/checkmk-agent-runtime")

#
# Imageroot checkmk-agent
#
container=$(buildah from scratch)
reponame="checkmk-agent"

# Build UI (NodeJS builder)
if ! buildah containers --format "{{.ContainerName}}" | grep -q nodebuilder-checkmk-agent; then
    echo "Pulling NodeJS runtime..."
    buildah from --name nodebuilder-checkmk-agent -v "${PWD}:/usr/src:Z" docker.io/library/node:24-slim
fi

echo "Build static UI files with node..."
buildah run \
    --workingdir=/usr/src/ui \
    --env="NODE_OPTIONS=--openssl-legacy-provider" \
    nodebuilder-checkmk-agent \
    sh -c "yarn install && yarn build"

# Add imageroot and UI to the module image
buildah add "${container}" imageroot /imageroot
buildah add "${container}" ui/dist /ui

# Configure NS8 labels
buildah config \
    --label="org.nethserver.tcp-ports-demand=1" \
    --label="org.nethserver.rootfull=1" \
    --label="org.nethserver.images=${repobase}/checkmk-agent-runtime:${IMAGETAG:-latest}" \
    --entrypoint=/ \
    "${container}"

buildah commit "${container}" "${repobase}/${reponame}"
buildah rm "${container}"
images+=("${repobase}/${reponame}")

#
# Setup CI when pushing to Github
#
if [[ -n "${CI}" ]]; then
    # Set output value for Github Actions
    printf "images=%s\n" "${images[*],,}" >> "${GITHUB_OUTPUT}"
else
    printf "Publish the images with:\n\n"
    for image in "${images[@]}"; do printf "  buildah push %s docker://%s:latest\n" "${image}" "${image}" ; done
    printf "\n"
fi
