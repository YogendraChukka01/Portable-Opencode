#!/usr/bin/env bash
# ==============================================================
#  OpenCode Portable Launcher (Linux)  -- v2 (bugfixed)
#  Runs entirely off this drive. Never touches, reads, or runs
#  any OpenCode that may already be installed on the host
#  machine. All config / sessions / credentials / cache / temp
#  files are redirected onto the drive itself.
#
#  Fixes vs v1:
#   - Node "LTS" version lookup no longer breaks on nodejs.org's
#     minified index.json (old grep/sed one-liner could silently
#     grab the wrong version, or abort the whole script under
#     `set -o pipefail` due to a SIGPIPE from `grep -m1`).
#   - Detects CPU architecture (x64 / arm64) instead of hardcoding
#     x64, so this now works on ARM boards / Graviton / Asahi etc.
#   - Verifies the downloaded Node.js tarball against Node's own
#     published SHA256SUMS before extracting it.
#   - Calls the real compiled OpenCode binary directly instead of
#     going through the npm-generated .bin/opencode shim (faster
#     startup, one less moving part).
#   - Checks for required host tools (curl, tar) up front with a
#     clear error instead of failing deep inside the script.
#   - `df --output=target` (GNU-only) no longer crashes the noexec
#     check on busybox/Alpine-style `df`.
# ==============================================================
set -euo pipefail

# --- ROOT = the folder this script lives in (works on any mount point) ---
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --------------------------------------------------------------
# STEP 0 - Make sure the tools this script depends on exist.
# Failing fast here with a clear message beats a cryptic error
# 40 lines deep into a download.
# --------------------------------------------------------------
missing=()
for cmd in curl tar; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if [ "${#missing[@]}" -gt 0 ]; then
    echo "ERROR: missing required tool(s): ${missing[*]}"
    echo "Install them with your distro's package manager and re-run this script."
    exit 1
fi

# --------------------------------------------------------------
# Detect CPU architecture. The old script silently assumed x64,
# which fails outright on ARM (Raspberry Pi, Graviton, etc).
# --------------------------------------------------------------
case "$(uname -m)" in
    x86_64|amd64)   NODE_ARCH="x64";   OC_ARCH="x64"   ;;
    aarch64|arm64)  NODE_ARCH="arm64"; OC_ARCH="arm64" ;;
    *)
        echo "ERROR: unsupported CPU architecture '$(uname -m)'."
        echo "OpenCode Portable only ships Node.js/OpenCode builds for x64 and arm64 Linux."
        exit 1
        ;;
esac

ENGINE_DIR="$ROOT/engine/node-linux"
NODE_BIN="$ENGINE_DIR/bin/node"
NPM_CMD="$ENGINE_DIR/bin/npm"

APP_DIR="$ROOT/opt/opencode-linux"

# Locate the compiled OpenCode binary anywhere under the installed npm
# tree. npm hoists platform packages (opencode-linux-<arch>) to the
# top-level node_modules, but older layouts nested them under
# opencode-ai/node_modules, and --no-bin-links means the .bin shim is
# absent -- so we search rather than trust a single hard-coded path.
locate_opencode() {
    local cand
    for cand in \
        "$APP_DIR/node_modules/opencode-ai/node_modules/opencode-linux-${OC_ARCH}/bin/opencode" \
        "$APP_DIR/node_modules/opencode-linux-${OC_ARCH}/bin/opencode" \
        "$APP_DIR/node_modules/opencode-ai/bin/opencode.exe" \
        "$APP_DIR/node_modules/.bin/opencode" ; do
        [ -x "$cand" ] && { printf '%s' "$cand"; return 0; }
    done
    # Last resort: find any matching platform binary in the tree.
    find "$APP_DIR/node_modules" -type f -path "*/opencode-linux-${OC_ARCH}/bin/opencode" 2>/dev/null | head -1
}

DATA_DIR="$ROOT/data/linux"
HOME_DIR="$DATA_DIR/home"
CONFIG_DIR="$DATA_DIR/config"
SHARE_DIR="$DATA_DIR/share"
CACHE_DIR="$DATA_DIR/cache"
TEMP_DIR="$DATA_DIR/temp"
NPMCACHE_DIR="$DATA_DIR/npm-cache"

mkdir -p "$HOME_DIR" "$CONFIG_DIR" "$SHARE_DIR" "$CACHE_DIR" "$TEMP_DIR" "$NPMCACHE_DIR" "$APP_DIR"

echo
echo "  OpenCode Portable (Linux / $NODE_ARCH)"
echo "  Running from: $ROOT"
echo

