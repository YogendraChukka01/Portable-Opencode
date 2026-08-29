#!/usr/bin/env bash
# ==============================================================
#  OpenCode Portable Launcher (Linux) -- hardened
# ==============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

missing=()
for cmd in curl tar openssl sha256sum; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if [ "${#missing[@]}" -gt 0 ]; then
    echo "ERROR: missing required tool(s): ${missing[*]}"
    echo "Install them with your distro's package manager and re-run this script."
    exit 1
fi

case "$(uname -m)" in
    x86_64|amd64)   NODE_ARCH="x64";   OC_ARCH="x64"   ;;
    aarch64|arm64)  NODE_ARCH="arm64"; OC_ARCH="arm64" ;;
    *)
        echo "ERROR: unsupported CPU architecture '$(uname -m)'."
        echo "OpenCode Portable supports x64 and arm64 Linux builds."
        exit 1
        ;;
esac

# Detect musl robustly. Official Node.js portable musl archives are
# currently available for Linux x64, but not Linux arm64. Fail clearly
# instead of downloading a URL that cannot exist.
if ldd --version 2>&1 | grep -qi musl || compgen -G '/lib/ld-musl-*' >/dev/null 2>&1; then
    LIBC="musl"
else
    LIBC="glibc"
fi
if [ "$LIBC" = "musl" ] && [ "$NODE_ARCH" != "x64" ]; then
    echo "ERROR: Linux ARM64 + musl is not supported by the official portable Node.js runtime."
    echo "Use a glibc-based ARM64 Linux system, or provide a compatible Node.js runtime yourself."
    exit 1
fi

ENGINE_DIR="$ROOT/engine/node-linux-${LIBC}"
NODE_BIN="$ENGINE_DIR/bin/node"
NPM_CMD="$ENGINE_DIR/bin/npm"
APP_DIR="$ROOT/opt/opencode-linux-${LIBC}"

locate_opencode() {
    local cand
    for cand in \
        "$APP_DIR/node_modules/opencode-linux-${OC_ARCH}-${LIBC}/bin/opencode" \
        "$APP_DIR/node_modules/opencode-ai/node_modules/opencode-linux-${OC_ARCH}-${LIBC}/bin/opencode" \
        "$APP_DIR/node_modules/opencode-linux-${OC_ARCH}/bin/opencode" \
        "$APP_DIR/node_modules/opencode-ai/node_modules/opencode-linux-${OC_ARCH}/bin/opencode" \
        "$APP_DIR/node_modules/opencode-ai/bin/opencode" \
        "$APP_DIR/node_modules/.bin/opencode"; do
        [ -x "$cand" ] && { printf '%s' "$cand"; return 0; }
    done
    find "$APP_DIR/node_modules" -type f \
        \( -path "*/opencode-linux-${OC_ARCH}-${LIBC}/bin/opencode" -o \
           -path "*/opencode-linux-${OC_ARCH}/bin/opencode" \) 2>/dev/null | head -1
}

verify_sri() {
    local file="$1" sri="$2"
    local alg="${sri%%-*}" expect_b64="${sri#*-}" actual
    case "$alg" in
        sha512) actual="$(openssl dgst -sha512 -binary "$file" | openssl base64 -A)" ;;
        sha256) actual="$(openssl dgst -sha256 -binary "$file" | openssl base64 -A)" ;;
        *) return 1 ;;
    esac
    [ "$actual" = "$expect_b64" ]
}

