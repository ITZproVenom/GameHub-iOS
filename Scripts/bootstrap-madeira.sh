#!/usr/bin/env bash
#
# Madeira runtime bootstrap for GameHub-iOS.
#
# Fetches and pins the upstream Madeira project (Wine ARM64EC + FEX-Emu + DXMT)
# at a specific commit so GameHub can integrate a reproducible runtime.
#
# Ref: https://github.com/willfaust/Madeira
#
# NOTE: A full Madeira build is a cross-compilation effort that must run on a
# macOS/iOS toolchain (or a x86_64 Linux cross-build host per upstream docs).
# This script stages the pinned source tree and records the revision; it does
# NOT claim that Wine/FEX/DXMT execution already works on iOS from this repo.

set -euo pipefail

MADEIRA_REPO="${MADEIRA_REPO:-https://github.com/willfaust/Madeira.git}"
MADEIRA_COMMIT="${MADEIRA_COMMIT:-97e2ce26e6dc9e4a38976f3b5deb9272d64558eb}"
TARGET_DIR="${1:-vendor/madeira}"
STAMP_DIR="$TARGET_DIR/.bootstrap"

echo "Madeira bootstrap"
echo "  repo:   $MADEIRA_REPO"
echo "  commit: $MADEIRA_COMMIT"
echo "  target: $TARGET_DIR"

if [[ -d "$STAMP_DIR" ]] && [[ -f "$STAMP_DIR/commit" ]] && [[ "$(cat "$STAMP_DIR/commit")" == "$MADEIRA_COMMIT" ]]; then
  echo "Bootstrap already present and pinned at $MADEIRA_COMMIT — skipping."
  exit 0
fi

mkdir -p "$TARGET_DIR"

if [[ -d "$TARGET_DIR/.git" ]]; then
  git -C "$TARGET_DIR" fetch --depth 1 origin "$MADEIRA_COMMIT"
else
  git clone --depth 1 "$MADEIRA_REPO" "$TARGET_DIR"
fi

git -C "$TARGET_DIR" checkout -q "$MADEIRA_COMMIT"

# Record the pinned revision for reproducibility.
mkdir -p "$STAMP_DIR"
git -C "$TARGET_DIR" rev-parse HEAD > "$STAMP_DIR/commit"
git -C "$TARGET_DIR" rev-parse --short HEAD > "$STAMP_DIR/commit-short"

echo "Pinned Madeira at:"
echo "  commit: $(cat "$STAMP_DIR/commit")"
echo "  short:  $(cat "$STAMP_DIR/commit-short")"

# Remind the integrator that this is scaffolding, not a working binary bundle.
cat <<'EOF'

-------------------------------------------------------------------------------
INTEGRATION NOTE
-------------------------------------------------------------------------------
The Madeira source is staged for INTEGRATION only. Running Windows .exe files
requires building the actual runtime binaries (Wine ARM64EC, FEX Interpreter,
DXMT dylib) and bundling them inside the app, plus JIT entitlement/setup on
device. GameHub's RuntimeService reports these capabilities truthfully and will
surface "unavailable" states until the binaries are present.

See LICENSE-NOTICE.md for licensing obligations (GPL-3.0-or-later).
-------------------------------------------------------------------------------
EOF

echo "Done."