# --------------------------------------------------------------
# Quick sanity check: some distros auto-mount removable/exFAT
# drives with the "noexec" flag, which blocks running binaries
# straight off the drive. Catch that early with a clear message.
# --------------------------------------------------------------
TESTFILE="$ROOT/.exec_test"
if ! { echo '#!/bin/sh' > "$TESTFILE" && chmod +x "$TESTFILE"; }; then
    echo "ERROR: could not write a test file to $ROOT (drive may be read-only)."
    rm -f "$TESTFILE" 2>/dev/null || true
    exit 1
fi
if ! "$TESTFILE" >/dev/null 2>&1; then
    rm -f "$TESTFILE"
    # `df --output=target` is a GNU coreutils-ism; busybox df (Alpine etc.)
    # doesn't support it, so fall back gracefully instead of dying here.
    if MOUNTPOINT="$(df --output=target "$ROOT" 2>/dev/null | tail -1)" && [ -n "$MOUNTPOINT" ]; then
        :
    else
        MOUNTPOINT="$(df "$ROOT" 2>/dev/null | tail -1 | awk '{print $NF}')"
    fi
    echo "ERROR: This drive appears to be mounted with the 'noexec' option,"
    echo "which stops any program (including Node.js/OpenCode) from running"
    echo "directly off it."
    echo
    echo "Fix by remounting with exec allowed, e.g.:"
    echo "    sudo mount -o remount,exec \"$MOUNTPOINT\""
    echo
    echo "(If that keeps happening, reformat this drive/partition as ext4"
    echo "for Linux use - see README.txt.)"
    exit 1
fi
rm -f "$TESTFILE"