resolve_opencode() {
    local pkg="opencode-linux-${OC_ARCH}-${LIBC}"
    local ver_spec="${OPENCODE_VERSION:-latest}"
    local meta tgz integrity tarball
    OPENCODE_TGZ=""

    if ! meta="$(curl -fsSL "https://registry.npmjs.org/${pkg}/${ver_spec}")"; then
        echo "ERROR: could not reach npm to resolve ${pkg}@${ver_spec}."
        return 1
    fi

    OPENCODE_VER="$(printf '%s' "$meta" | grep -o '"version":"[^"]*"' | head -1 | sed -E 's/"version":"([^"]*)"/\1/')"
    integrity="$(printf '%s' "$meta" | grep -o '"integrity":"[^"]*"' | head -1 | sed -E 's/"integrity":"([^"]*)"/\1/')"
    tarball="$(printf '%s' "$meta" | grep -o '"tarball":"[^"]*"' | head -1 | sed -E 's/"tarball":"([^"]*)"/\1/')"

    if [ -z "$OPENCODE_VER" ] || [ -z "$integrity" ] || [ -z "$tarball" ]; then
        echo "ERROR: incomplete npm metadata for ${pkg}@${ver_spec}."
        return 1
    fi

    echo "      Resolved OpenCode $OPENCODE_VER ($OC_ARCH / $LIBC) ..."
    tgz="$TEMP_DIR/opencode-${OPENCODE_VER}.tgz"

    if [ -f "$tgz" ] && verify_sri "$tgz" "$integrity" 2>/dev/null; then
        echo "      Cached package integrity OK."
    else
        rm -f "$tgz"
        if ! curl -fsSL "$tarball" -o "$tgz"; then
            echo "ERROR: failed to download the OpenCode package tarball."
            rm -f "$tgz"
            return 1
        fi
    fi

    echo "      Verifying package integrity ..."
    if ! verify_sri "$tgz" "$integrity"; then
        echo "ERROR: OpenCode package integrity mismatch -- possible corruption or tampering."
        rm -f "$tgz"
        return 1
    fi
    echo "      Integrity OK."
    OPENCODE_TGZ="$tgz"
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
echo "  OpenCode Portable (Linux / $NODE_ARCH / $LIBC)"
echo "  Running from: $ROOT"
echo

TESTFILE="$ROOT/.exec_test"
if ! { echo '#!/bin/sh' > "$TESTFILE" && chmod +x "$TESTFILE"; }; then
    echo "ERROR: could not write a test file to $ROOT (drive may be read-only)."
    rm -f "$TESTFILE" 2>/dev/null || true
    exit 1
fi
if ! "$TESTFILE" >/dev/null 2>&1; then
    rm -f "$TESTFILE"
    if MOUNTPOINT="$(df --output=target "$ROOT" 2>/dev/null | tail -1)" && [ -n "$MOUNTPOINT" ]; then :; else
        MOUNTPOINT="$(df "$ROOT" 2>/dev/null | tail -1 | awk '{print $NF}')"
    fi
    echo "ERROR: This drive appears to be mounted with 'noexec'."
    echo "Remount it with execution enabled if your system policy allows it:"
    echo "    sudo mount -o remount,exec \"$MOUNTPOINT\""
    exit 1
fi
rm -f "$TESTFILE"

