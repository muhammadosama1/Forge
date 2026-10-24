# Forge

**Forge** is a lightweight, opinionated Swift CLI for scaffolding production-ready SwiftUI features in Xcode projects and Swift packages. 

It generates clean, testable architectural patterns with a single command—supporting standalone presentation styles, Clean Architecture layers, functional UI categories, and automated test scaffolds.

---

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

### 2. Layer Modifiers
* **`-clean`, `--clean`**: Adds **Domain** (`Entity`, `UseCase`, `Repository`) and **Data** (`RepositoryImpl`, `RemoteDataSource`, `Models`) layers.
* **`--no-clean`**: Omits Clean Architecture layers (overrides `.forge.yml`).
* **`--no-domain`**: Generates the **Data** layer while omitting the **Domain** layer (implies Clean Architecture).

### 3. UI Categories *(optional, pick one)*
Customize generated Views and State handlers with functional UI logic instead of empty placeholders:

* **`-form`**: Form layout with two-way `@Published` bindings (`TextField` inputs), keyboard-ready layout, and a `submit()` action.
* **`-list`**: Dynamic `List` bound to a stable `Identifiable` item collection, integrated with async lifecycle loading (`.task`).

### 4. Project & Packaging Options
* **`--path <dir>`**: Target project root directory (default: current working directory or `paths.root` in `.forge.yml`).
* **`--config <path>`**: Path to a specific `.forge.yml` configuration file.
* **`--package`**: Scaffolds the feature as an independent Swift Package with its own `Package.swift`.
* **`--target <name>`**: Routes files into `Sources/<Target>/<Feature>` and `Tests/<Target>Tests/<Feature>` in existing multi-target packages.
* **`--tests`**: Automatically generates matching unit test suites (`XCTestCase`, UseCase mocks).
* **`--no-tests`**: Skips test generation (overrides `.forge.yml`).

---

## ⚙️ Project Configuration (`.forge.yml`)

Commit a `.forge.yml` file to the root of your repository to establish and enforce team-wide conventions. When present, running `forge make <Feature>` automatically adopts your team's architecture, naming, paths, and flags without manual flags or terminal prompts.

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
#   root: Sources/Features  # Default target directory relative to repo root
#   package: false          # Scaffold as independent Swift Packages
#   target: FeatureKit      # Default target in multi-target packages

naming:
  type_prefix: ""         # e.g., "App" -> AppLoginView
  type_suffix: ""         # e.g., "Feature" -> LoginFeatureView
  folder_prefix: ""       # e.g., "Feature" -> FeatureLogin/
  folder_suffix: ""       # e.g., "Module" -> LoginModule/
  strip_redundant_suffix: true  # Prevent 'LoginFeatureFeature' when suffix is 'Feature'
  strip_redundant_prefix: true  # Prevent 'AppAppLogin' when prefix is 'App'
```

### State Binding Options (`binding`)
* **`combine`** *(default)*: Generates reactive bindings using Apple's Combine framework (`ObservableObject`, `@Published`, `@StateObject`). Target platforms: iOS 15+, macOS 12+.
* **`concurrency`** *(aliases: `swift-concurrency`, `observation`)*: Generates modern Swift Concurrency bindings using Apple's Observation framework (`@Observable`, `@State`, `@Bindable`). Target platforms: iOS 17+, macOS 14+.

### Testing Framework Options (`testing`)
* **`xctest`** *(default)*: Generates unit test suites using Apple's traditional XCTest framework (`import XCTest`, `XCTestCase`, `XCTAssertEqual`).
* **`swift-testing`** *(aliases: `swift-test`, `testing`)*: Generates unit test suites using Apple's modern Swift Testing framework (`import Testing`, `@Suite`, `@Test`, `#expect`). Target platforms: iOS 16+, macOS 13+.

### Dependency Injection Options (`di`)
* **`native`** *(default)*: Generates self-contained static factory containers (`enum FeatureDependencyContainer`) with pure Swift composition without external dependencies.
* **`factory`** *(aliases: `factory-di`)*: Integrates Michael Long's [Factory](https://github.com/hmlongco/Factory) library. Generates `extension Container` with typed registrations (`var featureView: Factory<...>`, etc.) while preserving static factory helpers (`FeatureDependencyContainer.makeView()`, `FeatureDependencyContainer.makeViewModel()`) that delegate to `Container.shared`. Automatically declares Factory package and target dependencies in generated standalone Swift packages (`Package.swift`).

CLI flags always take precedence over `.forge.yml`, allowing developers to override standards on demand (e.g. `forge make SpecialScreen -viper --no-tests`, `forge make Profile --no-clean`, or `forge make Settings --domain`).

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

Generated tests import `FeatureKit`, while feature types retain the `Profile` prefix. For an existing package, `--target` writes tests under `Tests/<Target>Tests/<Feature>`; its manifest must already declare the corresponding test target. For files added directly to an Xcode app, set the generated test import to the app's module name and add the files to the appropriate targets.

### Verifying generated code

The repository tests check parsing, rendering, and file generation. The generated-code check additionally builds and runs the emitted XCTest suites, including SwiftUI previews:

```sh
swift test
python3 Scripts/verify-generated.py
# Check one architecture while editing its templates:
python3 Scripts/verify-generated.py --architecture mvi
```

Run these checks on macOS with Swift 6.2 or newer and Python 3. The generated-code matrix covers MVVM, MVI, VIPER, VIP, and MVP across default/form/list views and standalone/Clean/no-domain layers (45 combinations). Every package uses a target name different from its feature name to verify module imports.

---

## 🌟 Best Practices Built-In

Every generated feature conforms to modern Swift & iOS conventions:
* **Swift Concurrency**: Fully annotated with `@MainActor` for thread-safe UI updates and `.task` modifiers for cancellation-aware async loads.
* **Clean Layer Boundaries**: Domain and Data layers remain 100% UI-framework agnostic (zero `SwiftUI` imports).
* **Unidirectional Data Flow**: State properties use `@Published private(set)` to protect state encapsulation.
* **Stable Identity**: List item models declare stable identifiers (`let id: UUID`), preventing SwiftUI list diffing and animation glitches.
* **Dependency Inversion**: UseCases interact strictly with protocol abstractions for effortless mocking and unit testing.
* **Header Metadata**: Automatically includes author, project name, and creation date in standard Xcode header format.
