# Starboard Linux runtime rootfs — Debian bookworm-slim ARM64
#
# Provides the glibc + SDL2 environment that PortMaster ports expect.
# Built for arm64/v8a; extracted by the app on first launch via EngineSetupRepository.
#
# Build + export:
#   bash scripts/build-rootfs.sh

# ---------------------------------------------------------------------------
# Stage 1: build libjpeg-turbo with JPEG 8 ABI
#
# Many PortMaster ports link against libjpeg.so.8 and require LIBJPEG_8.0
# versioned symbols.  Debian only ships the 6.2 ABI (libjpeg62-turbo); the
# 8-ABI variant must be compiled explicitly with -DWITH_JPEG8=1.
# ---------------------------------------------------------------------------
FROM --platform=linux/arm64 debian:bookworm-slim AS libjpeg8-builder

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        cmake build-essential nasm wget ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Same source version as Debian Bookworm's libjpeg62-turbo (2.1.5).
RUN wget -q https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/2.1.5.1/libjpeg-turbo-2.1.5.1.tar.gz && \
    tar xzf libjpeg-turbo-2.1.5.1.tar.gz && \
    cmake -S libjpeg-turbo-2.1.5.1 -B /build \
        -DWITH_JPEG8=1 \
        -DCMAKE_BUILD_TYPE=MinSizeRel \
        -DENABLE_STATIC=FALSE && \
    cmake --build /build -j$(nproc)

# ---------------------------------------------------------------------------
# Stage 2: main rootfs
# ---------------------------------------------------------------------------
FROM --platform=linux/arm64 debian:bookworm-slim

# Core runtime packages that cover the vast majority of PortMaster ports:
#   - SDL2 and companion libs  (video/audio/input)
#   - Python 3                 (Python-based ports)
#   - Common media/image libs  (ogg, vorbis, opus, mpg123, flac, png, jpeg)
#   - Mesa GL software renderer (OpenGL ports via SDL_VIDEO_DRIVER=offscreen)
#   - curl                     (some ports self-update or fetch assets)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libsdl2-2.0-0 \
        libsdl2-image-2.0-0 \
        libsdl2-mixer-2.0-0 \
        libsdl2-ttf-2.0-0 \
        libsdl2-net-2.0-0 \
        libsdl1.2debian \
        python3 \
        python3-sdl2 \
        libogg0 \
        libvorbis0a \
        libopusfile0 \
        libflac12 \
        libmpg123-0 \
        libpng16-16 \
        libjpeg62-turbo \
        zlib1g \
        libopenal1 \
        libsndfile1 \
        libwebp7 \
        libtheora0 \
        libfontconfig1 \
        libcairo2 \
        curl \
        ca-certificates \
        unzip \
        libgl1 \
        libegl1 \
        libegl-mesa0 \
        libgl1-mesa-dri \
        libgles2 \
        libosmesa6 \
        squashfs-tools \
        7zip \
        xdelta3 \
        zip \
        libevdev2 \
        procps \
        binutils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install the JPEG 8 ABI library built above.
# libjpeg62-turbo (above) provides libjpeg.so.62 / LIBJPEG_6.2.
# This adds libjpeg.so.8 / LIBJPEG_8.0 for ports that require it.
COPY --from=libjpeg8-builder /build/libjpeg.so.8* /usr/lib/aarch64-linux-gnu/
RUN ldconfig && \
    ln -sf /usr/lib/aarch64-linux-gnu/dri /usr/lib/dri && \
    ln -sf libOSMesa.so.8 /usr/lib/aarch64-linux-gnu/libGLESv1_CM.so.1 && \
    ln -sf libGLESv1_CM.so.1 /usr/lib/aarch64-linux-gnu/libGLESv1_CM.so && \
    ln -sf libdrm.so.2 /usr/lib/aarch64-linux-gnu/libdrm.so && \
    ln -sf libEGL.so.1 /usr/lib/aarch64-linux-gnu/libEGL.so

# Packages not in bookworm pulled from adjacent Debian releases.
# Each block adds the repo at a specific priority, installs only what's needed,
# then removes the repo so subsequent apt commands stay on bookworm.

# Debian 11 (bullseye) — packages removed or replaced in bookworm:
#   libssl1.1 / libcrypto.so.1.1  — bookworm ships OpenSSL 3 only
#   FFmpeg 4.x / libavcodec.so.58 — bookworm ships FFmpeg 5.x (.so.59)
#   libflac8                       — bookworm ships libflac12
#   libzip4 / libzip.so.4          — bookworm ships libzip5 only; newer gmloadernext.aarch64
#                                    links against libzip.so.4
RUN echo 'deb [arch=arm64] https://archive.debian.org/debian bullseye main' \
        > /etc/apt/sources.list.d/bullseye.list && \
    printf 'Package: *\nPin: release n=bullseye\nPin-Priority: 100\n' \
        > /etc/apt/preferences.d/bullseye && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libssl1.1 \
        libzip4 \
        libavcodec58 libavformat58 libavutil56 libswresample3 libswscale5 \
        libflac8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    rm /etc/apt/sources.list.d/bullseye.list /etc/apt/preferences.d/bullseye

# Debian 13 (trixie) — OpenSSL 3.3.x upgrades bookworm's 3.0.x in-place.
# Same SONAME (libssl.so.3 / libcrypto.so.3); 3.3.x adds OPENSSL_3.1.0,
# OPENSSL_3.2.0, OPENSSL_3.3.0 versioned symbols that some bundled port libs
# (e.g. minetest's libcurl.so.4) require. Fully backwards-compatible with
# anything compiled against 3.0.x.
# trixie packages may carry a t64 suffix (64-bit time_t ABI transition).
RUN echo 'deb [arch=arm64] http://deb.debian.org/debian trixie main' \
        > /etc/apt/sources.list.d/trixie.list && \
    printf 'Package: *\nPin: release n=trixie\nPin-Priority: 100\n' \
        > /etc/apt/preferences.d/trixie && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        -t trixie libssl3t64 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    rm /etc/apt/sources.list.d/trixie.list /etc/apt/preferences.d/trixie

