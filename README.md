# GameHub-iOS

A native iOS (SwiftUI) game library app for managing imported Windows
executables, built to integrate a Wine/FEX/DXMT runtime on iPhone/iPad.

> **Status:** Foundation + architecture complete. `.exe` import, library,
> per-game settings, containers, runtime abstraction, input, performance and
> logging are implemented. Actual Windows execution requires compiling and
> bundling the **Madeira** runtime (see below) — until then the runtime layer
> truthfully reports unavailable.

## Features

- **Library grid** — artwork, titles, last played, favorites, search, sorting,
  filtering, empty state, context menus, materials and animations.
- **Import** — native document picker (`.exe`, `.msi`, `.bat`, `.cmd`), copies
  the file into app-managed storage, creates a `Game`, and creates a container.
- **Containers** — real per-game Windows prefix with persisted config:
  architecture, runtime version, resolution, graphics/audio/input settings,
  DXVK/DXMT toggles, environment variables, launch arguments.
- **Runtime abstraction** — `RuntimeProvider` protocol + `MadeiraRuntimeProvider`
  with honest capability/state reporting. JIT requirements isolated.
- **Input** — `GameController`-based `InputService` (gamepads, keyboard, mouse).
- **Performance** — `PerformanceMonitor` (FPS, frame time, CPU, memory) via
  `CADisplayLink`; no fabricated metrics.
- **Logs** — persistent, filterable log store.
- **Settings** — runtime provider, architecture defaults, import behavior.

## Architecture

```
MVVM + services

GameHub/App        App entry point + AppState composition root
GameHub/Models     Game, Container, RuntimeConfig, AppSettings, enums
GameHub/Services   Storage, Game, Container, Runtime, Input, Performance, Log
                   Services/Runtime: RuntimeProvider protocol + MadeiraRuntimeProvider
GameHub/ViewModels Library, GameDetail, Import, Container, Settings
GameHub/Views      SwiftUI screens (Library, Import, Detail, Container, Settings)
GameHub/Utilities  Constants, extensions
```

Data persists as JSON under `Application Support/GameHubData`.

## Runtime (Madeira)

Target pipeline: `.exe → Wine (ARM64EC) → FEX x86-64→ARM64 → DXMT D3D11→Metal → iOS`.

- Upstream: [willfaust/Madeira](https://github.com/willfaust/Madeira)
- Pinned: `97e2ce26e6dc9e4a38976f3b5deb9272d64558eb` (GPL-3.0-or-later)
- Stage the pinned source: `Scripts/bootstrap-madeira.sh`
- Details & integration plan: `Scripts/MADEIRA-INTEGRATION.md`
- Licensing obligations: `LICENSE-NOTICE.md`

The app does **not** fake execution. Until runtime binaries are bundled, launch
returns explicit "runtime not installed" states.

## Build

Open `GameHub.xcodeproj` in Xcode 15+ (iOS deployment target 17.0).

### CI

`.github/workflows/ios.yml` builds the simulator app, runs unit tests, and
archives an unsigned IPA on macOS.

## Tests

`GameHubTests` covers persistence, import validation, containers, settings and
runtime capability/launch validation.

## License

This repository is licensed under GPL-3.0-or-later (see `LICENSE`). It contains
no proprietary Android GameHub code or assets. Bundled/embedded runtime
components (Madeira/Wine/FEX/DXMT) carry their own licenses — see
`LICENSE-NOTICE.md`.