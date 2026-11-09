# Repository Guidelines

## Project Structure & Module Organization

Forge is a Swift 6.2 command-line tool built with Swift Package Manager. Application code lives in `Sources/forge/`; `Models/`, `Config/`, and `Templates/` hold the core types, `.forge.yml` handling, and generated-code templates. Unit tests are in `Tests/forgeTests/`. `Scripts/verify-generated.py` builds generated feature combinations, and `.github/workflows/` contains CI automation. `Makefile` provides release builds and installation. Do not edit `.build/` or generated verification output as source.

## Build, Test, and Development Commands

- `swift build` builds the executable in debug mode.
- `swift run forge --help` runs the CLI from the package checkout.
- `swift test` runs the Swift test suite.
- `make build` updates the git-derived version when needed and builds in release mode.
- `python3 Scripts/verify-generated.py` verifies generated code across supported architectures and layouts; pass `--architecture mvi` to limit the matrix.
- `make install INSTALL_DIR="$HOME/.local/bin"` installs the release binary to a chosen directory.

Run Swift and generated-code checks on macOS with Swift 6.2 or newer; the verification script also needs Python 3.

## Coding Style & Naming Conventions

Follow the surrounding Swift style: four-space indentation, `UpperCamelCase` for types, and `lowerCamelCase` for properties and functions. Keep CLI parsing, configuration, models, and rendering responsibilities in their existing areas. Name tests after the behavior or type they cover (for example, `ProjectConfigTests.swift`). Generated output should follow the naming and formatting conventions encoded in `Sources/forge/Templates/`.

## Testing Guidelines

Add or update XCTest coverage in `Tests/forgeTests/` for behavior changes, especially CLI options, configuration precedence, and template output. Run `swift test` for package changes. If generated source or templates change, also run `python3 Scripts/verify-generated.py`; this compiles generated packages and executes their tests.

## Commit & Pull Request Guidelines

Recent history uses short, imperative subjects, often with Conventional Commit prefixes such as `feat:`, `fix:`, `test:`, `docs:`, and `chore:`. Keep changes focused and subjects concise. Pull requests should explain the behavior and rationale, link related issues when available, list the checks run, and include CLI examples or generated-output screenshots when they clarify user-facing changes.

## Configuration & Generated Files

The CLI can read or create `.forge.yml`; keep examples and defaults consistent with `README.md` and configuration tests. `Sources/forge/Version.swift` is maintained by `make generate-version`, so avoid hand-editing its version value.