# Create directories that proot bind-mounts into.
# These must exist as directories in the guest rootfs before proot starts.
#   /home/user/port  — launcher script path (bind target for portDir)
#   /roms/ports      — PortMaster convention: GAMEDIR="/$directory/ports/<name>"
#                      with directory="roms"; portDir is also bound here
#   /tmp/sb          — IPC files (fb, input.sock, game.log)
#   /opt/sb          — nativeLibDir (libSDL2_starboard.so, libproot_loader.so, etc.)
RUN mkdir -p /home/user/port /roms/ports /tmp/sb /opt/sb

# Mesa-virgl client payload for the experimental hardware-GPU mode.
# When the user toggles "Run on GPU" in the launcher, this directory is
# preferred over the OSMesa software path via LD_LIBRARY_PATH ordering
# (see launcher.sh template in app/src/main/cpp/game_bridge.cpp).
#   /opt/sb-virgl/dri  — Mesa virtio_gpu DRI driver + swrast bootstrap drivers
#   /opt/sb-virgl/lib  — libGL/libEGL/libGLES* + their transitive deps (libdrm, llvm)
#   /opt/sb-virgl/bin  — eglinfo / es2_info diagnostics
# Source = stock Debian Mesa 22.3.6, same version used to build virglrenderer_sb,
# so wire-protocol matches across the vtest socket.
RUN mkdir -p /opt/sb-virgl/dri /opt/sb-virgl/lib /opt/sb-virgl/bin && \
    cp -L /usr/lib/aarch64-linux-gnu/dri/virtio_gpu_dri.so /opt/sb-virgl/dri/ && \
    cp -L /usr/lib/aarch64-linux-gnu/dri/swrast_dri.so /opt/sb-virgl/dri/ && \
    cp -L /usr/lib/aarch64-linux-gnu/dri/kms_swrast_dri.so /opt/sb-virgl/dri/ && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libllvm15 libdrm-amdgpu1 libdrm-radeon1 libdrm-nouveau2 mesa-utils-bin \
    && for lib in libGL.so.1 libGLX.so.0 libGLdispatch.so.0 libGLX_mesa.so.0 \
                  libEGL.so.1 libEGL_mesa.so.0 libgbm.so.1 libglapi.so.0 \
                  libdrm.so.2 libdrm_amdgpu.so.1 libdrm_radeon.so.1 libdrm_nouveau.so.2 \
                  libLLVM-15.so.1 libzstd.so.1 libelf.so.1 libsensors.so.5 libxml2.so.2 \
                  libGLESv2.so.2 libGLESv1_CM.so.1; do \
        src=$(find /usr/lib/aarch64-linux-gnu -maxdepth 2 -name "$lib" 2>/dev/null | head -1); \
        if [ -n "$src" ]; then cp -L "$src" /opt/sb-virgl/lib/; \
        else echo "WARN: $lib not found" >&2; fi; \
    done && \
    cp -L /usr/bin/es2_info.aarch64-linux-gnu /opt/sb-virgl/bin/es2_info && \
    cp -L /usr/bin/eglinfo.aarch64-linux-gnu /opt/sb-virgl/bin/eglinfo && \
    chmod +x /opt/sb-virgl/bin/* && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    du -sh /opt/sb-virgl

# PortMaster expects this file to exist so port scripts can source it for GL settings.
RUN mkdir -p /opt/system/Tools/PortMaster && \
    printf 'export LIBGL_ALWAYS_SOFTWARE=1\nexport GALLIUM_DRIVER=llvmpipe\n' \
        > /opt/system/Tools/PortMaster/libgl_default.txt && \
    ln -sf /usr/bin/7zz /opt/system/Tools/PortMaster/7zzs.aarch64

# Love2D 11.5 runtime — pre-built binary + libs copied from scripts/runtimes/love_11.5.
#   $controlfolder resolves to /opt/system/Tools/PortMaster on Starboard (matched by
#   the if-block in PortMaster launchers that checks this path first).
COPY runtimes/love_11.5/ /opt/system/Tools/PortMaster/runtimes/love_11.5/
RUN chmod +x /opt/system/Tools/PortMaster/runtimes/love_11.5/love.aarch64

# gmloadernext.aarch64 — newer GMLoader-Next binary bundled for patching old ports.
# Some ports ship a legacy 'gmloadernext' binary (no .aarch64 suffix) that uses
# Android JNI audio and produces no sound outside Android.  game_bridge.cpp detects
# and replaces those binaries with this one at each launch.
RUN mkdir -p /usr/local/lib/starboard
COPY runtimes/gmloadernext/gmloadernext.aarch64 /usr/local/lib/starboard/gmloadernext.aarch64
RUN chmod +x /usr/local/lib/starboard/gmloadernext.aarch64

# mount/umount wrappers: proot cannot perform real kernel mounts so we intercept
# them here.  squashfs mounts are replaced by unsquashfs extraction (idempotent
# — already-extracted directories are skipped on re-run).  All other mounts
# silently succeed so port scripts that test the exit code don't abort.
COPY rootfs-mount-wrapper.sh /usr/local/bin/mount
RUN chmod +x /usr/local/bin/mount
RUN printf '#!/bin/bash\nexit 0\n' > /usr/local/bin/umount && chmod +x /usr/local/bin/umount
