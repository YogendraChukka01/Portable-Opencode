# OpenCode Portable 🚀

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20Linux-lightgrey.svg" alt="Platform">
  <img src="https://img.shields.io/badge/arch-x64%20%7C%20arm64-brightgreen.svg" alt="Architecture">
  <img src="https://img.shields.io/badge/build-passing-success.svg" alt="Build Status">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
</p>

<p align="center">
  <strong>⚠️ Unofficial Portable Fork — Not affiliated with the upstream OpenCode project.</strong>
</p>

<p align="center">
  <em>A self-contained, portable USB edition of <a href="https://github.com/anomalyco/opencode">OpenCode</a> that runs on both Windows and Linux — no installation, no admin rights, no traces left behind.</em>
</p>

---

## 📋 Table of Contents

- [System Architecture](#-system-architecture)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Execution Guide](#-execution-guide)
- [Configuration](#-configuration)
- [Folder Layout](#-folder-layout)
- [Resetting / Starting Over](#-resetting--starting-over)
- [Legal & Compliance](#-legal--compliance)

---

## 🏗️ System Architecture

OpenCode Portable achieves full portability through three core design principles:

### 1. Localized Runtime Isolation
Instead of relying on a host-installed Node.js (which may be missing, the wrong version, or require admin rights to install), the launcher downloads and manages a **private, portable Node.js runtime** directly onto the USB drive:

```
engine/
├── node-win/       ← Portable Node.js for Windows (downloaded once)
└── node-linux/     ← Portable Node.js for Linux (downloaded once)
```

Each OS gets its own runtime, stored side-by-side on the same USB drive. The launcher selects the correct one automatically.

### 2. Relative-Path Application Deployment
OpenCode itself is installed from the official npm package into OS-specific directories on the USB drive:

```
opt/
├── opencode-win/   ← OpenCode app for Windows (npm-installed once)
└── opencode-linux/ ← OpenCode app for Linux (npm-installed once)
```

All paths within the application are resolved relative to the USB mount point, making the entire setup **path-independent** — it works whether the drive mounts as `E:\`, `F:\`, or `/media/user/OPENCODE`.

### 3. Zero-Registry, Zero-Footprint Data Isolation
All OpenCode data — configuration, sessions, provider credentials, cache, and temporary files — is redirected into OS-specific data directories on the USB drive:

```
data/
├── win/            ← Windows data (HOME, APPDATA, TEMP redirected here)
└── linux/          ← Linux data (XDG_CONFIG_HOME, HOME, TMPDIR redirected here)
```

The launchers set environment variables (`HOME`, `APPDATA`, `XDG_CONFIG_HOME`, `TEMP`/`TMPDIR`, `XDG_CACHE_HOME`, `XDG_DATA_HOME`, `NPM_CONFIG_CACHE`) to point exclusively into these USB-local paths. **Nothing is written to the host machine's** `%APPDATA%`, `~/.config`, `~/Library`, registry, or system profile. These environment variables exist only within the terminal session launched by the portable app and vanish when the window is closed.

> **Note on "zero traces":** This covers everything OpenCode and Node.js write themselves. Host OS can still maintain its own general-purpose logs (Windows Prefetch/jump lists, Linux shell history, etc.) as it would for any program run from removable media — that's outside what any portable app can control.

---

## 📋 Prerequisites

### Host System Requirements

| Requirement | Windows | Linux |
|------------|---------|-------|
| **OS Version** | Windows 10+ | Any modern distro with bash |
| **Architecture** | x64 or arm64 | x64 or arm64 |
| **Pre-installed Tools** | PowerShell (bundled) | bash, curl, tar (default on virtually all distros) |
| **Admin / Root** | ❌ Not required | ❌ Not required (see noexec note) |
| **Internet** | ✅ Required on first run only | ✅ Required on first run only |
| **USB Drive** | exFAT-formatted (see below) | exFAT-formatted (see below) |

### USB Drive Formatting

Use **exFAT** so the same drive is readable and writable on both Windows and Linux:

<details>
<summary><strong>Windows (File Explorer)</strong></summary>

1. Right-click the USB drive in File Explorer
2. Select **Format...**
3. Set **File system** to `exFAT`
4. Click **Start**
</details>

<details>
<summary><strong>Windows (Command Line — Administrator)</strong></summary>

```batch
diskpart
list disk
select disk N          :: Replace N with your USB drive number — be careful!
clean
create partition primary
format fs=exfat quick label=OPENCODE
assign
exit
```
</details>

<details>
<summary><strong>Linux (Command Line)</strong></summary>

```bash
lsblk                           # Identify your device (e.g., /dev/sdb)
sudo mkfs.exfat -n OPENCODE /dev/sdb1
```
</details>

> **⚠️ Linux "noexec" Warning:** Some Linux desktops auto-mount removable/exFAT drives with the `noexec` option, which blocks running programs directly from the drive. If you get a "Permission denied" error when launching, run:
> ```bash
> sudo mount -o remount,exec /media/youruser/OPENCODE
> ```
> If your distro re-adds `noexec` on every reconnect, you can optionally create a small ext4 partition for `engine/` and `opt/` (ext4 does not receive `noexec` by default) and keep exFAT for data sharing.

---

## 💾 Installation

Deploying OpenCode Portable to a USB drive takes exactly **3 steps**:

### Step 1: Format the USB Drive
Format your USB drive to **exFAT** (see [USB Drive Formatting](#usb-drive-formatting) above).

### Step 2: Copy the Portable Folder
Copy the entire `OpenCode-Portable` folder onto the USB drive:

```bash
# Windows (example)
copy C:\Downloads\OpenCode-Portable E:\OpenCode-Portable /E

# Linux (example)
cp -r ~/Downloads/OpenCode-Portable /media/user/OPENCODE/
```

### Step 3: Run the Launcher (Initial Setup)
Launch the appropriate script for your OS. On first run, it will:
1. Detect your OS and CPU architecture
2. Download a portable Node.js runtime onto the USB drive
3. Install OpenCode from the official npm package onto the USB drive
4. Launch OpenCode

> **First run requires internet access.** After that, OpenCode starts instantly without downloads.

---

## 🚀 Execution Guide

### Windows

**GUI Method:**
1. Open the USB drive in File Explorer
2. Navigate to `OpenCode-Portable\`
3. Double-click **`opencode.bat`**

**Terminal Method:**
```batch
E:
cd E:\OpenCode-Portable
opencode.bat
```

### Linux

**Terminal Method:**
```bash
cd /media/youruser/OPENCODE/OpenCode-Portable
./opencode.sh
```

**GUI Method (desktop environments):**
1. Open your file manager
2. Navigate to the USB drive → `OpenCode-Portable/`
3. Right-click `opencode.sh` → **Run as executable** or **Open in Terminal**
4. If the script is not executable, run: `chmod +x opencode.sh && ./opencode.sh`

### First-Run Behavior (Both Platforms)

| Stage | Description |
|-------|-------------|
| **1. Architecture Detection** | Launcher detects x64 or arm64 automatically |
| **2. Node.js Download** | Downloads portable Node.js → `engine/node-<os>/` |
| **3. Checksum Verification** | Validates SHA256 checksum against Node's published hashes |
| **4. npm Installation** | Installs the platform-specific OpenCode build (`opencode-<os>-<arch>`) → `opt/opencode-<os>/` |
| **5. Launch** | Opens OpenCode with all environment variables set to USB-local paths |

### Subsequent Runs
On every run after the first, the launcher:
1. Detects that Node.js and OpenCode are already present on the USB
2. Launches OpenCode immediately using the local copies
3. **Never touches** any OpenCode installation that may exist on the host machine

### Integrity Verification & Reproducible Builds
Both launchers verify what they download rather than trusting the network blindly:

- **Node.js** is checked against Node's published `SHASUMS256.txt` before extraction (hard-fail on mismatch).
- **OpenCode** is resolved from the npm registry, its tarball is verified against the registry's published **SHA‑512 Subresource Integrity** (the same SRI npm uses internally), and only then installed. This makes the install tamper-evident.
- All transient files (Node's downloader `.ps1`, the OpenCode tarball, etc.) are written **onto the drive** (`data/<os>/temp/`) — nothing is left in the host's temp directory, so "zero traces" holds on first run too.

You can **pin a specific OpenCode version** for fully reproducible installs via an environment variable before launching:

```bash
# Linux
OPENCODE_VERSION=1.2.3 ./opencode.sh

# Windows (Command Prompt)
set OPENCODE_VERSION=1.2.3
opencode.bat
```

If `OPENCODE_VERSION` is unset, the current `latest` is used. The resolved version is recorded to `opt/opencode-<os>/OPENCODE_VERSION` for reference.

---

## ⚙️ Configuration

### Managing Settings Locally

All OpenCode configuration data is stored on the USB drive in OS-specific directories:

| Data Type | Windows Path | Linux Path |
|-----------|-------------|------------|
| **Home directory** | `data\win\home\` | `data/linux/home/` |
| **Config files** | `data\win\config\` | `data/linux/config/` |
| **Shared data** | `data\win\share\` | `data/linux/share/` |
| **Cache** | `data\win\cache\` | `data/linux/cache/` |
| **Temp files** | `data\win\temp\` | `data/linux/temp/` |
| **npm cache** | `data\win\npm-cache\` | `data/linux/npm-cache/` |

### Modifying Config
You can edit configuration files directly in the `data` directory:

```bash
# Windows
notepad E:\OpenCode-Portable\data\win\config\opencode.json

# Linux
nano /media/user/OPENCODE/OpenCode-Portable/data/linux/config/opencode.json
```

### Environment Variable Isolation
The launcher pins the following variables exclusively to USB-local paths:

- `HOME` / `USERPROFILE`
- `APPDATA` (Windows)
- `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME` (Linux)
- `TEMP` / `TMPDIR` / `TMP`
- `NPM_CONFIG_CACHE`

These changes are **session-scoped only** — they exist solely within the terminal or window launched by `opencode.bat` or `opencode.sh` and are never persisted to the host system.

---

## 📂 Folder Layout

```
OpenCode-Portable/
│
├── opencode.bat              ← Launcher script for Windows
├── opencode.sh                ← Launcher script for Linux
├── README.txt                 ← Legacy documentation
│
├── engine/
│   ├── node-win/              ← Portable Node.js runtime (Windows)
│   └── node-linux/            ← Portable Node.js runtime (Linux)
│
├── opt/
│   ├── opencode-win/          ← OpenCode app installation (Windows)
│   └── opencode-linux/        ← OpenCode app installation (Linux)
│
└── data/
    ├── win/
    │   ├── home/
    │   ├── config/
    │   ├── share/
    │   ├── cache/
    │   ├── temp/
    │   └── npm-cache/
    │
    └── linux/
        ├── home/
        ├── config/
        ├── share/
        ├── cache/
        ├── temp/
        └── npm-cache/
```

---

## 🔄 Resetting / Starting Over

| What to Reset | What to Delete |
|--------------|----------------|
| **Configuration & sessions only** | `data\win\` or `data/linux/` |
| **App & Node.js runtime** | `engine\` and `opt\` for the target OS |
| **Everything (clean reinstall)** | `engine\`, `opt\`, and `data\` for the target OS |

After deletion, the next run of the launcher will redownload and reinstall everything from scratch.

---

## ⚖️ Legal & Compliance

### Upstream Project
OpenCode Portable is an **unofficial portable fork** of **[OpenCode](https://github.com/anomalyco/opencode)** by [anomalyco](https://github.com/anomalyco).

- **Original Repository:** [https://github.com/anomalyco/opencode](https://github.com/anomalyco/opencode)
- **Original Creator:** [anomalyco](https://github.com/anomalyco)
- **License:** MIT

### Attribution
This project builds upon the excellent work of the OpenCode team. All credit for the core application functionality belongs to the upstream maintainers. This portable distribution simply packages the official code alongside a self-contained runtime to enable USB-portable operation without any modifications to the upstream source code.

### Licensing
This portable distribution is released under the **MIT License**, consistent with the upstream OpenCode project.

```
MIT License

Copyright (c) 2024 anomalyco — OpenCode upstream
Copyright (c) 2024 Portable-Opencode contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Third-Party Components
This distribution includes:
- **Node.js** — downloaded at runtime from [nodejs.org](https://nodejs.org), governed by its own license
- **OpenCode** — installed from the official npm package published by the `opencode-ai` project (the platform-specific `opencode-<os>-<arch>` build), governed by the upstream MIT license
- **npm dependencies** — governed by their respective licenses

---

<p align="center">
  <sub>Built with ❤️ for portable development. Not affiliated with anomalyco or the OpenCode project.</sub>
</p>