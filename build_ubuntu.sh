#!/bin/bash
set -euo pipefail

# Upstream Linux architectures for headscale (https://github.com/juanfont/headscale):
#   amd64  -> headscale_<version>_linux_amd64
#   arm64  -> headscale_<version>_linux_arm64
#
# amd64 and arm64 only (upstream also publishes its own .deb for these two architectures).
# TODO: implement headscale build

headscale_VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}  # Default to amd64 if no architecture specified

if [ -z "$headscale_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <headscale_version> <build_version> [architecture]"
    echo "Example: $0 1.2.3 1 arm64"
    echo "Example: $0 1.2.3 1 all    # Build for all architectures"
    echo "Supported architectures: amd64, arm64, all"
    exit 1
fi

echo "build_ubuntu.sh for headscale is not implemented yet."
exit 1
