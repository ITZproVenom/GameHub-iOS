GameHub Runtime Bundle (Madeira-compatible)
===========================================

Place built Madeira products here (or under:
  Application Support/GameHubData/Runtime/
  Documents/Runtime/
)

Required:
  VERSION          — text file with runtime version string
  wine64           — Wine loader (ARM64EC / iOS build)
  FEXInterpreter   — FEX-Emu translator
  dxmt11.dylib     — DXMT D3D11 → Metal

Optional:
  wineserver
  prefix-template.tar.gz
  libdxmt_unix.a

Upstream: https://github.com/willfaust/Madeira
Pinned:   97e2ce26e6dc9e4a38976f3b5deb9272d64558eb

Build Madeira with its own Xcode project and build/*/build.sh scripts
(submodules: wine, FEX, dxmt). On-device JIT requires debugger attach
(e.g. StikDebug) — see Madeira README.

GameHub will NOT pretend launch works without these files.
