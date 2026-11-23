# Local templates

## Editable stacks

Run `forge init` in the project root and choose MVVM, MVI, VIPER, VIP, or MVP. Forge creates `.forge.yml` and the selected architecture's templates in a sibling `.templates/` directory. For scripts, use an architecture flag such as `forge init -mvvm`. Commit both paths. Generate a feature immediately with `forge make Profile -form`.

Existing projects can run setup with their configured architecture. If the project already has overrides under `.forge/templates/`, run `forge init --adopt` to activate editable stacks and keep the legacy files available for reference. Port any team edits to the new templates. Running setup again in an initialized project points to validation and preserves your edits.

### Add files to your stack

Add the following roles under the existing `stack.files` mapping and place the referenced files in `.templates/`.

```yaml
    coordinator:
      template: coordinator.swift.stencil
      output: "Navigation/{{ name }}Coordinator.swift"
      target: source
    teamTests:
      template: teamTests.swift.stencil
      output: "Team/{{ name }}TeamTests.swift"
      target: test
```

Built-in roles accept a `template` path and retain their standard Swift destination and target. Team roles use relative `.swift` output paths beneath the feature's source or test destination. Output paths accept `{{ name }}` and `{{ propertyName }}`. Test roles are included when generation enables tests. Set individual keys under `stack.categories` to `false` to disable `default`, `form`, or `list`. The stack's architecture is the top-level `architecture` setting. For a separate stack, select a different configuration with `--config`.

### Preserve form and list behavior

Keep the active insertion points when editing templates. The same ViewModel or store template is used for all categories.

| Template | Insertion points |
|---|---|
| MVVM ViewModel | `forge.viewModelProperties`, `forge.viewModelInitializers`, and `forge.viewModelActions` inside the class. Keep `forge.viewModelTypes` after it. |
| MVI store | `forge.storeProperties`, `forge.storeInitializers`, and `forge.storeActions` inside the class. Keep `forge.storeTypes` after it. |
| MVVM or MVI form view | `forge.field1Binding` and `forge.field2Binding`, one per field. |
| MVVM or MVI list view | `forge.listItems` as the collection passed to the list. |

For example, change the default control to `ShopTextField(title: "Name", text: {{ forge.field1Binding }})`. The host target supplies `ShopTextField`. You can add team-owned properties, methods, and convenience initializers around the generated members. Update `dependencyContainer.swift.stencil` and any team preview/test construction paths when they need to supply a new dependency. The compiled MVVM example adds a coordinator to both the live dependency container and the isolated preview. It also supplies a custom text field and row, and connects a team operation through the Clean remote data source. Its tests use the generated factory to check dependency injection, submission, and list retry. [Generated package verification script](../Scripts/verify-generated.py)

To own the designated initializer, replace the `…Initializers` block with your own signature and body. For example, this MVVM initializer accepts a team dependency alongside the managed parameters.

```swift
    private let analytics: ShopAnalytics

    init(analytics: ShopAnalytics{{ forge.viewModelInitializerParametersAfterComma }}) {
        self.analytics = analytics
        {{ forge.viewModelInitializerAssignments }}
    }
```

Use `…InitializerParameters` without the comma when Forge supplies the first parameter. Both parameter insertion points expand to empty text when a variant has no managed parameters. The assignments block follows the indentation of its insertion point. Update the team’s live dependency container, previews, tests, and any convenience initializers when they need to supply a new required argument. Projects exported with the earlier `…Members` block can keep it or adopt the separate insertion points.

### Validate in CI

If a required insertion point is inside a branch Forge skips, the error identifies the template, insertion point, affected screen, and the controlling condition. Move the insertion point to a shared position when every screen needs it, or add it to the branch that runs for that screen. Duplicate insertion points report both active locations. Validation reports independent template errors together for each screen.

