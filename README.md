# OpenCode Portable 🚀

<p align="center">
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20Linux-111827?style=for-the-badge" alt="Platforms">
  <img src="https://img.shields.io/badge/architecture-x64%20%7C%20ARM64-111827?style=for-the-badge" alt="Architecture">
  <img src="https://img.shields.io/badge/runtime-Portable%20Node.js-111827?style=for-the-badge" alt="Portable Node.js">
  <img src="https://img.shields.io/badge/license-MIT-111827?style=for-the-badge" alt="MIT License">
</p>

<p align="center"><strong>Carry your OpenCode environment on a USB drive.</strong></p>
<p align="center">An unofficial portable distribution for Windows and Linux with a USB-local runtime, application, configuration, cache, and temporary workspace.</p>

<p align="center">
  <img src="docs/architecture.svg" alt="OpenCode Portable architecture" width="900">
</p>

> ⚠️ **Unofficial project.** This repository is not affiliated with or endorsed by the upstream OpenCode project.

## ✨ Highlights

- 🔌 **USB portable** — run from a removable drive without a normal system installation.
- 🧰 **Private Node.js runtime** — the launcher manages its own Node.js runtime on the drive.
- 🖥️ **Windows + Linux** — x64 and ARM64 detection.
- 🐧 **glibc + musl Linux** — automatically selects the matching Linux package/runtime where an official portable runtime exists.
- 🔐 **Integrity verification** — Node.js downloads are checked against the official SHA-256 manifest; OpenCode packages are checked against npm registry SRI.
- 📦 **Native OpenCode binary** — the launcher calls the platform binary directly instead of relying on npm's generated `.bin` shim.
- 🗂️ **USB-local data** — configuration, sessions, cache, npm cache, and temporary files are redirected to the portable directory.
- 📌 **Version pinning** — set `OPENCODE_VERSION` when you need a reproducible OpenCode version.
- 🧹 **No installer required** — no administrator/root installation is needed by the launcher itself.

## ⚡ Quick Start

### Windows

1. Copy `OpenCode-Portable/` to an exFAT or another writable USB filesystem.
2. Connect the drive.
3. Double-click `OpenCode-Portable\opencode.bat`.
4. On first launch, the launcher downloads the correct Node.js runtime and OpenCode package to the drive.

Or from Command Prompt:

```bat
E:
cd E:\OpenCode-Portable
opencode.bat
```

### Linux

```bash
cd /media/$USER/OPENCODE/OpenCode-Portable
chmod +x opencode.sh
./opencode.sh
```

The first run requires internet access. Once the runtime and application are present, subsequent launches use the USB-local copies.

## 🧱 Architecture

```text
OpenCode-Portable/
├── opencode.bat                 # Windows launcher
├── opencode.sh                  # Linux launcher
├── engine/
│   ├── node-win/                # Windows portable Node.js
│   ├── node-linux-glibc/        # Linux glibc Node.js
│   └── node-linux-musl/         # Linux x64 musl Node.js
├── opt/
│   ├── opencode-win/            # Windows OpenCode package
│   ├── opencode-linux-glibc/    # Linux glibc OpenCode package
│   └── opencode-linux-musl/     # Linux x64 musl OpenCode package
└── data/
    ├── win/                     # Windows config/cache/temp
    └── linux/                   # Linux config/cache/temp
```

<p align="center"><img src="docs/architecture.svg" alt="Detailed architecture diagram" width="900"></p>

### Runtime isolation

The launchers do not require a host-installed Node.js. Runtime files are stored under `engine/` on the USB drive.

### Application isolation

OpenCode is installed under `opt/` using the platform-specific native package. The launcher resolves the native executable directly and does not intentionally invoke an OpenCode installation from the host `PATH`.

### Data isolation

The launchers redirect relevant environment variables to `data/`, including:

- `HOME` / `USERPROFILE`
- `APPDATA` / `LOCALAPPDATA` on Windows
- `XDG_CONFIG_HOME`
- `XDG_DATA_HOME`
- `XDG_CACHE_HOME`
- `XDG_STATE_HOME`
- `OPENCODE_CONFIG_DIR`
- `TEMP` / `TMP` / `TMPDIR`
- npm cache

These variables are process-scoped and are not persisted as system environment variables by the launcher.

## 🖥️ Compatibility

| Platform | CPU | libc/runtime | Status |
|---|---|---|---|
| Windows 10+ | x64 | Windows | ✅ Supported |
| Windows 10+ | ARM64 | Windows | ✅ Supported where the native package is available |
| Linux | x64 | glibc | ✅ Supported |
| Linux | ARM64 | glibc | ✅ Supported |
| Linux | x64 | musl | ✅ Supported when the corresponding upstream packages are available |
| Linux | ARM64 | musl | ❌ Not supported by the official portable Node.js runtime |

### Linux `noexec`

