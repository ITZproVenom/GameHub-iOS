# GameHub-iOS Architecture

This document describes the design of GameHub-iOS at the time of writing. It is a
live document — update it whenever the structure or data flow changes materially.

## Overview

GameHub-iOS is a native **SwiftUI** app organized around **MVVM** with a thin
**service layer**. The architecture intentionally separates three concerns so the app
can evolve independently from the runtime it orchestrates:

1. **Library/product concerns** — games, artwork, metadata, persistence.
2. **Container concerns** — per-game Windows prefixes and their configuration.
3. **Runtime concerns** — launching Windows executables, capability & status reporting.

The app is written so that **no code outside the runtime layer ever assumes a
particular runtime is available**. The runtime may report `unavailable` without any
other system breaking — the UI simply surfaces that state.

## Directory layout

```
GameHub.xcodeproj          Xcode project (GameHub + GameHubTests targets)
GameHub/
  App/                     App entry point, AppState composition root
  Models/                  Codable domain models and enums
  Services/                Storage, Game, Container, Runtime, Input, Performance, Log
  Services/Runtime/        RuntimeProvider protocol + MadeiraRuntimeProvider
  Utilities/               Constants, extensions
  Resources/               Info.plist, asset catalogs
  ViewModels/              Per-screen observable state + actions
  Views/                   SwiftUI views (screens and components)
GameHubTests/              Unit test targets
assets/                    Branding (logo)
docs/                      Design documentation
Scripts/                   Runtime bootstrap + integration notes
.github/workflows/         CI
```

## Composition root (`App/`)

`GameHubApp` is the `@main` entry point. Its `AppState` is a single composition root
that constructs the shared services and view models, owns the settings persistence
lifecycle, and is exposed to the view tree through SwiftUI's environment:

- `EnvironmentObject` for app-wide state
- `Environment` for services the low-level views need directly (e.g. the runtime
  service used by the game detail screen)

Dependency direction is one-way: **views read view models, view models use services,
services own storage and the outside world.** Nothing reaches back up.

## Data model (`Models/`)

All persisted models are `Codable` structs so the store layer stays trivial and
future-proof:

- `Game` — imported executable metadata, artwork reference, last-played, favorites.
- `Container` — per-game prefix: architecture, Windows version, resolution, graphics /
  audio / input settings, DXVK/DXMT toggles, environment variables, launch arguments,
  and a `ContainerStatus`.
- `RuntimeConfig` — defaults used when creating a container.
- `AppSettings` — provider selection, default architecture, import behavior.
- `WindowsArchitecture` — the CPU/iOS-family/ABI the container targets.

Models carry no behavior; all logic lives in services and view models.

## Persistence (`Services/StorageService.swift`)

A single, synchronous, actor-sound storage class:

- Resolves a configurable base directory (Application Support by default; injectable
  for tests).
- Persists each collection as JSON files (`games.json`, `containers.json`,
  `settings.json`, `logs.json`).
- Exposes atomic read/load/write operations with deterministic error handling.

Because storage is synchronous and injected, every service can be unit-tested against
a temp directory without touching the real filesystem.

## Services

- **GameService** (`@MainActor`) — CRUD for the library, cover-artwork caching, and
  the launch entry point for a game.
- **ContainerService** (`@MainActor`) — create, load, reset, duplicate-check, delete
  and re-query container state; owns the containers collection.
- **RuntimeService** (`actor`) — wraps the currently selected `RuntimeProvider`;
  surfaces `approvalStatus` (e.g. whether the OS image is approved) and the active
  provider's availability. Its state is synchronous to query, so consumers `await`
  once at entry.
- **InputService** — `GameController` monitoring (gamepads, keyboard, mouse) with
  connection-change notifications and wrapper-class haptics.
- **PerformanceService** — `CADisplayLink`-driven sampler reporting FPS, frame time,
  CPU usage and resident memory via mach APIs. Reports `0`/`nil` when a metric is
  unavailable rather than fabricating numbers.
- **LogService** — persistent, filterable log store with text export.

