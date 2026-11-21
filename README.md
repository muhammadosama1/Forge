# Forge

**Forge** is a lightweight Swift CLI for scaffolding SwiftUI features in Xcode projects and Swift packages.

It generates clean, testable architectural patterns with a single command—supporting standalone presentation styles, optional Clean Architecture layers, connected MVVM/MVI list and form workflows, and automated test scaffolds.

---

For a complete example of generation, API wiring, tests, and template customization, see the [walkthrough](docs/WALKTHROUGH.md).

## ⚡️ Quick Start

```sh
# Generate Clean Architecture + MVVM feature
forge make Profile -mvvm -clean

# Standalone MVVM with a form layout
forge make Login -mvvm -form

# Clean Architecture + VIPER with automated tests
forge make Feed -viper -clean --tests
```

---

## 📥 Installation

### Homebrew (Recommended)
```sh
brew install muhammadosama1/forge/forge
```

### Build from Source
```sh
git clone https://github.com/muhammadosama1/forge.git
cd forge
make install
```
*Installs by default to `/usr/local/bin/forge`. Use `make install INSTALL_DIR="$HOME/.local/bin"` to customize.*

---

## 🛠 Command Reference

```text
forge make <FeatureName> [options]
```

### 1. Architecture Flags *(pick one)*
When omitted, Forge interactively prompts you to choose in the terminal.

| Flag | Pattern | Key Components Generated |
|---|---|---|
| `-mvvm` | **Model-View-ViewModel** | `View`, `ViewModel`, `DependencyContainer` |
| `-mvi` | **Model-View-Intent** | `View`, `Store`, `State`, `Intent`, `Reducer`, `DependencyContainer` |
| `-viper` | **VIPER** | `View`, `Presenter`, `Interactor`, `Router`, `Entity`, `Contracts`, `DependencyContainer` |
| `-vip` | **Clean Swift (VIP)** | `View`, `Interactor`, `Presenter`, `Worker`, `PresentationModels`, `DependencyContainer` |
| `-mvp` | **Model-View-Presenter** | `View`, `Presenter`, `Model`, `DependencyContainer` |

Forge v2.0 removes the `-tca` option. Existing TCA users should continue with a v1.x release or migrate to one of the patterns above.

### 2. Layer Modifiers
* **`-clean`, `--clean`**: Adds **Domain** (`Entity`, `UseCase`, `Repository`) and **Data** (`RepositoryImpl`, `RemoteDataSource`, `Models`) layers.
* **`--no-clean`**: Omits Clean Architecture layers (overrides `.forge.yml`).
* **`--no-domain`**: Generates the **Data** layer while omitting the **Domain** layer (implies Clean Architecture).

### 3. UI Categories *(optional, pick one)*
Choose a UI starting point. MVVM/MVI include injectable async operations, visible loading/submission and error state, cancellation handling, and retry support. VIPER/VIP/MVP retain simpler scaffold hooks:

* **`-form`**: Form layout with bound `TextField` inputs, keyboard-ready layout, and a `submit()` action. Bindings follow the configured state strategy.
* **`-list`**: Dynamic `List` connected to a stable `Identifiable` item collection, with async lifecycle loading (`.task`).

### 4. Project & Packaging Options
* **`--path <dir>`**: Target project root directory (default: current working directory or `paths.root` in `.forge.yml`).
* **`--config <path>`**: Path to a specific `.forge.yml` configuration file.
* **`--package`**: Scaffolds the feature as an independent Swift Package with its own `Package.swift`.
* **`--target <name>`**: Target names must start with an ASCII letter or underscore and contain only ASCII letters, digits, underscores, or hyphens; Swift reserved names are rejected. The same rules apply to `paths.target`. For an existing Swift package, Forge verifies the target in `Package.swift`, routes files into `Sources/<Target>/<Feature>`, adds a test target when `--tests` is used, and adds Factory package and target dependencies when `di: factory` is selected. Manifest updates require literal target and dependency arrays and the standard `Sources/<Target>` layout; unsupported manifests fail before feature files are written.
* **`--xcode-target <name>`**: Register generated Swift sources in an Xcode app target. With one `.xcodeproj` and one app target, Forge selects it automatically. For projects with multiple app targets, select one with `--xcode-target "My App"` or `paths.xcode_target`. Choose the project with `paths.xcode_project` or point `--path` at the directory containing the `.xcodeproj`.
* **`--xcode-test-target <name>`**: With tests enabled, select an existing app-hosted Xcode unit-test target. Forge automatically selects a unique match when possible. Automatic test registration requires full Xcode and an app build configuration with testability enabled.
* **`--dry-run`**: Preview resolved settings, output paths, and project/dependency changes without writing files or resolving dependencies. Xcode test module, host, and testability checks are deferred until generation.
* **`--files-only`**: Generate files under `paths.features` or the default output root for manual wiring, including projects with unusual Xcode layouts. For automatic integration of app sources only, use `--no-tests`.
* **`--tests`**: Automatically generates matching unit test suites (`XCTestCase`, UseCase mocks).
* **`--no-tests`**: Skips test generation (overrides `.forge.yml`).

