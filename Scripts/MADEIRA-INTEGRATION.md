# Madeira (upstream runtime target)

GameHub-iOS targets the **Madeira** project as its intended runtime foundation
for running Windows x86-64 executables on iPhone/iPad:

- **Repo:** https://github.com/willfaust/Madeira
- **Pinned commit:** `97e2ce26e6dc9e4a38976f3b5deb9272d64558eb` (main)
- **License:** GPL-3.0-or-later

Madeira stacks:
- **Wine ARM64EC** — Windows API compatibility layer
- **FEX-Emu** — x86-64 → ARM64 instruction translation
- **DXMT** — Direct3D 10/11 → Metal graphics translation

## Status

Madeira is **not yet compiled or bundled** into GameHub-iOS. Until runtime
binaries (wine64, FEXInterpreter, dxmt dylib) are present in the app's managed
runtime directory, the app's `RuntimeService`/`RuntimeProvider` layer honestly
reports the runtime as **unavailable** and launch requests fail with explicit
errors rather than pretending execution works.

## Integration plan

1. Run `Scripts/bootstrap-madeira.sh` to stage the pinned upstream source under
   `vendor/madeira`.
2. Cross-compile the runtime binaries per upstream build docs for iOS ARM64.
3. Embed the binaries in the app bundle / managed storage.
4. Add the JIT entitlement (`com.apple.security.cs.allow-jit`) via a developer
   provisioning profile — required for FEX JIT compilation.
5. The existing `MadeiraRuntimeProvider` automatically becomes "installed" when
   it detects the `VERSION` file and binaries, flipping inferred capabilities on.

## Isolated JIT handling

JIT-dependent behavior (FEX translation) is kept behind the runtime
abstraction. `RuntimeProvider.isCapabilityAvailable(.jitCompilation)` gates the
launch path so the app never attempts an invalid FEX launch.