# Portable-Opencode ⚡

<p align="center">
  <img src="docs/architecture.svg" alt="Portable-Opencode architecture" width="900">
</p>

<p align="center">
  <strong>Carry your AI coding environment with you.</strong><br>
  A USB-first portable runtime for OpenCode on Windows and Linux.
</p>

<p align="center">
  <a href="https://github.com/YogendraChukka01/Portable-Opencode/actions"><img src="https://img.shields.io/github/actions/workflow/status/YogendraChukka01/Portable-Opencode/windows-smoke.yml?label=CI&style=flat-square" alt="CI"></a>
  <img src="https://img.shields.io/badge/Windows-x64%20%7C%20ARM64-2563eb?style=flat-square" alt="Windows">
  <img src="https://img.shields.io/badge/Linux-x64%20%7C%20ARM64-16a34a?style=flat-square" alt="Linux">
  <img src="https://img.shields.io/badge/USB-Portable-7c3aed?style=flat-square" alt="USB Portable">
  <img src="https://img.shields.io/badge/License-MIT-111827?style=flat-square" alt="MIT License">
</p>

---

## What is Portable-Opencode?

**Portable-Opencode** packages the runtime and application environment needed to run OpenCode from a removable drive.

The launcher keeps the runtime, OpenCode installation, configuration, cache, temporary files, and application data inside the portable directory instead of depending on a conventional host installation.

### The goal

> **Plug in → launch → code → unplug.**

No global Node.js installation. No administrator/root installation required by the launcher itself. Your portable environment stays organized on the drive.

---

## ✨ Why Portable-Opencode?

| Capability | Portable-Opencode |
|---|---|
| USB-first workflow | ✅ |
| Host Node.js required | ❌ |
| Windows | ✅ |
| Linux | ✅ |
| x64 | ✅ |
| ARM64 | ✅ where native packages/runtime are available |
| Linux musl x64 | ✅ |
| Native OpenCode binary | ✅ |
| USB-local configuration | ✅ |
| USB-local cache/temp | ✅ |
| Artifact integrity verification | ✅ |
| Reproducible OpenCode version | ✅ with `OPENCODE_VERSION` |
| Literal zero host traces | ❌ not claimed |

---

## 🚀 Quick Start

### Windows

1. Copy `OpenCode-Portable/` to a writable USB drive.
2. Open the folder.
3. Run **`opencode.bat`**.
4. The first run provisions the required runtime and OpenCode package.
5. Start coding.

From Command Prompt:

```bat
cd /d E:\OpenCode-Portable
opencode.bat
```

### Linux

```bash
cd /media/$USER/YOUR_USB/OpenCode-Portable
chmod +x opencode.sh
./opencode.sh
```

The first provisioning run needs network access unless the required runtime and application packages are already present on the drive.

---

## 🧩 How it works

```text
                         ┌─────────────────────┐
                         │   USB Drive         │
                         │  Portable-Opencode  │
                         └──────────┬──────────┘
                                    │
                     ┌──────────────▼──────────────┐
                     │          Launcher           │
                     │  Windows .bat / Linux .sh  │
                     └──────────────┬──────────────┘
                                    │
                ┌───────────────────┼───────────────────┐
                │                   │                   │
        ┌───────▼───────┐   ┌───────▼───────┐   ┌──────▼──────┐
        │ Portable Node │   │ Native OpenCode│   │ USB-local   │
        │    runtime    │   │    binary     │   │ data/cache  │
        └───────────────┘   └───────────────┘   └─────────────┘
```

The launchers:

1. Detect the host operating system and CPU architecture.
2. Select the appropriate portable Node.js runtime.
3. Resolve the platform-specific OpenCode package.
4. Verify downloaded artifacts before installation.
5. Install the application into the portable directory.
6. Redirect relevant runtime/application paths to USB-local storage.
7. Launch the native OpenCode executable directly.

---

## 📁 Project Structure