---

## ⚙️ Project Configuration (`.forge.yml`)

Commit a `.forge.yml` file to the root of your repository to establish generation defaults for your team. Forge does not lint or enforce conventions in existing code. When present, running `forge make <Feature>` automatically adopts your team's architecture, naming, paths, and flags without manual flags or terminal prompts.

Generate a starter configuration with:

```sh
forge init
```

Example `.forge.yml`:

```yaml
# .forge.yml - Forge Team Standards
architecture: mvvm

# State binding mechanism: combine or concurrency (Observation framework)
binding: combine

# Unit testing framework: xctest or swift-testing
testing: xctest

# Dependency injection strategy: native or factory (Factory library)
di: native

flags:
  clean: false        # Include Clean Architecture layers (Domain + Data)
  no_domain: false    # Skip Domain layer files (implies clean)
  tests: false        # Generate unit test suites by default

# paths:
#   root: Sources/Features  # Output directory relative to repo root; use the package root with target
#   package: false          # Scaffold as independent Swift Packages
#   target: FeatureKit      # Default target in multi-target packages
#   xcode_project: MyApp.xcodeproj # Select the exact project independently of the output directory
#   features: Features      # Put generated features in this directory
#   xcode_target: "My App"   # Default Xcode app target
#   xcode_test_target: "My AppTests" # Default Xcode unit-test target when tests are enabled

naming:
  type_prefix: ""         # e.g., "App" -> AppLoginView
  type_suffix: ""         # e.g., "Feature" -> LoginFeatureView
  folder_prefix: ""       # e.g., "Feature" -> FeatureLogin/
  folder_suffix: ""       # e.g., "Module" -> LoginModule/
  strip_redundant_suffix: true  # Prevent 'LoginFeatureFeature' when suffix is 'Feature'
  strip_redundant_prefix: true  # Prevent 'AppAppLogin' when prefix is 'App'
```

### Local template customization and previewing changes

```sh
forge templates list
forge templates export mvvmListViewModel
# Edit .forge/templates/mvvmListViewModel.stencil, then:
forge make Feed -mvvm -list --dry-run
forge make Feed -mvvm -list
```

Overrides live beside the selected configuration; all other templates keep their built-in defaults. Export refuses to overwrite existing templates. Commit `.forge/templates/contract-version` with your overrides. Unknown variables and malformed template syntax fail before feature files are written. See the [template contract and dry-run limitations](docs/TEMPLATES.md).

### State Binding Options (`binding`)
* **`combine`** *(default)*: Generates reactive bindings using Apple's Combine framework (`ObservableObject`, `@Published`, `@StateObject`). Target platforms: iOS 15+, macOS 12+.
* **`concurrency`** *(aliases: `swift-concurrency`, `observation`)*: Generates modern Swift Concurrency bindings using Apple's Observation framework (`@Observable`, `@State`, `@Bindable`). Target platforms: iOS 17+, macOS 14+.

### Testing Framework Options (`testing`)
* **`xctest`** *(default)*: Generates unit test suites using Apple's traditional XCTest framework (`import XCTest`, `XCTestCase`, `XCTAssertEqual`).
* **`swift-testing`** *(aliases: `swift-test`, `testing`)*: Generates unit test suites using Apple's modern Swift Testing framework (`import Testing`, `@Suite`, `@Test`, `#expect`). Target platforms: iOS 16+, macOS 13+.

