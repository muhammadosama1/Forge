# Changelog

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
