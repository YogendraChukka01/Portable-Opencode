# Portable-Opencode ⚡

<p align="center">
  <img src="docs/architecture.svg" alt="Portable-Opencode architecture" width="900">
</p>

<p align="center">
  <strong>Carry your AI coding environment with you.</strong><br>
  A USB-first portable environment for OpenCode on Windows and Linux.
</p>

<p align="center">
  <a href="https://github.com/YogendraChukka01/Portable-Opencode/actions"><img src="https://img.shields.io/github/actions/workflow/status/YogendraChukka01/Portable-Opencode/windows-smoke.yml?label=CI&style=flat-square" alt="CI"></a>
  <img src="https://img.shields.io/badge/Windows-x64%20%7C%20ARM64-2563eb?style=flat-square" alt="Windows">
  <img src="https://img.shields.io/badge/Linux-x64%20%7C%20ARM64-16a34a?style=flat-square" alt="Linux">
  <img src="https://img.shields.io/badge/USB-Portable-7c3aed?style=flat-square" alt="USB Portable">
  <img src="https://img.shields.io/badge/License-MIT-111827?style=flat-square" alt="MIT License">
</p>

---

## 🚀 What Portable-Opencode Provides

Portable-Opencode gives you a self-contained OpenCode environment designed to run directly from a USB drive.

It keeps the required runtime, OpenCode application, configuration, cache, temporary workspace, and application data inside the portable environment.

### Core capabilities

- 🔌 **USB-first** — run the environment directly from a removable drive.
- 🧰 **Portable Node.js** — includes platform-specific Node.js runtime storage.
- 🖥️ **Windows + Linux** — launcher-based platform detection.
- ⚙️ **x64 + ARM64** — architecture-aware runtime/application selection where supported.
- 🐧 **Linux glibc + x64 musl** — platform-specific Linux environment support.
- 📦 **Native OpenCode packages** — platform-specific application packages are stored locally.
- 🔐 **Artifact verification** — downloaded runtime/application artifacts are verified before use.
- 🗂️ **USB-local data** — configuration, cache, temporary files, and npm cache are stored in the portable data tree.
- 📌 **Version control** — OpenCode versions can be pinned with `OPENCODE_VERSION`.
- 🧹 **No traditional installer** — the launchers provision the environment directly inside the portable directory.

---

## ⚡ Quick Start

### Windows

1. Copy `OpenCode-Portable/` to a writable USB drive.
2. Open the folder.
3. Run **`opencode.bat`**.
4. The launcher prepares the required runtime and OpenCode package.
5. OpenCode starts from the portable environment.

Command Prompt:

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

On first provisioning, the launcher obtains required packages when they are not already present on the USB drive.

---

## 🧩 How It Works

<p align="center">
  <img src="docs/architecture.svg" alt="Portable-Opencode architecture diagram" width="900">
</p>

The launcher performs the following flow:

```text
USB Drive
   │
   ▼
Portable-Opencode Launcher
   │
   ├── Detect OS
   ├── Detect CPU architecture
   ├── Select portable Node.js runtime
   ├── Select OpenCode package
   ├── Verify artifacts
   ├── Configure USB-local paths
   └── Launch native OpenCode executable
```

This keeps the runtime and application environment organized under the portable directory.

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

## 🔒 USB-Local Environment

Portable-Opencode configures the launched environment to use the portable `data/` directory.

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

The launchers configure relevant paths including:

- `HOME`
- `USERPROFILE`
- `APPDATA`
- `LOCALAPPDATA`
- `XDG_CONFIG_HOME`
- `XDG_DATA_HOME`
- `XDG_CACHE_HOME`
- `XDG_STATE_HOME`
- `OPENCODE_CONFIG_DIR`
- `TEMP`
- `TMP`
- `TMPDIR`
- npm cache

These paths are configured for the launched process and stored within the portable environment.

---

## 🛡️ Artifact Integrity

Portable-Opencode verifies downloaded artifacts before installation.

### Node.js

The provisioning flow:

1. Resolves the required Node.js release.
2. Downloads the matching archive.
3. Retrieves the official checksum manifest.
4. Locates the matching archive checksum.
5. Calculates SHA-256 locally.
6. Extracts the runtime only after verification succeeds.

### OpenCode

The provisioning flow:

1. Resolves the platform-specific package.
2. Reads its published integrity value.
3. Verifies the downloaded package archive.
4. Re-downloads a corrupted cached archive.
5. Installs the package after successful verification.

---

## 🖥️ Supported Environments

