OpenCode Portable (USB Edition — Windows + Linux)
====================================================

CHANGES IN THIS VERSION (bug fixes)
------------------------------------
This build fixes several real bugs found in the previous version:

  1. WINDOWS: the previous opencode.bat called the npm-generated
     node_modules\.bin\opencode.cmd shim, which is broken on stock
     Windows -- it tries to run the package's helper script via
     "/bin/sh.exe", which doesn't exist on Windows, so it failed with
     "'/bin/sh.exe' is not recognized..." or "cannot execute binary
     file" (this is a known upstream packaging issue in opencode-ai,
     see anomalyco/opencode issue #2447). opencode.bat now calls the
     real compiled opencode-windows-<arch>\bin\opencode.exe directly,
     which sidesteps the broken shim entirely and starts faster too.
  2. Both launchers now install with --no-bin-links, avoiding a class
     of symlink/EPERM permission errors some Windows users hit during
     npm's shim-generation step.
  3. LINUX: the old Node.js "LTS version" lookup used a grep/sed
     one-liner over nodejs.org/dist/index.json that could silently
     grab the wrong version (or, under some shells, abort the whole
     script) if that file isn't formatted exactly as expected. The
     lookup is now done reliably (via Node itself where available,
     with a hardened text-based fallback otherwise).
  4. Both platforms previously assumed x64 unconditionally. Both
     launchers now detect the CPU architecture and also support
     arm64 (Raspberry Pi / Graviton / Linux-on-ARM, and Windows
     ARM64 devices like Snapdragon X Elite).
  5. The downloaded Node.js archive is now checksum-verified against
     Node's own published SHA256 sums before being extracted.
  6. Both launchers now fail with a clear message up front if a
     required host tool is missing, instead of failing confusingly
     partway through.
  7. WINDOWS: a Node.js download failure is now actually detected and
     reported (the old download helper always reported success no
     matter what happened).

WHAT THIS IS
------------
A self-contained copy of OpenCode (github.com/anomalyco/opencode) that runs
straight off a USB flash drive on either Windows or Linux — no admin/root
rights, no installer, no changes to the host machine. Same USB drive, same
folder, works on both operating systems.

HOW TO SET IT UP
-----------------
1. Format the USB drive (see "FORMATTING THE USB DRIVE" below).
2. Copy this whole "OpenCode-Portable" folder onto the drive
   (e.g. E:\OpenCode-Portable on Windows, /media/usb/OpenCode-Portable
   on Linux).
3. On Windows: double-click "opencode.bat" (or run it from Command Prompt).
   On Linux:   run "./opencode.sh" from a terminal inside that folder.

WHAT HAPPENS THE FIRST TIME YOU RUN IT (per OS)
--------------------------------------------------
- It downloads a portable copy of Node.js onto the USB, into either
  engine\node-win (Windows) or engine/node-linux (Linux). Only once, per OS.
- It then installs OpenCode itself onto the USB from the official npm
  package (opencode-ai), into opt\opencode-win or opt/opencode-linux.
  Only once, per OS.
- This first run needs internet access. After that, OpenCode starts
  instantly with no download — on either OS.

Note: Windows and Linux binaries can't be shared, so each OS gets its own
copy of the Node runtime and OpenCode app on the drive (that's why there
are separate "-win" and "-linux" folders). Your actual OpenCode data
(config/sessions) is also kept separate per OS under data\win and
data/linux, to avoid path-format conflicts between the two systems.

WHAT HAPPENS EVERY TIME AFTER THAT
------------------------------------
- The launcher sees Node.js and OpenCode are already on the USB for that
  OS and launches OpenCode immediately, using the exact copy on the drive.
- It never looks at or runs any OpenCode that might already be installed
  on the host machine, even if one is present.

WHERE YOUR DATA LIVES
-----------------------
Everything OpenCode reads or writes — config, sessions, provider
credentials, cache, temp files — is redirected into:

    Windows: OpenCode-Portable\data\win\
    Linux:   OpenCode-Portable/data/linux/

Nothing is written to the host machine's normal user profile, AppData,
registry, or ~/.config by OpenCode itself. All redirect environment
variables (HOME, APPDATA, XDG_CONFIG_HOME, TEMP/TMPDIR, etc.) are set
only inside the terminal/window the launcher opens — they vanish the
moment you close it and are never saved to the host system.

Note on "zero traces": this covers everything OpenCode and Node.js write
themselves. The host OS can still keep its own general-purpose logs of
"a program was run from this drive" (Windows Prefetch/jump lists, Linux
shell history, etc.) the same way it would for any program run from
removable media — that's outside what any portable app can control.

FORMATTING THE USB DRIVE
----------------------------
Use exFAT so the same drive is readable/writable on both Windows and
Linux:

  Windows (File Explorer):
    Right-click the drive -> Format... -> File system: exFAT -> Start.

  Windows (command line, as Administrator):
    diskpart
    list disk
    select disk N        (replace N with your USB drive's number - be sure!)
    clean
    create partition primary
    format fs=exfat quick label=OPENCODE
    assign
    exit

  Linux (command line):
    lsblk                          # find your device, e.g. /dev/sdb
    sudo mkfs.exfat -n OPENCODE /dev/sdb1

IMPORTANT - Linux "noexec" mounts:
Some Linux desktops auto-mount removable/exFAT drives with the "noexec"
option, which blocks running any program (including Node.js/OpenCode)
directly from the drive. opencode.sh detects this automatically and
prints the exact fix, e.g.:
    sudo mount -o remount,exec /media/youruser/OPENCODE
If your distro keeps re-adding noexec on every plug-in and this gets
annoying, you can alternatively give the drive a second, small ext4
partition just for the "engine" and "opt" folders (ext4 doesn't get
noexec by default) and keep exFAT only for general file sharing.

MOVING TO A NEW COMPUTER
--------------------------
Just plug the USB drive into any other Windows or Linux machine and run
the matching launcher again. Because everything (runtime + app + your
data) lives on the drive, it works identically everywhere and your
sessions/config travel with you.

FOLDER LAYOUT
--------------
OpenCode-Portable/
  opencode.bat              <- run this on Windows
  opencode.sh                <- run this on Linux
  engine/
    node-win/                 portable Node.js runtime for Windows
    node-linux/                portable Node.js runtime for Linux
  opt/
    opencode-win/              OpenCode app (Windows)
    opencode-linux/             OpenCode app (Linux)
  data/
    win/
      home/  config/  share/  cache/  temp/  npm-cache/
    linux/
      home/  config/  share/  cache/  temp/  npm-cache/

RESETTING / STARTING OVER
----------------------------
Delete data\win or data/linux to wipe that OS's sessions/config (keeps
the installed runtime/app). Delete the matching engine/... and opt/...
folders too if you want that OS's launcher to redownload everything
from scratch.

REQUIREMENTS ON THE HOST
-----------------------------
Windows: Windows 10+ (PowerShell, bundled with Windows, is used only for
         the one-time download/extract step). No admin rights needed.
Linux:   bash, curl, tar (present on virtually every distro by default).
         No root needed, unless you hit the noexec issue above.
Both:    Internet access on first run only, per OS.
