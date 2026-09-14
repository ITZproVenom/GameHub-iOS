<p align="center">
  <img src="assets/gamehub-icon.svg" alt="GameHub-iOS" width="220" height="220">
</p>

<h1 align="center">GameHub-iOS</h1>

<p align="center">
  <em>A native iOS game library for running Windows executables on iPhone &amp; iPad.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS%2017%2B-7c3aed" alt="Platform: iOS 17+">
  <img src="https://img.shields.io/badge/framework-SwiftUI-6d28d9" alt="Framework: SwiftUI">
  <img src="https://img.shields.io/badge/Swift-5-4f46e5" alt="Swift 5">
  <img src="https://img.shields.io/badge/license-GPL--3.0--or--later-22d3ee" alt="License: GPL-3.0-or-later">
  <img src="https://github.com/ITZproVenom/GameHub-iOS/actions/workflows/ios.yml/badge.svg" alt="Build status">
</p>

<p align="center">
  <a href="#status">Status</a> ·
  <a href="#features">Features</a> ·
  <a href="#requirements">Requirements</a> ·
  <a href="#build">Build</a> ·
  <a href="#runtime">Runtime &amp; limitations</a> ·
  <a href="#architecture">Architecture</a> ·
  <a href="#roadmap">Roadmap</a> ·
  <a href="#credits">Credits</a> ·
  <a href="#license">License</a>
</p>

---

## What is this?

