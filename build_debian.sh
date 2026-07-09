#!/bin/bash
set -euo pipefail

# Upstream Linux architectures for headscale (https://github.com/juanfont/headscale):
#   amd64  -> headscale_<version>_linux_amd64
#   arm64  -> headscale_<version>_linux_arm64
#
# amd64 and arm64 only (upstream also publishes its own .deb for these two architectures).

headscale_VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}  # Default to amd64 if no architecture specified

if [ -z "$headscale_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <headscale_version> <build_version> [architecture]"
    echo "Example: $0 0.29.2 1 arm64"
    echo "Example: $0 0.29.2 1 all    # Build for all architectures"
    echo "Supported architectures: amd64, arm64, all"
    exit 1
fi

# Returns the headscale release asset suffix for a given Debian architecture
get_headscale_release() {
    local arch=$1
    case "$arch" in
        "amd64") echo "linux_amd64" ;;
        "arm64") echo "linux_arm64" ;;
        *)       echo "" ;;
    esac
}

# Downloads the headscale binary for the given arch into a local directory
download_binary() {
    local build_arch=$1
    local release_suffix

    release_suffix=$(get_headscale_release "$build_arch")
    if [ -z "$release_suffix" ]; then
        echo "❌ Unsupported architecture: $build_arch"
        echo "Supported architectures: amd64, arm64"
        return 1
    fi

    if [ -f "$build_arch/headscale" ]; then
        echo "  Binary for $build_arch already downloaded, skipping."
        return 0
    fi

    mkdir -p "$build_arch"

    local url="https://github.com/juanfont/headscale/releases/download/v${headscale_VERSION}/headscale_${headscale_VERSION}_${release_suffix}"
    echo "  Downloading $url"
    if ! wget -q -O "$build_arch/headscale" "$url"; then
        echo "❌ Failed to download headscale binary for $build_arch"
        rm -f "$build_arch/headscale"
        return 1
    fi
    chmod +x "$build_arch/headscale"
}

# Function to build for a specific architecture
build_architecture() {
    local build_arch=$1

    echo "Building Debian packages for architecture: $build_arch"

    if ! download_binary "$build_arch"; then
        return 1
    fi

    declare -a arr=("bookworm" "trixie" "forky" "sid")

    for dist in "${arr[@]}"; do
        FULL_VERSION="$headscale_VERSION-${BUILD_VERSION}+${dist}_${build_arch}"
        echo "  Building $FULL_VERSION"

        if ! docker build . -t "headscale-$dist-$build_arch" \
            --build-arg DEBIAN_DIST="$dist" \
            --build-arg headscale_VERSION="$headscale_VERSION" \
            --build-arg BUILD_VERSION="$BUILD_VERSION" \
            --build-arg FULL_VERSION="$FULL_VERSION" \
            --build-arg ARCH="$build_arch" \
            --build-arg HEADSCALE_RELEASE="$build_arch"; then
            echo "❌ Failed to build Docker image for $dist on $build_arch"
            return 1
        fi

        id="$(docker create "headscale-$dist-$build_arch")"
        if ! docker cp "$id:/headscale_$FULL_VERSION.deb" - > "./headscale_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb package for $dist on $build_arch"
            return 1
        fi

        if ! tar -xf "./headscale_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb contents for $dist on $build_arch"
            return 1
        fi
    done

    echo "✅ Successfully built Debian packages for $build_arch"
    return 0
}

# Main build logic
if [ "$ARCH" = "all" ]; then
    echo "🚀 Building headscale $headscale_VERSION-$BUILD_VERSION for all supported architectures (Debian)..."
    echo ""

    ARCHITECTURES=("amd64" "arm64")

    for build_arch in "${ARCHITECTURES[@]}"; do
        echo "==========================================="
        echo "Building for architecture: $build_arch"
        echo "==========================================="

        if ! build_architecture "$build_arch"; then
            echo "❌ Failed to build for $build_arch"
            exit 1
        fi

        echo ""
    done

    echo "🎉 All Debian packages built successfully!"
    echo "Generated packages:"
    ls -la headscale_*.deb
else
    if ! build_architecture "$ARCH"; then
        exit 1
    fi
fi
