# Madeira host library build (commit 97e2ce26)

## How Madeira produces host `.a` files

| Library | Producer | Prerequisites |
|---------|----------|---------------|
| `libntdll_unix.a` | `build/ntdll-unix/build.sh` | `wine/` submodule (`ios-build`), **`wine/build-macos/include/config.h`** from host `./configure` |
| `libwineserver.a` | `build/wineserver/build.sh` | Same + often a prior base `app/Madeira/libwineserver.a` to patch |
| `libwin32u_unix.a` | `build/win32u-unix/build.sh` | Same wine build-macos headers |
| `libFEXCore.a` etc. | CMake into `FEX/build-ios/` | FEX submodule `ios-port-2607`, iOS SDK, Ninja |
| `libdxmt_combined.a` | `build/dxmt-ios/build.sh` + libtool | `research/dxmt`, **LLVM 15 iOS**, llvm-mingw, Metal toolchain |
| Crypto `.a` | `build/gnutls-ios/build.sh` | GMP/nettle/gnutls sources |

WineProcessBridge.m / FEXBridge.mm are **sources** linked against those archives inside Madeira.xcodeproj — they are not self-contained.

## FEX paths (from Madeira.xcodeproj)

```
FEX/build-ios/FEXCore/Source/libFEXCore.a
FEX/build-ios/FEXCore/Source/libFEXCore_Base.a
FEX/build-ios/External/fmt/libfmt.a
...
```

## DXMT

See `build/dxmt-ios/README.md`: requires llvm-mingw + LLVM 15 cross for iOS (~multi-hour).

## CI

`.github/workflows/build-madeira-host.yml` attempts stages in order and uploads any produced `.a` files plus logs. Green stage ≠ full .exe execution.