GameHub-iOS is a **native SwiftUI application** (MVVM + service layer) that manages a
personal library of imported Windows executables (`.exe`, `.msi`, `.bat`, `.cmd`) and is
designed to launch them through an iOS-compatible Windows runtime: **Wine** on
**ARM64EC**, accelerated by **FEX** (x86-64 → ARM64 translation) and **DXMT** (D3D11 →
Metal), orchestrated by **[Madeira](https://github.com/willfaust/Madeira)**.

It is an original reimplementation of the *concept* popularized by the Android
"GameHub" app — running Windows games on mobile hardware. No Android GameHub source,
assets, or trademarks are copied into this repository; the app and logo are clean-room
work.

> **Important:** the runtime stack (**Madeira / Wine / FEX / DXMT**) is **not yet
> bundled** with this repository. Importing, library management, per-game containers,
> settings, input and performance telemetry are implemented and tested. Actually
> launching a `.exe` requires the runtime binaries to be compiled for each target
> and bundled — until then the runtime layer truthfully reports "runtime not installed".

## Status

**Current phase — pre-alpha foundation.**

- ✅ App skeleton, navigation, library, import pipeline
- ✅ Per-game Wine container model + persistence (architecture, resolution, graphics,
  audio, input, DXVK/DXMT toggles, env vars, launch args)
- ✅ Runtime abstraction (`RuntimeProvider` protocol) with honest capability/state
  reporting and isolated JIT handling
- ✅ GameController-based input service, performance monitor, persisted logs
- ✅ Unit test suite + CI (simulator build, tests, unsigned IPA)
- ⏳ Compiling and bundling the Madeira runtime for arm64 iOS
- ⏳ End-to-end `.exe` execution on device
- ⏳ App Store / TestFlight distribution strategy (GPL obligations apply)

Work is tracked in [Issues](https://github.com/ITZproVenom/GameHub-iOS/issues).

## Features

- **Library grid** — artwork, titles, last-played, favorites, search, sorting and
  filtering, empty state, context menus, material backgrounds.
- **Native import** — system document picker (`UTType.exe`, `.msi`, `.bat`, `.cmd`);
  imports the file into app-managed storage, creates a `Game` record and a per-game
  container.
- **Per-game containers** — real, individually persisted Windows prefixes in JSON
  under `Application Support/GameHubData`, with architecture/Windows-version defaults,
  resolution, graphics/audio/input settings, DXVK/DXMT toggles, environment variables
  and launch arguments.
- **Runtime abstraction** — `RuntimeProvider` protocol with a `MadeiraRuntimeProvider`
  that reports capabilities and states truthfully; JIT requirements are isolated so
  the rest of the app stays runtime-agnostic.
- **Input** — `GameController`-based `InputService` (gamepads, keyboard, mouse),
  connection monitoring and haptics.
- **Performance** — `CADisplayLink` monitor reporting FPS, frame time, CPU and memory
  (no fabricated metrics).
- **Logs** — persistent, filterable application log store you can export.
- **Settings** — runtime provider selection, default architecture, import behavior.

## Architecture

```
MVVM + service layer

GameHub/App        App entry point + AppState composition root
GameHub/Models     Game, Container, RuntimeConfig, AppSettings, enums
GameHub/Services   Storage, Game, Container, Runtime, Input, Performance, Log
GameHub/Services/Runtime   RuntimeProvider protocol + MadeiraRuntimeProvider
GameHub/ViewModels Library, GameDetail, Import, Container, Settings
GameHub/Views      SwiftUI screens (Library, Import, Detail, Container, Settings)
GameHub/Utilities  Constants, extensions
GameHubTests       Unit tests (persistence, import, containers, settings, runtime)
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full design write-up.

## Requirements

- Xcode 15 or newer
- Swift 5 toolchain
- iOS deployment target **17.0+**
- A physical iPhone/pad/iPad is required for controller and on-device runtime testing;
  the simulator is supported for the app, UI and unit tests.

## Build

```sh
git clone https://github.com/ITZproVenom/GameHub-iOS.git
cd GameHub-iOS
open GameHub.xcodeproj
```

Select the **GameHub** scheme and build/run on an iOS 17+ simulator or device.

Unit tests: `⌘ U` with the **GameHubTests** target, or via CI.

### Continuous integration

`.github/workflows/ios.yml` (on `macos-14`) builds the app for the iOS simulator,
runs the unit test suite, and archives an unsigned IPA every push to default/main —
so current build status always reflects the code on this branch.

## Runtime &amp; limitations

Target pipeline: `.exe → Wine (ARM64EC) → FEX x86-64→ARM64 → DXMT D3D11→Metal → iOS`.

- Upstream: [willfaust/Madeira](https://github.com/willfaust/Madeira)
- Pinned: `97e2ce26e6dc9e4a38976f3b5deb9272d64558eb` (GPL-3.0-or-later)
- Stage the pinned source: `Scripts/bootstrap-madeira.sh`
- Integration plan: `Scripts/MADEIRA-INTEGRATION.md`
- Licensing obligations: `LICENSE-NOTICE.md`

What the app will **not** do: it will not fabricate launch results. Until runtime
binaries are present, launching a game returns an explicit "runtime not installed"
state and the runtime UI shows the provider as unavailable. JIT-forcing the CPU, and
running apps from unsigned sources, also trigger App Store review implications that
must be resolved before any store distribution.

## Roadmap

- [ ] Compile and bundle **Madeira** (Wine/FEX/DXMT) for `arm64` iOS targets
- [ ] Runtime state machine + launch orchestration wired to the container configs
- [ ] On-device import → launch → play loop validation
- [ ] Game art / metadata enrichment and cloud sync
- [ ] Store release with GPL-compliant source offering
- [ ] Per-game saves, shader cache and performance presets

## Credits &amp; third-party

- **Madeira** — [github.com/willfaust/Madeira](https://github.com/willfaust/Madeira) — GPL-3.0-or-later
- **Wine** — [winehq.org](https://winehq.org) (via Madeira) — LGPL-2.1-or-later
- **FEX-Emu** — [github.com/FEX-Emu/FEX](https://github.com/FEX-Emu/FEX) — MIT
- **DXMT** — [github.com/3Shain/dxmt](https://github.com/3Shain/dxmt) — MIT (see upstream)

Full details in [LICENSE-NOTICE.md](LICENSE-NOTICE.md).

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening issues or pull requests.

## Security

Report vulnerabilities privately — see [SECURITY.md](SECURITY.md).

## License

GameHub-iOS is an original, clean-room application licensed under **GPL-3.0-or-later**
(see [LICENSE](LICENSE)). It contains no proprietary Android GameHub code or assets.
Bundled or embedded runtime components (Madeira/Wine/FEX/DXMT) carry their own
licenses and impose the corresponding source-offering obligations when distributed —
see [LICENSE-NOTICE.md](LICENSE-NOTICE.md).