| Platform | Architecture | Environment | Provided |
|---|---|---|---|
| Windows | x64 | Windows portable runtime | ✅ |
| Windows | ARM64 | Windows portable runtime | ✅ where the corresponding package is available |
| Linux | x64 | glibc | ✅ |
| Linux | ARM64 | glibc | ✅ |
| Linux | x64 | musl | ✅ |

The launcher selects the matching environment instead of using a host-installed Node.js runtime.

---

## 🐧 Linux USB Execution

For Linux USB execution, the filesystem must allow execution of the portable runtime and application.

Check the mount options with:

```bash
findmnt -no OPTIONS /media/$USER/YOUR_USB
```

If the USB filesystem is mounted with `noexec`, execution from that mount is disabled by the operating system.

---

## 📌 Version Pinning

Set `OPENCODE_VERSION` when you want the launcher to use a specific OpenCode version.

### Linux

```bash
OPENCODE_VERSION=YOUR_VERSION ./opencode.sh
```

### Windows

```bat
set OPENCODE_VERSION=YOUR_VERSION
opencode.bat
```

Keeping the required runtime and application package on the USB drive also allows the same provisioned environment to be reused across launches.

---

## 🌐 Network Usage

When required packages are not already present, the launcher obtains them from their configured package sources.

After the runtime and OpenCode application are provisioned on the USB drive, those local copies are reused on subsequent launches.

OpenCode can still use network services required by the coding workflow, such as AI providers and remote repositories.

---

## 🧹 Reset & Reinstall

### Reset portable data

Remove the relevant directory:

```text
data/win/
data/linux/
```

### Reinstall OpenCode

Remove the relevant `opt/` directory and run the launcher again.

### Reinstall Node.js

Remove the relevant `engine/` directory and run the launcher again.

### Complete reset

Remove:

```text
engine/
opt/
data/
```

The launcher can provision the environment again.

---

## 🧪 Verification

The repository includes verification and CI support for the portable environment.

### Shell checks

```bash
bash -n OpenCode-Portable/opencode.sh
bash tests/verify.sh
```

### Archive check

```bash
unzip -t Portable-Opencode-main.zip
```

### Release testing

The portable environment is tested through repository checks and Windows smoke testing. Target environments can additionally be tested on:

- Windows x64
- Windows ARM64 where available
- Linux x64 glibc
- Linux ARM64 glibc
- Linux x64 musl
- Writable USB storage

---

## 🔧 Troubleshooting

### Windows launcher does not start

Check that:

- The USB drive is writable.
- The launcher files are present.
- The system architecture matches a provided environment.
- Security software allows the runtime/application to execute.

### Linux shows `Permission denied`

Check the USB mount options:

```bash
findmnt -no OPTIONS /media/$USER/YOUR_USB
```

If `noexec` is present, use an executable mount configuration permitted by your system.

### Download or integrity verification fails

Run the launcher again after removing the incomplete cached artifact. The provisioning flow verifies the replacement before installation.

### OpenCode application files are missing

Run the launcher again so the required application package can be provisioned into the portable `opt/` directory.

---

## 🧭 Design

Portable-Opencode is organized around a simple portable workflow:

```text
         ┌──────────────────────┐
         │      USB Drive       │
         └──────────┬───────────┘
                    │
                    ▼
         ┌──────────────────────┐
         │      Launcher        │
         └──────────┬───────────┘
                    │
       ┌────────────┼────────────┐
       ▼            ▼            ▼
   Node.js      OpenCode     Portable Data
   Runtime      Package      + Cache + Temp
```

### Principles

- **Portable** — environment files live with the portable project.
- **Native** — platform-specific OpenCode packages are used.
- **Verified** — downloaded artifacts are checked before installation.
- **Organized** — runtime, application, and data have separate directories.
- **Reusable** — provisioned components remain available for later launches.
- **Configurable** — OpenCode versions can be explicitly selected.

---

## 📜 Licensing

This repository includes its applicable license in `LICENSE`.

OpenCode, Node.js, npm, and other components used by the project remain subject to their respective licenses and distribution terms.

---

## 🤝 Contributing

Compatibility reports, bug reports, and improvements are welcome.

When reporting an issue, include:

- Operating system and version
- CPU architecture
- Linux libc, when applicable
- USB filesystem
- Relevant mount options
- Launcher output
- OpenCode version

Please remove API keys, access tokens, credentials, and personal data before submitting logs.

---

<p align="center">
  <strong>Portable development. Your environment. Your drive.</strong>
</p>

<p align="center">
  Built by <strong>Yogi</strong> • Portable-Opencode
</p>
