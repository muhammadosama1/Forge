# Build a feature with Forge

This walkthrough creates a Clean MVVM feature in a standalone package and connects a sample API. Run it on macOS with Forge, Xcode, and Swift installed.

```sh
mkdir ForgeDemo && cd ForgeDemo
forge make Profile -mvvm -clean --package --tests --dry-run
forge make Profile -mvvm -clean --package --tests
swift test --package-path Profile
```

The dry run shows planned files without writing them. The generated package exposes `ProfileFeature.makeView()` to an importing app. The feature starts with an unconfigured live data source; previews and generated tests use isolated sample data.

## Connect the API

In `Profile/Sources/Profile/ProfileDependencyContainer.swift`, find the native container's `makeRemoteDataSource()` and replace its `ProfileRemoteDataSource()` return expression with:

```swift
ProfileRemoteDataSource(fetch: {
    let url = URL(string: "https://example.com/profile")!
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        throw URLError(.badServerResponse)
    }
    return try JSONDecoder().decode(ProfileResponse.self, from: data)
})
```

Add `import Foundation` to that file. Replace the example URL with your service. The generated response expects a JSON object with a UUID `id` and a string `title`; adapt `ProfileResponse` and its domain mapping to your API. This example demonstrates fetching only; form submission needs its own injected `submit` operation.

Run `swift test --package-path Profile` again. Generated tests exercise preview fixtures and repository behavior, so add tests for your API decoding and failure cases as you implement them. In an app that links the package, use `import Profile` and display `ProfileFeature.makeView()` from a SwiftUI view.

## Adapt conventions

To customize future generated ViewModels, export the built-in template:

```sh
forge templates export cleanMvvmViewModel --path .
forge make Settings -mvvm -clean --package --tests --dry-run
```

Edit `.forge/templates/cleanMvvmViewModel.stencil`, commit it with `contract-version`, and build generated examples after changes. Exports do not change already generated features. See [the template contract](TEMPLATES.md) for syntax and compatibility details.

For an existing app, point `--path` at the directory containing its `.xcodeproj`. Forge selects an unambiguous app target; use `--xcode-target` and `--xcode-test-target` when selection is ambiguous. Use `--files-only` for manual integration. See the [README](../README.md) for package and Xcode limitations.