## Runtime abstraction (`Services/Runtime/`)

The runtime must never be a hard dependency of the app's features. That is the job of
the `RuntimeProvider` protocol:

```
protocol RuntimeProvider {
    var displayName: String { get }
    var available: Bool { get }
    var capabilities: [RuntimeCapability] { get }
    var status: RuntimeStatus { get }
    func launch(_ game: Game, container: Container) async -> LaunchResult
    func updateRuntime(...) // as implemented
}
```

- `RuntimeCapability` flags features (including `.jitCompilation`) so the UI can show
  what the active provider supports without knowing its internals.
- `RuntimeStatus` carries an honest availability state and a human-readable reason.
- `LaunchResult` distinguishes success from every meaningful failure, cascading
  through runtime-not-installed → runtime-unavailable → container-error, so the app
  never claims a launch happened when it did not.

`MadeiraRuntimeProvider` is the one provider implemented today. It does **not**
pretend to run. It reports:

- `available == false` and an explanatory status when the bundled runtime binaries are
  absent (which is the case in a fresh checkout), and
- its capability set so the UI can pre-emptively communicate JIT/CPU requirements.

Staging the upstream source is a build-time step owned by
`Scripts/bootstrap-madeira.sh`; see `Scripts/MADEIRA-INTEGRATION.md`. The provider
will be extended to shell out to the real Wine-backed launch pipeline once binaries
are bundled.

## ViewModels

View models own the observable state of a screen and translate service calls into
user-facing results.

- **LibraryViewModel** — game collection, search, ordering, favorite toggle, artwork
  cache population, import/settings/detail navigation, and the play action (which
  `await`s the runtime provider, maps `LaunchResult` to messages, and never fakes a
  successful launch).
- **GameDetailViewModel** — loads/saves game + container config.
- **ImportViewModel** — wraps the document picker: security-scoped URL handling,
  extension validation (`.exe`/`.msi`/`.bat`/`.cmd`), file copy into library storage,
  `Game`/container creation, error surfacing.
- **ContainerViewModel** — edits a container's fields and toggles; persists on change.
- **SettingsViewModel** — app settings read/write.

## Views

Views are declarative and stateless where possible:

- `ContentView` hosts the `NavigationStack`, environment wiring and top-level sheets/
  alerts.
- `LibraryView` — grid + searchable + sort/filter menus + empty state; navigates via
  `.navigationDestination(item:)` to the game detail.
- `GameDetailView` / `ContainerDetailView` — configuration editor for a game and its
  container, driven by `ContainerViewModel`.
- `ImportView` — system document picker sheet.
- `SettingsView` / `RuntimeStatusView` / `LogsView` — provider status, settings, logs.

## Concurrency & threading

- Services that mutate user-visible collections run on the main actor.
- `RuntimeService` is an `actor`: its state reads are serialized, and view models
  `await` once on entry rather than holding synchronous assumptions.
- Storage is a synchronous class used by main-actor services; long-running future
  work (runtime launch) will move to background tasks while staying actor-isolated.

## Testing

`GameHubTests` uses XCTest and covers the non-UI surface:

- Persistence — round-tripping and error cases against a temp base dir.
- Import validation — extension gating, discovery, copy + Game/container creation.
- Containers — create/duplicate/state/reset/delete and JSON persistence.
- Settings — load/save defaults and toggles.
- Runtime — honest `unavailable` reporting, capability set, and `LaunchResult`
  mapping (including runtime-not-installed).

Run with `⌘ U` in Xcode or via `.github/workflows/ios.yml`.

## CI

`.github/workflows/ios.yml` runs on `macos-14`:

1. `xcode-select` the shipped Xcode.
2. Build the debug app for the iOS Simulator (this is the compile gate).
3. Run the unit tests.
4. Archive a generic iOS (device) build with code signing disabled and package an
   unsigned IPA for manual sideloading/testing.
5. Upload artifacts, plus system logs on failure.

CI is the definitive compile check for this repository, since day-to-day development
may happen without a local Xcode toolchain.