### Dependency Injection Options (`di`)
* **`native`** *(default)*: Generates self-contained static factory containers (`enum FeatureDependencyContainer`) with pure Swift composition without external dependencies.
* **`factory`** *(aliases: `factory-di`)*: Integrates Michael Long's [Factory](https://github.com/hmlongco/Factory) library. Generates `extension Container` with typed registrations (`var featureView: Factory<...>`, etc.) while preserving static factory helpers (`FeatureDependencyContainer.makeView()`, `FeatureDependencyContainer.makeViewModel()`) that delegate to `Container.shared`. Forge adds the `Factory` product to generated standalone Swift packages, supported existing Swift packages, and selected Xcode app targets. For a new dependency, Forge uses Factory 2.4.0 up to the next major version. For Xcode projects with an existing reference to the official Factory repository, Forge preserves its version requirement. Generated code uses the `Factory` product available in Factory 2.x.

If you generate Xcode tests before Xcode has resolved the newly added Factory dependency, Forge lets Xcode resolve it while reading the test target's build settings. Xcode may create or update `Package.resolved` during this step.

When `paths.target` is set for an existing package, `paths.root` must point to that package's root, where `Package.swift` lives.

Set `paths.xcode_target` to choose the default app target. Use `--xcode-target` to select another app target for one command.

CLI flags can override the matching defaults in `.forge.yml` (e.g. `forge make SpecialScreen -viper --no-tests`, `forge make Profile --no-clean`, or `forge make Settings --domain`).

### Xcode project and feature destination

```yaml
architecture: mvvm
paths:
  xcode_project: Apps/Store/Store.xcodeproj
  features: Apps/Store/Features
  xcode_target: Store App
```

Run `forge make Login --dry-run` from the repo root or a nested directory to preview the selected project, targets, and output paths. Relative paths resolve from the directory containing `.forge.yml`. This example generates into `Apps/Store/Features/Login` and registers the files with `Store App`.

`--path` starts configuration discovery and overrides `paths.root`. If `paths.xcode_project` or `paths.features` is set, that setting still controls project selection or feature placement, respectively. When only `paths.features` is set and neither `--path` nor `paths.root` is supplied, Forge looks for a single Xcode project beside the configuration. When only `paths.xcode_project` is set, the project's containing directory is the default output root. Swift package output uses its existing paths.

For automatic Xcode integration, the output must be within the directory containing the selected project. Forge uses Xcode's automatic membership when the configured destination is inside a synchronized folder belonging to the app target. Tests go in the test target's dedicated synchronized folder when present, or in the feature's `Tests` folder when it can be registered safely. For manual integration, use `--files-only`.

---

## 📂 Feature Structure Examples

### Clean Architecture + MVVM (`forge make Profile -clean`)
```text
Profile/
├── ProfileDependencyContainer.swift
├── Presentation/
│   ├── ProfileView.swift
│   └── ProfileViewModel.swift
├── Domain/
│   ├── ProfileEntity.swift
│   ├── ProfileUseCase.swift
│   └── ProfileRepository.swift
└── Data/
    ├── ProfileRepositoryImpl.swift
    ├── ProfileRemoteDataSource.swift
    └── ProfileModels.swift
```

### With Tests (`--tests`)
Creates isolated unit tests matching the architecture (e.g. `ProfileViewModelTests.swift`, `ProfileUseCaseTests.swift` with mock repositories).

When combined with `--package`, the generated manifest includes a test target. For example:

```sh
forge make Profile -mvvm -clean --package --tests --target FeatureKit
swift test --package-path Profile
```

A consuming app uses `import FeatureKit` and `ProfileFeature.makeView()`. The public factory returns `some View`; internal implementation types stay hidden. Customize the generated dependency container to supply your application services.

Generated tests import `FeatureKit`, while feature types retain the `Profile` prefix. For an existing package, `--target` writes tests under `Tests/<Target>Tests/<Feature>` and adds a matching test target to a supported manifest when needed.

For Xcode apps, Forge integrates generated tests with an existing app-hosted unit-test target and uses the app's resolved Swift module in `@testable import`. Run the tests using a scheme that already includes that unit-test target.