Run `forge validate` from the project, or pass `--config path/to/team.yml`. It checks every configured template path and renders each enabled category with the configured defaults offline. Use `forge make … --dry-run` to check any additional flag combinations you use. Treat the check as a rendering and wiring check. Swift compilation is the next gate for custom code. A CI job can generate sample features into a disposable checkout and run the host project’s normal Xcode build and tests. [Host CI workflow](WALKTHROUGH.md#adopt-the-stack-in-an-existing-ios-app)

For self-contained templates, use a temporary directory and compile a generated package.

```sh
fixture="$(mktemp -d)"
forge make ForgeSample -form --config .forge.yml --path "$fixture" --package --tests
swift test --package-path "$fixture/ForgeSample"
```

## Legacy overrides (contract v1)

Forge supports project-local overrides of individual built-in templates. The rest of the feature keeps using Forge's defaults. Overrides contain text, not executable scripts; Forge owns output filenames and destinations.

```sh
forge templates list
forge templates export mvvmListViewModel --path /path/to/project
forge make Feed -mvvm -list --path /path/to/project --dry-run
forge make Feed -mvvm -list --path /path/to/project
```

Export accepts a name with or without `.stencil`. It refuses to overwrite an existing override. `--config /path/to/team.yml` selects an explicit configuration; `--path` starts normal configuration discovery. Overrides live in `.forge/templates/` next to the selected configuration, even when `paths.root` or `--path` sends generated code elsewhere. Without configuration, overrides live under the output project root. Commit the directory, including its `contract-version` file containing `1`.

A generation uses an override only when its exact template name matches a selected built-in template. For example, `mvvmListViewModel.stencil` and `cleanMvvmListViewModel.stencil` are different templates. `forge templates list` is the authoritative list. Exporting does not copy other templates. Delete an override to restore the built-in implementation.

## Syntax and values

Supported syntax is deliberately smaller than the Stencil language:

- `{{ name }}` or `{{name}}` substitutes a value. Whitespace around the key is allowed.
- `{% if isList %}...{% else %}...{% endif %}` supports nested boolean branches; `else` is optional.
- Loops, filters, expressions, includes, scripts, and remote templates are unsupported.

Unknown values (including in inactive branches), malformed tags, unbalanced branches, unreadable overrides, and incompatible contract versions stop generation before any feature files are written. Symlinks to template files outside the template directory are rejected. Template values are inserted as text and are not parsed again as template syntax.

Feature source and test templates receive:

| Value | Meaning |
|---|---|
| `name` | Feature Swift type prefix after naming rules |
| `propertyName` | Feature property prefix |
| `moduleName` | Importable target module; Xcode resolves it when generating tests |
| `isClean`, `hasNoDomain` | Layer selection |
| `isMVVM`, `isMVI`, `isVIPER`, `isVIP`, `isMVP` | Selected presentation architecture |
| `isForm`, `isList` | UI category, both false for the default view |
| `isConcurrency`, `isSwiftTesting`, `isFactory`, `isPackage` | Selected integration options |
| `hasView`, `hasViewModel`, `hasPresenter`, `hasInteractor`, `hasRouter`, `hasStore`, `hasUseCase`, `hasRepository`, `hasRemoteDataSource`, `hasWorker`, `hasDependencyContainer` | Selected source roles |

All known boolean keys default to false. `hasTests` describes the standalone package manifest's test target; it is not a source-selection flag.

The default file header contains only the filename. A custom `fileHeader.stencil` receives `fileName`, `projectName`, `authorName`, and `createdDate`. `swiftPackage.stencil` receives `name` (the package target name), `hasTests`, `isConcurrency`, `isSwiftTesting`, and `isFactory`. Do not use feature-only string values in these infrastructure templates.

## Compatibility and responsibility

The contract version describes syntax and context, not a guarantee that arbitrary Swift overrides compile. The team owns the resulting Swift interfaces, preview construction, and tests. If you replace a dependency container, preserve the built-in view construction methods, the isolated `NamePreview` helpers used by previews/tests, and the `NameFeature.makeView()` public entry point for package output.

Forge validates rendering and destinations, but does not typecheck custom templates on every invocation. Build and test a generated fixture with your supported configuration combinations in CI. Keep your Forge version pinned; review exported built-ins when upgrading. A contract change requires explicit migration rather than silently rewriting overrides.

## Dry runs

Generation and dry-run summaries show paths relative to the configuration directory, or the selected project directory when there is no configuration.

`forge make ... --dry-run` resolves configuration, renders selected templates, checks conflicts and supported project structure, and lists planned file/project/manifest changes. It never writes output, acquires a generation lock, runs `xcodebuild`, or resolves dependencies.

For Xcode tests, the final module name, Test Host, and testability checks are deferred until generation. The dry run says so explicitly. A dry run is an advisory plan against the current filesystem, not a reservation or compilation guarantee. Existing destination files still produce an error; Forge never overwrites or regenerates edited feature code.
