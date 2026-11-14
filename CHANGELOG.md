# Changelog

## Unreleased

### Added
- Register generated Swift sources with an existing Xcode app target. Forge selects a sole app target automatically, accepts a target from `--xcode-target` or `.forge.yml`, and supports `--files-only` for manual wiring.
- Register generated tests with an existing app-hosted Xcode unit-test target and import the app's resolved Swift module. Select a target with `--xcode-test-target` or `paths.xcode_test_target` when needed.

### Fixed
- Report actionable errors for missing or ambiguous targets, invalid configuration, missing architecture in scripts, and blocked output paths before writing feature files.

## [2.0.0] - 2026-11-09

### Added
- **Release readiness gate**: `make release-check VERSION=<version>` runs unit tests, release-binary user workflows, installation, and two 45-case generated-code matrices for default and advanced configurations before tagging.
- **Existing Swift Package integration**: `--target` now verifies a declared target, adds a matching test target when needed, and registers Factory in the existing package and target. Unsupported dynamic manifests and custom target paths fail before generated files are written.
- **Configurable Dependency Injection Strategy (`di: native | factory`)**: Choose between Forge's self-contained `native` static container or Michael Long's third-party [Factory](https://github.com/hmlongco/Factory) library (`di: factory`) in `.forge.yml`. When `factory` is selected, Forge generates `extension Container` property registrations, delegates `enum FeatureDependencyContainer` static factory methods to `Container.shared`, and automatically adds Factory package and target dependencies to generated `Package.swift` files. Defaults to `native` for backward compatibility.
- **Configurable Test Framework (`testing: xctest | swift-testing`)**: Select between Apple's traditional `XCTest` or modern `Swift Testing` (`import Testing`, `@Suite`, `@Test`, `#expect`) in `.forge.yml`. Defaults to `xctest` for backward compatibility.
- **Configurable State Binding Strategy (`binding: combine | concurrency`)**: Choose between traditional Apple Combine (`ObservableObject`, `@Published`, `@StateObject`) or modern Swift Concurrency & Observation (`@Observable`, `@State`, `@Bindable`, `import Observation`) in `.forge.yml`. Defaults to `combine` for backward compatibility.
- **Project Configuration (`.forge.yml`)**: Commit repository standards for default architecture, project flags (`clean`, `tests`, `no_domain`), output paths, and type/folder naming rules.
- **`forge init` Subcommand**: Quickly scaffold a starter `.forge.yml` file with team defaults and commented options.
- **Negative & Override Flags**: Added `--no-clean` and `--no-tests` to allow explicit overriding of `.forge.yml` standards from the CLI.

### Removed
- Removed support for The Composable Architecture (`-tca`).

### Fixed
- Reject invalid package target names before creating output and report malformed quoted YAML values with line numbers.
- Allow a clean checkout to build without a generated `Version.swift`; release builds still stamp the selected version.
- Count singular Swift Testing summaries correctly in the generated-code verification script.

## [1.1.1] - 2026-09-27

### Fixed
- Add the missing view factories used by generated MVI, VIPER, VIP, and MVP previews.
- Keep form/list state, actions, constructors, and tests consistent with the selected architecture and layers.
- Register generated Swift package test targets and import the selected module in test files.
- Place existing-package tests under `Tests/<Target>Tests` even when the `Tests` directory does not yet exist.

### Added
- A macOS regression matrix that builds and runs generated tests for 45 non-TCA feature combinations.

## [1.1.0] - 2026-09-18

### Added
- **UI Category Flags (`-form`, `-list`)**:
  - `-form`: Generates functional form views with two-way `@Published` field bindings, keyboard-friendly layout, and submit handling across all architectures.
  - `-list`: Generates dynamic `List` views connected to state collections with automatic async lifecycle loading (`.task`).
- **Comprehensive Automated Test Suite**:
  - Added 179 unit and best-practices audit tests in `Tests/forgeTests/ForgeTests.swift` covering CLI parsing, argument validation, file creation, layer routing, and Swift 6 concurrency patterns.
- **Enhanced Swift Package Target Routing**:
  - Support for `--target <name>` to place generated feature files within existing multi-target Swift package structures (`Sources/<Target>/<Feature>`).

### Changed
- **Streamlined Documentation**:
  - Redesigned `README.md` with an architecture comparison table, unified quick-start guide, and built-in best practices overview.
- **Simplified `FeatureFile.displayName`**:
  - Replaced verbose switch statements with direct capitalized raw values.
- **Improved Inline Code Comments**:
  - Added explanatory documentation across CLI command parsing, terminal raw-mode handling, template rendering, and file generation logic.

### Fixed
- **Stable Identity in List Item Structs**:
  - Fixed generated list item models across all architectures to use stable `let id: UUID` properties instead of inline default initialization, eliminating SwiftUI list diffing and animation glitches.
- **Cleaned Up TCA Scaffolding**:
  - Removed empty `DependencyContainer` boilerplate from Clean TCA templates in favor of idiomatic `@Dependency` usage.

## [1.0.0] - 2026-07-11

### Added

- MVVM, MVP, VIPER, VIP, TCA architecture support
- Clean Architecture layering
- Swift Package and folder output
- Dry-run mode
- Custom output path support
