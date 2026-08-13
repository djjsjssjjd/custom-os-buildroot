# custom-os-buildroot

Custom ARM64 OS built from scratch with **Buildroot 2025.05**, built entirely in
**GitHub Actions**. Base: `qemu_aarch64_virt_defconfig` with a fully resolved custom
defconfig — **`make olddefconfig` is never used, anywhere in the pipeline.**

## Why there's no `olddefconfig`

`olddefconfig` is only needed when you hand-edit `.config` and leave dependencies
unresolved. This repo instead ships `configs/custom_os_defconfig`, a defconfig whose
dependencies were resolved and verified against a real Buildroot 2025.05 tree. When
`make <defconfig>` loads it, kconfig expands all defaults and `select` chains itself.
Verified end-to-end: fresh clean-tree load → every package below `=y`, zero legacy
symbols, byte-identical savedefconfig round-trip.

## What's in the image

| Category | Packages |
|---|---|
| **Desktop** | X11R7 (Xorg modular server), **Openbox**, xinit/startx, xterm, PCManFM file manager, Dillo browser, feh, ImageMagick, xdotool, xrandr, xcalc, xeyes, xclock, xprop, xwininfo, xinput, xsetroot, twm, X cursor themes |
| **X drivers/fonts** | xf86-video-fbdev + vesa (virtio-gpu), xf86-input-evdev; misc-misc + adobe-100dpi bitmap fonts, DejaVu, Liberation |
| **Package manager** | opkg |
| **Shells/core** | bash, zsh, coreutils, util-linux, procps-ng, gawk, GNU grep/sed, findutils, diffutils, patch, less, tree, which, file, tar, sudo, dcron, mc, screen, tmux |
| **Editors/monitors** | nano, vim, htop, ncdu |
| **Development** | make, cmake, git, gdb (+gdbserver), strace, ltrace, valgrind, binutils, jq, python3, perl, lua, sqlite |
| **Networking** | openssh, curl, wget, wireguard-tools (kernel WireGuard enabled), openvpn, nmap, iperf3, tcpdump, socat, iproute2, iputils, ethtool, bridge-utils, iw, wpa_supplicant, dnsmasq, iptables, nftables, rsync, pciutils, usbutils |
| **Crypto/compression** | gnupg2, ca-certificates, zip, unzip, p7zip, xz, lz4, zstd |
| **Filesystems** | e2fsprogs, dosfstools, parted |
| **Audio** | alsa-utils, mpg123 |
| **System** | eudev (dynamic /dev), dbus, ccache (build accel), ext2 rootfs sized at **1024M** |

Notes:
- **dropbear was removed** — it collided with openssh on port 22 at boot (S50dropbear
  won the bind, sshd failed every boot). openssh stays.
- Kernel 6.12.27 with config fragments adding `CONFIG_DRM_FBDEV_EMULATION=y` (X gets
  `/dev/fb0` on virtio-gpu) and `CONFIG_WIREGUARD=y` (so wireguard-tools actually works).

Root password: `root`. On console login with a display present (`/dev/fb0`),
X + Openbox auto-start via `startx`. Openbox theme: **CyberDark** (dark, neon-purple
accents) shipped in the overlay.

## Repo layout (BR2_EXTERNAL tree)

```
external.desc / external.mk / Config.in   # external tree glue
configs/custom_os_defconfig               # the whole OS, fully resolved
kernel/virtio-gpu.fragment                # fbdev-on-DRM + WireGuard
overlay/
  etc/X11/xorg.conf.d/10-virtio-gpu.conf  # force fbdev driver
  etc/xdg/openbox/{rc.xml,menu.xml,autostart}
  etc/profile.d/x11-autostart.sh          # startx on console login (if /dev/fb0)
  etc/opkg/opkg.conf                      # feed skeleton
  root/.xinitrc                           # openbox-session → openbox → twm fallback
  usr/share/themes/CyberDark/             # openbox theme
.github/workflows/build.yml
```

## Local build (same commands as CI)

```bash
wget https://buildroot.org/downloads/buildroot-2025.05.tar.gz
tar xzf buildroot-2025.05.tar.gz && cd buildroot-2025.05
make O=$PWD/../br-out BR2_EXTERNAL=/path/to/custom-os-buildroot custom_os_defconfig
make -C ../br-out -j$(nproc)
```

Artifacts land in `br-out/images/`: `Image`, `rootfs.ext2`, `rootfs.cpio.gz`, `rootfs.tar`.

## Run it

```bash
qemu-system-aarch64 -M virt -cpu cortex-a53 -m 1024 \
  -device virtio-gpu-pci -device virtio-keyboard -device virtio-mouse \
  -kernel br-out/images/Image -append "root=/dev/vda console=ttyAMA0" \
  -drive file=br-out/images/rootfs.ext2,if=virtio,format=raw
```

Log in as `root` / `root` — Openbox starts automatically when a display is present.
`rootfs.tar` is also produced for loop-mount-free extraction (mobile-friendly).

## CI

Push to `main` or hit **Actions → Build Custom OS → Run workflow** in the web UI.
The workflow: installs host deps → downloads + caches Buildroot source, the `dl/`
tarball cache and ccache (build tree deliberately uncached — Buildroot doesn't
track overlay contents as make deps, so a cached `output/` would serve stale
rootfs images) → applies the defconfig out-of-tree (no olddefconfig) → verifies
~20 key symbols + no legacy symbols + dropbear disabled → builds → boot-smoke-tests
the kernel in QEMU to the login prompt → xz-compresses the ext2 image → uploads
artifacts (build fails loudly if any artifact is missing).
