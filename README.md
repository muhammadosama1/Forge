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

# The Composable Architecture (TCA) inside a Swift Package target
forge make Orders -tca --path /path/to/MyPackage --target AppFeaturesKit
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
| `-tca` | **The Composable Architecture** | `Feature` (Reducer + ObservableState), `View` |
| `-mvi` | **Model-View-Intent** | `View`, `Store`, `State`, `Intent`, `Reducer`, `DependencyContainer` |
| `-viper` | **VIPER** | `View`, `Presenter`, `Interactor`, `Router`, `Entity`, `Contracts`, `DependencyContainer` |
| `-vip` | **Clean Swift (VIP)** | `View`, `Interactor`, `Presenter`, `Worker`, `PresentationModels`, `DependencyContainer` |
| `-mvp` | **Model-View-Presenter** | `View`, `Presenter`, `Model`, `DependencyContainer` |

### 2. Layer Modifiers
* **`-clean`, `--clean`**: Adds **Domain** (`Entity`, `UseCase`, `Repository`) and **Data** (`RepositoryImpl`, `RemoteDataSource`, `Models`) layers.
* **`--no-domain`**: Generates the **Data** layer while omitting the **Domain** layer (implies Clean Architecture).

### 3. UI Categories *(optional, pick one)*
Customize generated Views and State handlers with functional UI logic instead of empty placeholders:

* **`-form`**: Form layout with two-way `@Published` bindings (`TextField` inputs), keyboard-ready layout, and a `submit()` action.
* **`-list`**: Dynamic `List` bound to a stable `Identifiable` item collection, integrated with async lifecycle loading (`.task`).

### 4. Project & Packaging Options
* **`--path <dir>`**: Target project root directory (default: current working directory).
* **`--package`**: Scaffolds the feature as an independent Swift Package with its own `Package.swift`.
* **`--target <name>`**: Routes files into `Sources/<Target>/<Feature>` and `Tests/<Target>Tests/<Feature>` in existing multi-target packages.
* **`--tests`**: Automatically generates matching unit test suites (`XCTestCase`, `TestStore` for TCA, UseCase mocks).

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

### Standalone TCA (`forge make Orders -tca`)
```text
Orders/
└── Presentation/
    ├── OrdersFeature.swift
    └── OrdersView.swift
```

### With Tests (`--tests`)
Creates isolated unit tests matching the architecture (e.g. `ProfileViewModelTests.swift`, `ProfileUseCaseTests.swift` with mock repositories, or `ProfileFeatureTests.swift` with TCA's `TestStore`).

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

Run these checks on macOS with Swift 6.2 or newer and Python 3. The generated-code matrix covers MVVM, MVI, VIPER, VIP, and MVP across default/form/list views and standalone/Clean/no-domain layers (45 combinations). Every package uses a target name different from its feature name to verify module imports. TCA is outside this matrix because its external dependency setup is not covered by the generated package manifest.

---

## 🌟 Best Practices Built-In

Every generated feature conforms to modern Swift & iOS conventions:
* **Swift Concurrency**: Fully annotated with `@MainActor` for thread-safe UI updates and `.task` modifiers for cancellation-aware async loads.
* **Clean Layer Boundaries**: Domain and Data layers remain 100% UI-framework agnostic (zero `SwiftUI` imports).
* **Unidirectional Data Flow**: State properties use `@Published private(set)` (or TCA `@ObservableState`) to protect state encapsulation.
* **Stable Identity**: List item models declare stable identifiers (`let id: UUID`), preventing SwiftUI list diffing and animation glitches.
* **Dependency Inversion**: UseCases interact strictly with protocol abstractions for effortless mocking and unit testing.
* **Header Metadata**: Automatically includes author, project name, and creation date in standard Xcode header format.
