# Linux 安装与分发

[English](linux.en.md) · [返回 README](../../README.md#linux)

从 [GitHub Releases](https://github.com/CyrilPeng/Venera-Next/releases) 下载与机器架构对应的包。`uname -m` 输出 `x86_64` 时选择 x64 / amd64，输出 `aarch64` 时选择 ARM64 / arm64。RPM 和 AppImage 从 [v1.17.0-rc.1](https://github.com/CyrilPeng/Venera-Next/releases/tag/v1.17.0-rc.1) 起提供，两种格式均支持 x86_64 和 ARM64；也可在 GitHub Actions 的“构建”工作流中下载产物。

## 安装

以下 `xxx` 代表下载文件中的实际版本号。

```bash
# Debian / Ubuntu
sudo apt install ./venera-next_xxx_amd64.deb

# Fedora 及提供对应依赖的红帽系发行版
sudo dnf install ./venera-next-xxx.x86_64.rpm

# Arch Linux（目前仅提供 x86_64）
sudo pacman -U ./venera-next-xxx-x86_64.pkg.tar.zst
```

RPM 安装后可从应用菜单或 `venera-next` 命令启动。升级时再次执行 `dnf install ./新版本.rpm`；卸载使用 `sudo dnf remove venera-next`。这些下载包不配置自动更新仓库。

## AppImage

```bash
chmod +x VeneraNext-xxx-linux-x86_64.AppImage
./VeneraNext-xxx-linux-x86_64.AppImage
```

ARM64 使用文件名含 `aarch64` 的版本。无法挂载 FUSE 时，可使用无需 FUSE 的解包运行方式：

```bash
./VeneraNext-xxx-linux-x86_64.AppImage --appimage-extract-and-run
```

AppImage 不需管理员权限，不会自动安装菜单入口；下载新文件替换旧文件即可更新。应用数据仍使用系统用户数据目录，不保存到 AppImage 文件内。

## 系统依赖与兼容范围

所有 Linux 格式目前复用 Ubuntu 22.04 编译的程序，需要兼容的 glibc（基线 2.35）、libstdc++、GTK 3 和 WebKitGTK 4.1。RPM 使用 ELF 依赖检测记录所需符号版本；包管理器会拒绝缺失依赖的安装。

AppImage 携带 Flutter 引擎、应用资源和插件库，但不打包 glibc、GTK 或 WebKitGTK。先安装运行依赖，例如：

```bash
# Ubuntu 22.04 / Debian 等
sudo apt install libgtk-3-0 libwebkit2gtk-4.1-0

# Fedora
sudo dnf install gtk3 webkit2gtk4.1
```

“RPM”不代表兼容所有红帽系系统：RHEL / Rocky / AlmaLinux 9 的 glibc 2.34 低于当前基线，不能保证运行；AppImage 同样不能绕过 glibc 版本限制。请使用提供所需运行库的新发行版，或在目标系统自行编译。

## GitHub Actions 与本地打包

DEB 由 `python3 debian/build.py x64` 或 `python3 debian/build.py arm64` 构建，使用系统 `dpkg-deb`，不再安装 `flutter_to_debian`。先运行 `flutter pub get --enforce-lockfile`；已有对应架构的 Release bundle 时可加 `--skip-build`。输出为 `build/linux/<架构>/release/debian/`。运行依赖、菜单入口和安装路径由脚本维护，保留 `/usr/local/lib/venera-next` 以兼容已有安装；不再修改仓库内的模板文件。质量检查会用两种架构的 ELF 测试数据执行 DEB 打包与解包，这不代替实际平台编译和运行验证。

“构建”工作流的 Linux x64 / ARM64 开关同时控制该架构的 DEB、RPM、AppImage；x64 还生成 Arch 包。完整发布工作流收集两种新格式并上传 Release。工作流产物分别为 `linux_extra_x64` 和 `linux_extra_arm64`。

Linux runner 在现有 Flutter bundle 上运行：

```bash
sudo apt install rpm squashfs-tools desktop-file-utils file
python3 .github/scripts/build_linux_packages.py --arch x64
# ARM64 runner 使用 --arch arm64
```

脚本校验 ELF 架构和 Flutter 资源，生成并检查 RPM，解包生成的 AppImage 检查入口及资源。AppImage 工具固定为 appimagetool 1.9.1、type2-runtime 20251108，并分别校验两个架构的 SHA-256；构建无需 FUSE。产物位于 `build/linux/<架构>/packages/`。
