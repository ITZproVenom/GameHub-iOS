# Security policy

## Reporting a vulnerability

If you discover a security issue in GameHub-iOS, **do not open a public issue.**
Please report it privately by emailing the maintainer directly or using GitHub's
private vulnerability reporting feature on the Security tab.

When reporting, include:

- A description of the vulnerability and its potential impact.
- Steps to reproduce, if known.
- The version or commit hash you tested against.
- Any relevant logs or screenshots.

## Supported versions

Only the latest commit on `main` receives active development and security fixes.
The project is currently pre-alpha, so no released versions are supported in the
traditional sense — all work is tracked against `main`.

## Known risk areas

Because GameHub-iOS orchestrates the execution of imported Windows executables via
a Wine-based runtime, there are inherent trust and privilege considerations:

- **Imported executables are user-supplied code.** Running them on-device carries
  whatever risk the executable itself carries. The app does not validate or sandbox
  executables beyond file-type checks at import time.
- **JIT / code generation.** If a runtime provider uses JIT compilation, the process
  may be running with elevated memory protection capabilities. Ensure these
  requirements are reviewed in `RuntimeProvider` and `RuntimeCapability` before
  enabling them.
- **No secrets or keys in source.** The repository should never contain API keys,
  signing credentials, or other secrets. All tokens, certificates and credentials
  must remain outside the repository and the filesystem managed by the app.

## Responsible disclosure

We appreciate coordinated disclosure. Please allow a reasonable window (90 days is
typical) for a fix to be prepared before public disclosure. We will credit
reporters in the release notes unless anonymity is preferred.