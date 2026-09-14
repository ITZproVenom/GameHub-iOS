GameHub-iOS
===========

GameHub-iOS is an original SwiftUI application that manages a library of
imported Windows executables and orchestrates an iOS-compatible Windows runtime.

This repository does **not** redistribute proprietary Android GameHub code,
assets, or trademarks. GameHub-iOS is clean-room software written from scratch.

Runtime integration
-------------------

GameHub-iOS targets the **Madeira** project as its runtime foundation:

- Repo: https://github.com/willfaust/Madeira
- Pinned commit: `97e2ce26e6dc9e4a38976f3b5deb9272d64558eb`
- License: GPL-3.0-or-later

The Madeira source is used solely as an external dependency/integration target
and is declared under `Scripts/MADEIRA-INTEGRATION.md`. Until the runtime
binaries are compiled and bundled, GameHub-iOS truthfully reports the runtime as
unavailable.

Dependencies
------------

| Project      | Upstream URL                     | License          |
|--------------|----------------------------------|------------------|
| Madeira      | github.com/willfaust/Madeira     | GPL-3.0-or-later |
| Wine         | winehq.org (via Madeira)         | LGPL-2.1-or-later|
| FEX-Emu      | github.com/FEX-Emu/FEX           | MIT              |
| DXMT         | github.com/3Shain/dxmt           | MIT (see upstream)|

When GameHub-iOS is distributed, it must comply with the GPL-3.0-or-later
obligations of Madeira (and Wine's LGPL), including providing corresponding
source and license notices for any bundled runtime components.

Third-party notice
------------------

The name "GameHub" is used descriptively for this reimplementation concept and
is inspired by an Android project. No proprietary Android source or assets are
copied into this repository.