if [ ! -x "$NODE_BIN" ]; then
    echo "[1/3] No portable Node.js runtime found. Downloading it now..."
    TMP_TAR="$TEMP_DIR/node-linux.tar.xz"
    TMP_EXTRACT="$TEMP_DIR/node-extract"
    INDEX_JSON="$TEMP_DIR/node-index.json"
    NORMALIZED="$TEMP_DIR/node-index-normalized.txt"
    SHASUMS="$TEMP_DIR/SHASUMS256.txt"
    rm -rf "$TMP_EXTRACT"
    mkdir -p "$TMP_EXTRACT"

    if ! curl -fsSL "https://nodejs.org/dist/index.json" -o "$INDEX_JSON"; then
        echo "ERROR: could not reach nodejs.org to resolve Node.js."
        exit 1
    fi

    sed 's/},{/}\n{/g' "$INDEX_JSON" > "$NORMALIZED"
    VER="$(grep -m1 '"lts":[[:space:]]*"' "$NORMALIZED" | sed -E 's/.*"version":"([^"]+)".*/\1/' || true)"
    if [ -z "$VER" ]; then
        echo "ERROR: could not determine the current Node.js LTS version."
        exit 1
    fi

    if [ "$LIBC" = "musl" ]; then
        NODE_TARBALL="node-${VER}-linux-${NODE_ARCH}-musl.tar.xz"
    else
        NODE_TARBALL="node-${VER}-linux-${NODE_ARCH}.tar.xz"
    fi

    echo "      Downloading Node.js $VER ($NODE_ARCH / $LIBC) ..."
    if ! curl -fsSL "https://nodejs.org/dist/${VER}/${NODE_TARBALL}" -o "$TMP_TAR"; then
        echo "ERROR: could not download ${NODE_TARBALL}."
        exit 1
    fi

    if ! curl -fsSL "https://nodejs.org/dist/${VER}/SHASUMS256.txt" -o "$SHASUMS"; then
        echo "ERROR: could not download Node.js checksum manifest."
        rm -f "$TMP_TAR"
        exit 1
    fi

    EXPECTED="$(grep " ${NODE_TARBALL}\$" "$SHASUMS" | awk '{print $1}' || true)"
    if [ -z "$EXPECTED" ]; then
        echo "ERROR: checksum entry for ${NODE_TARBALL} was not found."
        rm -f "$TMP_TAR"
        exit 1
    fi
    ACTUAL="$(sha256sum "$TMP_TAR" | awk '{print $1}')"
    if [ "$EXPECTED" != "$ACTUAL" ]; then
        echo "ERROR: Node.js checksum mismatch."
        echo "Expected: $EXPECTED"
        echo "Actual:   $ACTUAL"
        rm -f "$TMP_TAR"
        exit 1
    fi
    echo "      Checksum OK."

    echo "      Extracting..."
    tar -xf "$TMP_TAR" -C "$TMP_EXTRACT"
    INNER="$(find "$TMP_EXTRACT" -mindepth 1 -maxdepth 1 -type d | head -1)"
    if [ -z "$INNER" ]; then
        echo "ERROR: Node.js archive extracted without a top-level directory."
        exit 1
    fi
    rm -rf "$ENGINE_DIR"
    mkdir -p "$(dirname "$ENGINE_DIR")"
    mv "$INNER" "$ENGINE_DIR"
    rm -rf "$TMP_TAR" "$TMP_EXTRACT" "$INDEX_JSON" "$NORMALIZED" "$SHASUMS"
    echo "      Done."
else
    echo "[1/3] Portable Node.js runtime found. OK."
fi

if [ -z "$(locate_opencode)" ]; then
    echo "[2/3] OpenCode is not yet installed. Resolving + verifying package..."
    export PATH="$ENGINE_DIR/bin:$PATH"
    export npm_config_cache="$NPMCACHE_DIR"
    resolve_opencode
    "$NPM_CMD" install "$OPENCODE_TGZ" --prefix "$APP_DIR" --no-fund --no-audit --no-bin-links --loglevel=error
    printf '%s\n' "$OPENCODE_VER" > "$APP_DIR/OPENCODE_VERSION"
    if [ -z "$(locate_opencode)" ]; then
        echo "ERROR: OpenCode installation completed without a runnable binary."
        exit 1
    fi
    echo "      OpenCode $OPENCODE_VER installed successfully."
else
    echo "[2/3] OpenCode already installed. OK."
fi

OPENCODE_BIN="$(locate_opencode)"
if [ -z "$OPENCODE_BIN" ]; then
    echo "ERROR: could not locate the OpenCode binary."
    exit 1
fi

echo "[3/3] Launching OpenCode (portable)..."
echo
export PATH="$ENGINE_DIR/bin:$PATH"
export HOME="$HOME_DIR"
export XDG_CONFIG_HOME="$CONFIG_DIR"
export XDG_DATA_HOME="$SHARE_DIR"
export XDG_CACHE_HOME="$CACHE_DIR"
export XDG_STATE_HOME="$SHARE_DIR/state"
export XDG_RUNTIME_DIR="$TEMP_DIR/runtime"
export OPENCODE_CONFIG_DIR="$CONFIG_DIR/opencode"
export TMPDIR="$TEMP_DIR"
export npm_config_cache="$NPMCACHE_DIR"
mkdir -p "$OPENCODE_CONFIG_DIR" "$XDG_RUNTIME_DIR"
cd "$ROOT"
exec "$OPENCODE_BIN" "$@"