```text
Portable-Opencode/
│
├── OpenCode-Portable/
│   ├── opencode.bat              # Windows launcher
│   ├── opencode.sh               # Linux launcher
│   │
│   ├── engine/                   # Portable runtimes
│   │   ├── node-win/
│   │   ├── node-linux-glibc/
│   │   └── node-linux-musl/
│   │
│   ├── opt/                      # OpenCode application packages
│   │   ├── opencode-win/
│   │   ├── opencode-linux-glibc/
│   │   └── opencode-linux-musl/
│   │
│   └── data/                     # Portable application state
│       ├── win/
│       └── linux/
│
├── docs/
│   ├── architecture.svg
│   └── PORTABILITY.md
│
├── tests/
│   └── verify.sh
│
└── .github/
    └── workflows/
```

---

## 🔒 Portable Data Isolation

Portable-Opencode redirects the relevant environment paths into the USB-local `data/` tree.

### Windows

```text
data/win/
├── home/
├── config/
├── share/
├── cache/
├── temp/
├── npm-cache/
└── logs/
```

### Linux

```text
data/linux/
├── home/
├── config/
├── share/
├── cache/
├── temp/
└── npm-cache/
```

The launchers configure paths such as:

- `HOME`
- `USERPROFILE`
- `APPDATA`
- `LOCALAPPDATA`
- `XDG_CONFIG_HOME`
- `XDG_DATA_HOME`
- `XDG_CACHE_HOME`
- `XDG_STATE_HOME`
- `OPENCODE_CONFIG_DIR`
- `TEMP` / `TMP` / `TMPDIR`
- npm cache

These are configured for the launched process rather than installed as permanent system environment variables.

---

## 🛡️ Integrity & Security

Portable-Opencode verifies downloaded artifacts before using them.

### Node.js verification

The launcher:

1. Resolves a Node.js release.
2. Downloads the matching archive.
3. Retrieves the official `SHASUMS256.txt` manifest.
4. Requires a matching checksum entry.
5. Calculates SHA-256 locally.
6. Refuses extraction when the checksum does not match.

### OpenCode verification

The launcher:

1. Resolves the platform-specific npm package.
2. Reads the package's published `dist.integrity` value.
3. Verifies the downloaded tarball using the declared SRI algorithm.
4. Re-downloads a corrupted cached archive.
5. Installs only after successful verification.

**Never store API keys or provider credentials in a public repository.** Treat the USB drive as sensitive because it may contain sessions, configuration, credentials, and project data.

---

## 🖥️ Platform Support

| Platform | Architecture | Runtime | Status |
|---|---|---|---|
| Windows 10+ | x64 | Windows | ✅ Supported |
| Windows 10+ | ARM64 | Windows | ✅ Supported when native package is available |
| Linux | x64 | glibc | ✅ Supported |
| Linux | ARM64 | glibc | ✅ Supported |
| Linux | x64 | musl | ✅ Supported |
| Linux | ARM64 | musl | ⚠️ Not supported by the standard portable Node.js runtime path |

Portable-Opencode intentionally fails with a clear message when a compatible official runtime cannot be provided rather than silently selecting an incompatible binary.

---

## 🐧 Linux `noexec` Drives

Some removable Linux filesystems are mounted with `noexec`. Executables on such a mount cannot run.

Check:

```bash
findmnt -no OPTIONS /media/$USER/YOUR_USB
```

If `noexec` is enabled, use a mount configuration that permits execution if your system policy allows it.

For Linux-only portable deployments, an executable Linux filesystem such as ext4 can be more suitable than exFAT.

---

## 📌 Version Pinning

The launcher can use the current OpenCode package by default, or you can pin a specific version for reproducible deployments.

### Linux

```bash
OPENCODE_VERSION=YOUR_VERSION ./opencode.sh
```

### Windows

```bat
set OPENCODE_VERSION=YOUR_VERSION
opencode.bat
```

For maximum reproducibility, provision and retain a specific Node.js runtime on the USB drive as well.

---

## 🌐 Network Requirements

### First provisioning

Internet access is normally required to download:

- Node.js
- OpenCode package
- npm package metadata

### Later launches

