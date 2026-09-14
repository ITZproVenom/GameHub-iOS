# Contributing to GameHub-iOS

Thanks for your interest in helping. This document explains how to contribute
effectively and respectfully.

## Code of conduct

This project uses the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you agree to abide by it. (If no CODE_OF_CONDUCT.md is present
yet, the contributor covenant terms still apply by expectation — be respectful.)

## Development setup

1. Clone the repository
2. Open `GameHub.xcodeproj` in Xcode 15+
3. Build the **GameHub** scheme (target iOS 17+ simulator or device)
4. Run unit tests (`⌘ U`, **GameHubTests** target)

## Getting started

- Check existing [Issues](https://github.com/ITZproVenom/GameHub-iOS/issues) for
  open bugs or roadmap tasks.
- If something is not tracked, open an issue first describing what you want to do,
  especially for non-trivial changes or new features.

## Making a change

- Keep changes focused: one logical change per pull request.
- Maintain the existing code style: Swift APIs, MVVM, SwiftUI conventions.
- Write or update unit tests where the change touches business logic or persistence.
- Run the test suite before opening your pull request.
- Avoid adding external dependencies unless absolutely necessary — discuss in the
  issue first.
- Do not commit binary artifacts, Xcode state (`xcuserdata`), or build products
  (these are covered by `.gitignore`).

## Commit messages

Use a descriptive prefix conventionally:

- `feat:` new feature or significant behavior change
- `fix:` bug fix
- `refactor:` internal restructuring without behavior change
- `docs:` documentation-only changes
- `test:` adding or updating tests
- `chore:` tooling, CI, dependency updates

Keep messages concise and explain *why* if the motivation isn't obvious.

## Pull requests

1. Fork the repository (or create a branch on the main repo if you have access).
2. Create a topic branch from `main`.
3. Make your changes, commit with a descriptive message, and push.
4. Open a pull request with a summary of the change and a link to the related issue.
5. CI must pass before a merge is considered.
6. Be responsive to review feedback.

## Runtime considerations

GameHub-iOS integrates with the [Madeira](https://github.com/willfaust/Madeira)
runtime stack (GPL-3.0-or-later). Changes that touch runtime integration, launch
flow, or the runtime provider interface need special care:

- Do not fabricate runtime results for testing.
- Do not claim features are implemented if the required runtime binaries are absent.
- Runtime-related changes may require sign-off from a maintainer before merge.

## Licensing

By submitting a contribution, you agree that your work will be licensed under
GPL-3.0-or-later, consistent with the repository license. You must have the right
to submit anything you contribute.