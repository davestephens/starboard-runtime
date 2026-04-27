# starboard-runtime

Runtime distribution for [Starboard](https://github.com/davestephens/starboard) — an Android app that runs PortMaster Linux games on ARM64 handhelds via proot.

This repo hosts the Debian ARM64 rootfs that Starboard downloads and extracts on first launch. The rootfs provides the glibc + SDL2 + Mesa environment that PortMaster ports expect.

## Download

The latest rootfs is published as a GitHub Release asset:

```
https://github.com/davestephens/starboard-runtime/releases/latest/download/starboard-rootfs.tar.gz
```

The Starboard app downloads this automatically on first launch (~130 MB compressed, ~400 MB extracted).

## Contents

- Debian bookworm-slim ARM64 base
- SDL2 family, Python 3, Mesa/OSMesa, OpenAL, common media libs
- Love2D 11.5 runtime
- gmloadernext binary (for GameMaker ports)
- squashfs mount intercept wrapper

See [Dockerfile](Dockerfile) for the full package list and build steps.

## Building locally

Requires Docker with ARM64/QEMU support.

```bash
# Enable ARM64 emulation if needed (one-time)
docker run --privileged --rm tonistiigi/binfmt --install arm64

# Build
bash build-rootfs.sh
```

Output: `rootfs.tar.gz` in the repo root.

## CI

Any push to `main` (except README-only changes) triggers a build. Each successful build creates a new versioned release tagged `starboard-rootfs-YYYYMMDD.N` and marks it as the latest release.
