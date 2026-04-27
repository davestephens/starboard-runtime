#!/usr/bin/env bash
# build-rootfs.sh — Build the Debian ARM64 rootfs for Starboard.
#
# Requires:
#   docker (with binfmt_misc / QEMU for arm64 cross-build on x86_64)
#
# On Fedora, enable ARM64 emulation first if needed:
#   docker run --privileged --rm tonistiigi/binfmt --install arm64
#
# Usage:
#   bash build-rootfs.sh
#
# Output:
#   rootfs.tar.gz

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
DOCKERFILE="$REPO_ROOT/Dockerfile"
IMAGE_TAG="starboard-rootfs:latest"
CONTAINER_NAME="starboard-rootfs-export"
OUTPUT="$REPO_ROOT/rootfs.tar.gz"

log() { echo "==> $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

command -v docker &>/dev/null || die "docker not found"

# Ensure ARM64 emulation is available
if ! docker buildx inspect 2>/dev/null | grep -q linux/arm64 &&
   ! docker run --rm --platform linux/arm64 --entrypoint uname debian:bookworm-slim -m &>/dev/null; then
    log "Enabling ARM64 QEMU emulation..."
    docker run --privileged --rm tonistiigi/binfmt --install arm64
fi

log "Building Debian ARM64 rootfs image..."
docker build \
    --platform linux/arm64 \
    --file "$DOCKERFILE" \
    --tag "$IMAGE_TAG" \
    "$REPO_ROOT"

log "Exporting filesystem..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
docker create --platform linux/arm64 --name "$CONTAINER_NAME" "$IMAGE_TAG"

log "Compressing to $OUTPUT..."
docker export "$CONTAINER_NAME" | gzip -9 > "$OUTPUT"
docker rm "$CONTAINER_NAME"

SIZE=$(du -sh "$OUTPUT" | cut -f1)
log "Done: $OUTPUT ($SIZE)"