Some removable drives are mounted with `noexec`. In that case Linux will refuse to execute Node.js/OpenCode from the drive.

Check the mount options:

```bash
findmnt -no OPTIONS /media/$USER/OPENCODE
```

If `noexec` is present, remount the filesystem with execution enabled if your system policy allows it:

```bash
sudo mount -o remount,exec /media/$USER/OPENCODE
```

For a Linux-only portable setup, an executable Linux filesystem such as ext4 may be more appropriate than exFAT.

## 🔐 Security & Integrity

The installer treats downloaded artifacts as untrusted until verification succeeds.

### Node.js

1. Resolve a Node.js release from `nodejs.org`.
2. Download the matching archive.
3. Download the official `SHASUMS256.txt` manifest.
4. Require the matching filename/checksum entry.
5. Compare SHA-256 before extraction.

A missing manifest, missing checksum, download error, or checksum mismatch causes installation to stop.

### OpenCode

1. Resolve the platform-specific package from the npm registry.
2. Read its published `dist.integrity` value.
3. Verify the cached/downloaded tarball using the declared SHA-512/SHA-256 SRI value.
4. Only then install the package locally.

A corrupted cached tarball is discarded and downloaded again.

## 📌 Reproducible Versions

By default the launcher follows the current OpenCode `latest` package. For a reproducible deployment, pin the version explicitly:

### Linux

```bash
OPENCODE_VERSION=YOUR_VERSION ./opencode.sh
```

### Windows

```bat
set OPENCODE_VERSION=YOUR_VERSION
opencode.bat
```

For a truly reproducible USB image, also keep the Node.js runtime already provisioned on the drive rather than resolving a new LTS release during installation.

## 🌐 Network Requirements

**First run:** internet access is required to obtain Node.js and OpenCode unless those artifacts are already provisioned on the drive.

**Subsequent runs:** no download is performed while the required runtime/application is already present.

The project does not claim to make OpenCode itself offline-capable; provider APIs and other online services still require their own network access.

## 📂 Data Locations

| Data | Windows | Linux |
|---|---|---|
| Home | `data/win/home/` | `data/linux/home/` |
| Config | `data/win/config/` | `data/linux/config/` |
| Shared data | `data/win/share/` | `data/linux/share/` |
| Cache | `data/win/cache/` | `data/linux/cache/` |
| Temporary files | `data/win/temp/` | `data/linux/temp/` |
| npm cache | `data/win/npm-cache/` | `data/linux/npm-cache/` |

Provider credentials and sessions should therefore be treated as sensitive data on the USB drive. Protect the drive and back it up securely.

## 🔄 Reset / Clean Reinstall

To reset only user data, remove the relevant `data/win/` or `data/linux/` directory.

To reinstall the application/runtime for one platform, remove that platform's `engine/` and `opt/` directories. The next launcher run will provision them again.

For a complete reset, remove `engine/`, `opt/`, and `data/`.

## 🧪 Verification

The repository includes launcher scripts designed to fail safely on missing dependencies, unsupported architectures, failed downloads, and integrity mismatches.

Before release, run at minimum:

```bash
unzip -t Portable-Opencode-main.zip
bash -n OpenCode-Portable/opencode.sh
```

On Windows, validate the launcher on both x64 and ARM64 hardware/VMs where available. On Linux, test at least one glibc system and one musl system, plus an ARM64 environment if available.

> **Important:** Static verification cannot prove that every OpenCode release, Linux distribution, filesystem, antivirus configuration, or host policy will behave identically. Release testing should include real target environments.

## 🕵️ About “Zero Traces”

This project aims for **application-level data isolation**, not forensic invisibility.

OpenCode and Node.js are directed to USB-local data and temporary paths by the launcher. However, the host operating system, antivirus/EDR software, shell, filesystem, or network stack may still create independent logs, metadata, execution records, DNS records, or other traces.

Therefore this project does **not** guarantee zero host traces.

## ⚖️ Licensing & Attribution

This is an unofficial portable distribution built around the upstream OpenCode project and its published packages.

- Upstream project: https://github.com/anomalyco/opencode
- OpenCode documentation: https://opencode.ai/docs/
- Node.js: https://nodejs.org/
- npm: https://www.npmjs.com/

Third-party components retain their respective licenses. See `LICENSE` and upstream licensing information before redistribution.

## 🤝 Contributing

Bug reports and improvements are welcome. When reporting a portability problem, include:

- Operating system and version
- CPU architecture
- Linux libc (`glibc` or `musl`) where applicable
- USB filesystem and mount options
- Launcher output/error message
- OpenCode version, if known

Do **not** include API keys, provider credentials, session secrets, or personal data in issues.

## 👤 Built by Yogi

<p align="center">
  <strong>Build. Learn. Ship. Iterate.</strong>
</p>

<p align="center">
  Unofficial portable OpenCode tooling for developers who want their environment with them.
</p>