If the runtime and application are already present, the launcher does not need to download them again.

OpenCode's own AI providers, APIs, repositories, and other online services still require network connectivity when those services are used.

---

## 🧹 Reset & Reinstall

### Reset user/application data

Delete the platform-specific `data/` directory:

```text
data/win/
data/linux/
```

### Reinstall OpenCode

Remove the relevant `opt/` directory and launch again.

### Reinstall Node.js

Remove the relevant `engine/` directory and launch again.

### Complete reset

Remove:

```text
engine/
opt/
data/
```

The next launch provisions the environment again.

---

## 🧪 Verification & CI

The repository contains automated and static checks for the portable implementation.

Basic shell verification:

```bash
bash -n OpenCode-Portable/opencode.sh
bash tests/verify.sh
```

Archive verification:

```bash
unzip -t Portable-Opencode-main.zip
```

GitHub Actions provides Windows smoke testing and repository-level portability checks.

### Release testing matrix

Before calling a release production-ready, test on:

- Windows x64
- Windows ARM64 where available
- Linux x64 glibc
- Linux ARM64 glibc
- Linux x64 musl
- A writable USB filesystem
- A Linux `noexec` mount for the expected diagnostic path

Static checks are useful safeguards but cannot replace execution on real target environments.

---

## 🔍 Troubleshooting

### `opencode.bat` does not start

Check:

- USB drive is writable.
- Windows is supported.
- CPU architecture is supported.
- Security software is not blocking execution.
- The drive path does not use an unsupported filesystem configuration.

### Linux says `Permission denied`

Check for `noexec`:

```bash
findmnt -no OPTIONS /media/$USER/YOUR_USB
```

### Download or integrity failure

Remove the incomplete/corrupted cached artifact and run the launcher again. The launcher will verify the replacement before installation.

### OpenCode cannot be found after installation

Run the launcher again and inspect the `opt/` directory. If the problem persists, report the OS, architecture, libc, launcher output, and OpenCode version without including secrets.

---

## ⚠️ Important Limitations

Portable-Opencode provides **application-level portability and data isolation**. It does **not** provide forensic invisibility or guarantee that the host computer leaves no traces.

The host OS, antivirus/EDR, filesystem, shell, USB subsystem, DNS resolver, network infrastructure, or security policies may independently create logs, metadata, execution records, or other traces.

The project also does not bypass organizational security controls or host execution restrictions.

---

## 🧭 Design Principles

Portable-Opencode follows a few simple principles:

- **Portable by default** — runtime and application live with the project.
- **Fail closed** — failed integrity checks stop installation.
- **Native execution** — use the platform's native OpenCode binary.
- **Explicit compatibility** — don't pretend unsupported combinations work.
- **Local state** — keep application state under the portable data tree.
- **Reproducible when pinned** — support explicit OpenCode versions.
- **Transparent limitations** — portability is not the same as invisibility.

---

## 📜 Licensing

Portable-Opencode is distributed under the license included in this repository.

OpenCode, Node.js, npm, and other third-party components remain subject to their respective licenses and distribution terms. Review upstream licensing requirements before redistributing bundled artifacts.

### Project links

- OpenCode: https://github.com/anomalyco/opencode
- OpenCode documentation: https://opencode.ai/docs/
- Node.js: https://nodejs.org/
- npm: https://www.npmjs.com/

---

## 🤝 Contributing

Contributions, bug reports, compatibility reports, and improvements are welcome.

When reporting a portability issue, include:

- Operating system and version
- CPU architecture
- Linux libc (`glibc` / `musl`), if applicable
- USB filesystem
- Mount options, if relevant
- Launcher output
- OpenCode version

**Never post API keys, tokens, credentials, session files, or personal data in issues.**

---

## ⭐ Project

If Portable-Opencode is useful to you, consider starring the repository and sharing compatibility feedback.

<p align="center">
  <strong>Portable development. Your environment. Your drive.</strong>
</p>

<p align="center">
  Built by <strong>Yogi</strong> • Portable-Opencode
</p>
