#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v bash >/dev/null
a="${ROOT}/OpenCode-Portable/opencode.sh"
b="${ROOT}/OpenCode-Portable/opencode.bat"
test -f "$a"
test -f "$b"
test -f "$ROOT/README.md"
test -f "$ROOT/docs/architecture.svg"

bash -n "$a"
grep -q 'OPENCODE_VERSION' "$a"
grep -q 'OPENCODE_VERSION' "$b"
grep -q 'SHASUMS256.txt' "$a"
grep -q 'SHA256' "$b"
grep -q 'integrity' "$b"
grep -q 'musl' "$a"

echo "PASS: portable repository static verification"