```sh
forge make Profile -mvvm --tests
forge make Settings -mvvm --tests --xcode-target "My App" --xcode-test-target "My AppTests"
```

Set `paths.xcode_test_target` for a shared default. The CLI flag overrides it. Use `--files-only --tests` for manual registration and set the generated test import to the app's module name.

For a target with one dedicated Xcode synchronized folder, Forge generates into `<SynchronizedFolder>/<Feature>` and Xcode handles membership automatically. For example, with separate `MyApp` and `MyAppTests` synchronized folders, the files go under `MyApp/Profile` and `MyAppTests/Profile`. A target using explicit file references keeps the standard layout of `<Feature>` for app sources or `<Feature>/Tests` for tests. Forge reports overlapping folders, ambiguous membership, or exceptions affecting generated files before writing output.

The Xcode smoke test runs XCTest and Swift Testing for both layouts. Build Forge with `swift build` and pass an available iOS Simulator ID from `xcrun simctl list devices available`:

```sh
python3 Scripts/xcode-smoke.py --forge .build/debug/forge \
  --destination 'platform=iOS Simulator,id=<simulator-id>'
```

### Connecting application behavior

MVVM/MVI forms pass `field1` and `field2` into an injectable async submission operation; rename them and supply your business validation. Standalone lists accept an async item loader and initially return an empty collection. Clean list examples map one use-case response to one item; adapt the response/use case for a real collection API.

Clean `RemoteDataSource` initializers accept fetch and submit closures. Their live defaults throw `URLError(.unsupportedURL)` until your API client is connected, rather than report fabricated success. Generated `NamePreview` helpers use explicit fixtures, bypass Factory globals, and never invoke the live container. Preview fixture constructors are for previews/tests only. MVVM/MVI category tests cover dependency invocation, retry, cancellation, and duplicate submission; domain-specific behavior still needs your tests.

These changes affect newly generated files only. Existing generated features are not rewritten. VIPER, VIP, and MVP remain supported, with simpler form hooks documented as unfinished business behavior.

### Verifying generated code

The repository tests check parsing, rendering, and file generation. The generated-code check additionally builds and runs the emitted XCTest suites, including SwiftUI previews:

```sh
swift test
python3 Scripts/verify-generated.py
# Check one architecture while editing its templates:
python3 Scripts/verify-generated.py --architecture mvi
```

A clean checkout supports `swift build` and `swift test` directly; `forge --version` reports `dev` until `make generate-version` stamps the git-derived version. `make build` performs this stamping automatically.

Configuration supports single-line quoted YAML strings, doubled single quotes (`'O''Brien'`), and double-quoted YAML escapes (including Unicode escapes). Malformed escapes, unterminated quotes, and multiline quoted strings are rejected with line numbers.

Run these checks on macOS with Swift 6.2 or newer and Python 3. The generated-code matrix covers MVVM, MVI, VIPER, VIP, and MVP across default/form/list views and standalone/Clean/no-domain layers (45 combinations). Every package uses a target name different from its feature name to verify module imports. A separate consumer builds with an ordinary import and calls the public feature factory. CI also covers representative Observation + Swift Testing + Factory configurations.

Before a release, run `make release-check VERSION=<version>` to test the release binary, user workflows, and generated-code matrices for default and advanced configurations. See [release instructions](docs/RELEASING.md).

---

## 🌟 Best Practices Built-In

Every generated feature conforms to modern Swift & iOS conventions:
* **Swift Concurrency**: Fully annotated with `@MainActor` for thread-safe UI updates and `.task` modifiers for cancellation-aware async loads.
* **Clean Layer Boundaries**: Domain and Data layers remain 100% UI-framework agnostic (zero `SwiftUI` imports).
* **Unidirectional Data Flow**: Generated state keeps writes inside the selected architecture component.
* **Stable Identity**: List item models declare stable identifiers (`let id: UUID`), preventing SwiftUI list diffing and animation glitches.
* **Dependency Inversion**: UseCases interact strictly with protocol abstractions for effortless mocking and unit testing.
* **Header Metadata**: Automatically includes author, project name, and creation date in standard Xcode header format.
