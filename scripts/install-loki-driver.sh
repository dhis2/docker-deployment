#!/usr/bin/env bash

set -e

ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH_SUFFIX="amd64"
        ;;
    aarch64|arm64)
        ARCH_SUFFIX="arm64"
        ;;
    *)
        echo "Error: Unsupported architecture: $ARCH"
        echo "Supported architectures: x86_64, aarch64, arm64"
        exit 1
        ;;
esac

LOKI_DRIVER_VERSION="3.3.2"
PLUGIN_NAME="loki"

echo "Installing Docker Loki Driver plugin..."
echo "Architecture: $ARCH_SUFFIX"
echo "Version: $LOKI_DRIVER_VERSION"

if docker plugin ls | grep -q "$PLUGIN_NAME"; then
    echo "Loki driver plugin is already installed. Upgrading..."
    docker plugin disable "$PLUGIN_NAME" --force
    docker plugin upgrade "$PLUGIN_NAME" "grafana/loki-docker-driver:${LOKI_DRIVER_VERSION}-${ARCH_SUFFIX}" --grant-all-permissions
    docker plugin enable "$PLUGIN_NAME"
else
    echo "Installing new Loki driver plugin..."
    docker plugin install "grafana/loki-docker-driver:${LOKI_DRIVER_VERSION}-${ARCH_SUFFIX}" --alias "$PLUGIN_NAME" --grant-all-permissions
fi

echo "Loki driver plugin installed successfully!"
echo ""
echo "To verify the installation, run:"
echo "  docker plugin ls"
echo ""
echo "The plugin should be listed as 'enabled'."
