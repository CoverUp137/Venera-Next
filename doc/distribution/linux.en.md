# Linux installation and distribution

[简体中文](linux.zh.md) · [README](../../README.en.md#linux)

Choose a release asset matching `uname -m`: `x86_64` corresponds to x64 / amd64; `aarch64` corresponds to ARM64 / arm64. RPM and AppImage are available starting with the release containing this change, and as artifacts of the **构建** (Build) Actions workflow.

## Installation

DEB builds use `python3 debian/build.py x64` or `python3 debian/build.py arm64` and the system `dpkg-deb`, without installing `flutter_to_debian`. First run `flutter pub get --enforce-lockfile`. Add `--skip-build` to package an existing release bundle. Output is `build/linux/<arch>/release/debian/`. The script owns dependencies, desktop entries, and the existing `/usr/local/lib/venera-next` installation path; it does not modify repository templates. Quality checks build and extract DEBs with ELF fixtures for both architectures; these checks do not replace real platform compilation or runtime tests.

Replace `xxx` with the version in the downloaded filename.

```bash
# Debian / Ubuntu
sudo apt install ./venera-next_xxx_amd64.deb
# Fedora and compatible RPM distributions
sudo dnf install ./venera-next-xxx.x86_64.rpm
# Arch Linux (x86_64 only)
sudo pacman -U ./venera-next-xxx-x86_64.pkg.tar.zst
```

Start the RPM installation from the application menu or `venera-next`. Install a newer RPM using the same command; uninstall with `sudo dnf remove venera-next`. These packages do not configure an update repository.

## AppImage

```bash
chmod +x VeneraNext-xxx-linux-x86_64.AppImage
./VeneraNext-xxx-linux-x86_64.AppImage
# Run without FUSE when mounting is unavailable:
./VeneraNext-xxx-linux-x86_64.AppImage --appimage-extract-and-run
```

Use the `aarch64` asset for ARM64. No administrator permission is needed. Menu integration is not installed automatically. Replace the file to upgrade; application data remains in your system user data directory.

## Compatibility and dependencies

Linux packages share a binary compiled on Ubuntu 22.04, requiring compatible glibc (baseline 2.35), libstdc++, GTK 3, and WebKitGTK 4.1. RPM records system ELF symbol requirements automatically. AppImage includes Flutter and application/plugin libraries, but does not bundle glibc, GTK or WebKitGTK. Install host dependencies first:

```bash
sudo apt install libgtk-3-0 libwebkit2gtk-4.1-0  # Ubuntu / Debian
sudo dnf install gtk3 webkit2gtk4.1             # Fedora
```

RPM does not imply compatibility with every Red Hat family distribution. RHEL / Rocky / AlmaLinux 9 use glibc 2.34, below this baseline; AppImage cannot bypass this requirement either. Use a newer distribution with the required libraries, or compile on the target system.

## GitHub Actions and packaging

The Linux x64 / ARM64 switches in **构建** build DEB, RPM and AppImage for the selected architecture; x64 also builds Arch packages. The release workflow collects these assets. The additional workflow artifacts are named `linux_extra_x64` and `linux_extra_arm64`.

After building the Flutter bundle on a Linux runner:

```bash
sudo apt install rpm squashfs-tools desktop-file-utils file
python3 .github/scripts/build_linux_packages.py --arch x64
# Use --arch arm64 on an ARM64 runner.
```

The script checks ELF architecture and Flutter resources, builds and inspects the RPM, and extracts the resulting AppImage to verify its entry point and resources. Both architectures use SHA-256-verified appimagetool 1.9.1 and type2-runtime 20251108. Packaging does not require FUSE. Outputs are in `build/linux/<architecture>/packages/`.
