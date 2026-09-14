#!/usr/bin/env bash
# Stage pinned Madeira source for local runtime builds (GPL-3.0-or-later).
set -euo pipefail

MADEIRA_REPO="${MADEIRA_REPO:-https://github.com/willfaust/Madeira.git}"
MADEIRA_COMMIT="${MADEIRA_COMMIT:-97e2ce26e6dc9e4a38976f3b5deb9272d64558eb}"
TARGET_DIR="${1:-vendor/madeira}"
STAMP_DIR="$TARGET_DIR/.bootstrap"

echo "Madeira bootstrap → $TARGET_DIR @ $MADEIRA_COMMIT"

if [[ -f "$STAMP_DIR/commit" ]] && [[ "$(cat "$STAMP_DIR/commit")" == "$MADEIRA_COMMIT" ]]; then
  echo "Already pinned."
  exit 0
fi

rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

# Shallow clone then fetch exact commit (submodules are large).
git clone --filter=blob:none --no-checkout "$MADEIRA_REPO" "$TARGET_DIR"
git -C "$TARGET_DIR" fetch --depth 1 origin "$MADEIRA_COMMIT"
git -C "$TARGET_DIR" checkout "$MADEIRA_COMMIT"

# Best-effort submodules (wine / FEX / dxmt) — may take a long time.
git -C "$TARGET_DIR" submodule update --init --depth 1 || {
  echo "WARN: submodule init incomplete; init manually for a full Madeira build."
}

mkdir -p "$STAMP_DIR"
git -C "$TARGET_DIR" rev-parse HEAD > "$STAMP_DIR/commit"

cat <<EOF

Staged source only. Next steps for REAL .exe execution:
  1. Follow vendor/madeira README + build/*/build.sh
  2. Build app/Madeira.xcodeproj for iOS arm64
  3. Copy wine64, FEXInterpreter, dxmt11.dylib + VERSION into:
       GameHub/Resources/Runtime/  OR  device Documents/Runtime/
  4. Sideload with JIT (StikDebug) per Madeira docs

EOF