# --------------------------------------------------------------
# STEP 1 - Portable Node.js runtime (only downloaded once)
# --------------------------------------------------------------
if [ ! -x "$NODE_BIN" ]; then
    echo "[1/3] No portable Node.js runtime found. Downloading it now..."
    TMP_TAR="$TEMP_DIR/node-linux.tar.xz"
    TMP_EXTRACT="$TEMP_DIR/node-extract"
    rm -rf "$TMP_EXTRACT"
    mkdir -p "$TMP_EXTRACT"

    # --- Resolve the current LTS version number ----------------
    # NOTE: nodejs.org/dist/index.json is shipped minified (no
    # guaranteed newlines between records), so a plain `grep -m1`
    # over it can silently match across record boundaries and grab
    # the wrong version. We normalize it to one JSON object per
    # line first, which makes the parse reliable regardless of how
    # nodejs.org happens to format the file, and we save it to a
    # file instead of piping curl straight into grep so a `head`/
    # `-m1`-style early-exit can't SIGPIPE curl and trip `set -o
    # pipefail`.
    INDEX_JSON="$TEMP_DIR/node-index.json"
    if ! curl -fsSL "https://nodejs.org/dist/index.json" -o "$INDEX_JSON"; then
        echo "ERROR: could not reach nodejs.org to look up the current Node.js version."
        echo "Check your internet connection and try again."
        exit 1
    fi

    VER=""
    if command -v node >/dev/null 2>&1; then
        VER="$(node -e '
            const fs=require("fs");
            const idx=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
            const lts=idx.find(e=>e.lts);
            console.log(lts ? lts.version : idx[0].version);
        ' "$INDEX_JSON" 2>/dev/null || true)"
    fi
    if [ -z "$VER" ]; then
        # No node available yet (expected on first run - that's what we're
        # bootstrapping). Fall back to a record-per-line normalization
        # instead of assuming the file already has one record per line.
        NORMALIZED="$TEMP_DIR/node-index-normalized.txt"
        sed 's/},{/}\n{/g' "$INDEX_JSON" > "$NORMALIZED"
        VER="$(grep -m1 '"lts":[[:space:]]*"' "$NORMALIZED" | sed -E 's/.*"version":"([^"]+)".*/\1/' || true)"
        if [ -z "$VER" ]; then
            VER="$(grep -m1 '"version"' "$NORMALIZED" | sed -E 's/.*"version":"([^"]+)".*/\1/' || true)"
        fi
    fi
    if [ -z "$VER" ]; then
        echo "ERROR: could not determine the current Node.js LTS version from nodejs.org."
        exit 1
    fi
    echo "      Downloading Node.js $VER ($NODE_ARCH) ..."

    NODE_TARBALL="node-${VER}-linux-${NODE_ARCH}.tar.xz"
    curl -fsSL "https://nodejs.org/dist/${VER}/${NODE_TARBALL}" -o "$TMP_TAR"

    # --- Verify integrity against Node's published checksums ---
    # Best-effort: if the checksums file can't be fetched or parsed,
    # warn and continue rather than hard-failing a portable installer
    # over a transient issue - but if we DO get a checksum and it
    # doesn't match, we stop, since that indicates real corruption
    # or a tampered download.
    SHASUMS="$TEMP_DIR/SHASUMS256.txt"
    if curl -fsSL "https://nodejs.org/dist/${VER}/SHASUMS256.txt" -o "$SHASUMS" 2>/dev/null; then
        EXPECTED="$(grep " ${NODE_TARBALL}\$" "$SHASUMS" | awk '{print $1}' || true)"
        if [ -n "$EXPECTED" ]; then
            ACTUAL="$(sha256sum "$TMP_TAR" | awk '{print $1}')"
            if [ "$EXPECTED" != "$ACTUAL" ]; then
                echo "ERROR: checksum mismatch on downloaded Node.js tarball."
                echo "Expected: $EXPECTED"
                echo "Actual:   $ACTUAL"
                echo "The download may be corrupted or tampered with. Aborting."
                rm -f "$TMP_TAR"
                exit 1
            fi
            echo "      Checksum OK."
        fi
    fi

    echo "      Extracting..."
    tar -xf "$TMP_TAR" -C "$TMP_EXTRACT"
    INNER="$(find "$TMP_EXTRACT" -mindepth 1 -maxdepth 1 -type d | head -1)"
    rm -rf "$ENGINE_DIR"
    # `mv` won't create intermediate directories, so make sure the
    # parent (engine/) exists before moving the extracted node folder
    # into it. This matters on a first run where nothing is set up yet.
    mkdir -p "$(dirname "$ENGINE_DIR")"
    mv "$INNER" "$ENGINE_DIR"
    rm -rf "$TMP_TAR" "$TMP_EXTRACT" "$INDEX_JSON" "$SHASUMS"
    echo "      Done."
else
    echo "[1/3] Portable Node.js runtime found. OK."
fi

# --------------------------------------------------------------
# STEP 2 - OpenCode itself (only installed once, onto the drive)
# --------------------------------------------------------------
if [ -z "$(locate_opencode)" ]; then
    echo "[2/3] OpenCode is not yet installed. Installing from npm now..."
    export PATH="$ENGINE_DIR/bin:$PATH"
    export npm_config_cache="$NPMCACHE_DIR"
    # Install only the platform-specific OpenCode package directly instead
    # of the opencode-ai meta package. The meta package depends on every
    # platform variant (linux/win/macos x x64/arm64 x baseline/musl/...),
    # so `npm install opencode-ai` downloads several ~190 MB binaries and
    # resolves metadata for all of them -- needlessly slow. Installing just
    # opencode-linux-<arch> grabs the single binary we need.
    # --no-bin-links: skip npm's generated .bin/opencode wrapper. We call
    # the real compiled binary ourselves (see below), so we don't need it,
    # and skipping it avoids a class of symlink/shim permission issues.
    "$NPM_CMD" install "opencode-linux-${OC_ARCH}" --prefix "$APP_DIR" --no-fund --no-audit --no-bin-links --loglevel=error
    if [ -z "$(locate_opencode)" ]; then
        echo
        echo "ERROR: OpenCode installation failed. Check your internet connection and try again."
        exit 1
    fi
    echo "      OpenCode installed successfully."
else
    echo "[2/3] OpenCode already installed. OK."
fi

# Resolve the real compiled binary (npm may hoist it to the top-level
# node_modules or nest it under opencode-ai -- locate_opencode handles both).
OPENCODE_BIN="$(locate_opencode)"
if [ -z "$OPENCODE_BIN" ]; then
    echo "ERROR: could not locate the OpenCode binary after installation."
    exit 1
fi

# --------------------------------------------------------------
# STEP 3 - Launch OpenCode, fully sandboxed to the drive.
# These environment variables only exist for THIS process tree.
# Nothing persists on the host once the terminal is closed.
# --------------------------------------------------------------
echo "[3/3] Launching OpenCode (portable)..."
echo

export PATH="$ENGINE_DIR/bin:$PATH"
export HOME="$HOME_DIR"
export XDG_CONFIG_HOME="$CONFIG_DIR"
export XDG_DATA_HOME="$SHARE_DIR"
export XDG_CACHE_HOME="$CACHE_DIR"
export XDG_STATE_HOME="$SHARE_DIR/state"
export OPENCODE_CONFIG_DIR="$CONFIG_DIR/opencode"
export TMPDIR="$TEMP_DIR"
export npm_config_cache="$NPMCACHE_DIR"

mkdir -p "$OPENCODE_CONFIG_DIR"

# Call the drive's own copy of OpenCode by its exact, absolute path.
# This deliberately ignores any OpenCode that may be on the host's PATH.
cd "$ROOT"
exec "$OPENCODE_BIN" "$@"
