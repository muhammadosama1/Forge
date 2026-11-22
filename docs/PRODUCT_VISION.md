# Forge product direction

## Purpose and audience

Forge reduces the repeated work between creating a SwiftUI feature and starting its business logic: connected source files, dependency wiring, useful tests, previews, and integration into an existing Xcode project or Swift package. Solo developers and engineers in teams have equal priority. The simple workflow uses built-in defaults; teams can commit conventions and override individual templates.

The product promise is: **Generate a SwiftUI feature that fits your project, builds, and comes with useful tests, using your conventions.** Forge does not infer business rules, endpoints, validation policy, navigation flows, or a whole application's architecture.

## Current implementation

- Five supported patterns: MVVM, MVI, VIPER, VIP, and MVP, with optional Clean/Data layers. Existing configuration and binding/testing/DI defaults remain compatible.
- Xcode source/test target registration, dedicated synchronized folders, Factory dependencies, standalone packages, and supported existing package manifests. Dynamic manifests, custom target paths, and ambiguous project layouts still require manual integration.
- A minimal public `NameFeature.makeView() -> some View` entry point for package output. Implementation types remain internal; generated code belongs to the developer.
- MVVM/MVI list and form operations with injectable async dependencies, loading/submission state, cancellation handling, retries, and duplicate-operation guards. Clean list examples map the existing single-response use case to one item; real collection endpoints and business validation remain developer-owned.
- Explicit preview fixtures that bypass live construction and Factory globals. Clean live data sources require the developer's API operation and fail explicitly when unconfigured.
- Generated tests for MVVM/MVI category behavior, repository/use-case boundaries, and selected legacy architecture behavior. VIPER/VIP/MVP form examples still contain submission hooks; these are scaffolds, not finished product features.
- `--dry-run` and local per-template overrides with strict rendering validation. See [template contract](TEMPLATES.md).
- Refusal to overwrite existing files, preflight conflict checks, coordinated writes, and rollback on supported failures. No regeneration of edited source.

## Final release plan

The final planned update before a development pause gives individuals working defaults and lets teams own those defaults in their repository. The commands and contracts in this section describe release requirements.

### Initialize once and customize later

1. On a fresh project, interactive `forge init` asks one question about the preferred architecture. Offer MVVM, MVI, VIPER, VIP, and MVP with short descriptions. Accepting a choice completes setup using the existing binding, DI, and testing defaults.
2. Write `.forge.yml` and a sibling `.templates/` directory in the project root. Populate the directory with working templates for the chosen architecture. The config activates them immediately and includes a commented example of adding a team-specific role.
3. Finish with a message such as “Initialized Forge with MVVM. Generate your first form with `forge make Profile -form`. When you're ready, add your team's stack to the stack section of .forge.yml and edit the Swift templates in .templates/. Run forge validate to check your changes.”
4. Support the same setup in CI with an explicit architecture, for example `forge init -mvvm`. Preserve the existing unattended plain-init workflow. Reuse an existing config's architecture and settings during adoption. Resolve templates beside the selected config even when feature output goes elsewhere.

### Describe the stack in the existing configuration

Use one versioned `stack` mapping per configuration. Existing architecture, binding, DI, testing, naming, and path settings remain authoritative. The stack declares enabled categories and maps roles to templates. Built-in roles inherit their destinations. An extra role such as a coordinator declares its template, relative output path, and source or test target membership. Test roles follow the resolved test-generation setting.

Teams can replace the view, state owner, dependency construction, or individual control and row fragments. Ship a working example with a custom initializer dependency, branded controls, an extra coordinator, and isolated preview and test construction. A template can refer to dependencies supplied by its host project.

### Preserve behavior across template edits

Derive bindings, state, actions, initializer arguments, previews, and test inputs from one resolved feature description. Expose named insertion points in the exported Swift. For MVVM, a single ViewModel template serves default, form, and list generation. A form receives writable state and matching text-field bindings. A list receives the item collection, load action, retry, and cancellation behavior. Managed fragments handle indentation and optional initializer punctuation. Render into new feature files so the team's reusable templates retain their edits.

Provide the corresponding state, intent, and store wiring for MVI. Describe VIP, VIPER, and MVP according to their existing scaffold capabilities during setup. Keep existing field and item shapes for this release.

### Validation, feedback, and adoption

- `forge validate` renders every enabled category offline with the selected config's defaults. Check syntax across all branches and required insertion points on each active rendering path. `forge make` checks the requested combination before writing. Dry runs also report destination conflicts and deferred project checks.
- Each diagnostic names the template and available source location, affected category, consequence, and repair. For example, if model state appears only inside a list condition, identify that condition and explain that moving the state insertion point into the shared ViewModel body restores form bindings. Separate rendering success from compilation against team dependencies.
- Reject missing configured templates, unknown versions, incompatible architecture overrides, escaping paths and symlinks, and output collisions including case-only differences. Preserve edited files on rerun. Stage setup under a lock, publish config after templates are ready, and make interrupted setup recoverable.
- Keep existing v1 overrides working for projects using `.forge/templates/`. When adopting the new contract, explain which overrides will cease to be active and obtain an explicit choice. Preserve legacy files and existing config comments. A repeated init should identify the active setup and suggest the appropriate validation or repair.

### Release acceptance

1. From an empty project, select MVVM and generate a working form immediately. Edit its exported ViewModel once, then generate a fresh form and list. Compile both and exercise text entry, submission, list loading, retry, and the custom dependency.
2. Break only the form branch. Confirm the diagnostic leads to a successful repair while the list still validates. Exercise invalid paths, duplicate markers, collisions, cancellation, interrupted setup, concurrent writes, and reruns with edited templates.
3. Run legacy and new fixtures in Xcode and SwiftPM, including source/test target registration, files-only mode, and tests disabled. Cover Combine and Observation, representative testing and DI combinations, Clean layers, and a compiling default for each offered architecture.
4. Publish the versioned contract, adoption guide, walkthrough, and a host-build CI recipe. Use the compiled reference fixture in the walkthrough and release checks so teams can maintain their stack during the pause.

## Priorities and feature budget

1. Maintain usable, compiling generated output and dependable project integration. A file count or a passing trivial state assertion is not a productivity metric.
2. Improve default MVVM/MVI workflows and local customization. Preserve correctness and compatibility for VIPER/VIP/MVP without expanding their feature surfaces until usage supports doing so.
3. Keep Clean layers optional. Keep Combine/Observation, XCTest/Swift Testing, and native/Factory DI for compatibility. Maintain naming and header options without major expansion.
4. Defer remote template distribution, model generation, regeneration, additional DI frameworks, AI generation, app starters, auth/payment stacks, and build caching.
5. Consider deprecations only after observing usage and migration cost. `--no-domain` and less-used architectures are candidates for review, not announced removals. Any removal needs an alternative and a major-release migration notice.

## Evidence and limits

The research identifies genuine workflow friction but does not establish adoption or market share for Forge:

- [Tuist templates](https://tuist.dev/en/docs/guides/features/projects/templates) address consistent feature setup and show that generic scaffolding already has competition.
- [Reactive state testing discussion](https://forums.swift.org/t/supporting-reactive-updates/67588) describes difficulty reliably testing asynchronous ViewModel updates.
- [Modular app case study](https://forums.swift.org/t/how-to-build-a-modular-whitelabel-app-with-local-swift-packages/81548) illustrates package/target integration friction and the limits of universal project support.
- [Buildable-folder experience](https://tuist.dev/changelog/2025.08.11-buildable-folders) reinforces the value of files being recognized outside the Xcode UI.
- [Preview discussion](https://www.reddit.com/r/swift/comments/1lfdx1f) supports isolating preview dependencies.
- [Template adoption discussion](https://www.reddit.com/r/iOSProgramming/comments/176bfx6) raises the cost of reviewing and adapting boilerplate.

These qualitative sources are not representative demand estimates. Forge should complement existing project-generation tooling rather than replace it.

## Developer pilot (not yet conducted)

Recruit five solo developers and five engineers working in teams. Each uses Forge and their normal workflow on comparable real list/form tasks; alternate task order to reduce learning effects. Include existing projects, not just empty sample packages.

Record time to an integrated, building feature with a useful test, including configuration, cleanup, and customization; deleted generated files; rewritten boilerplate; integration failures; and voluntary use on a second feature. Compare median time improvement separately for each audience. Do not collect source code or add automatic telemetry.

Proposed continuation gate: at least 30% median setup-time improvement in each audience and voluntary reuse by at least three of five participants in each group. These are targets, not results. If either group misses the gate, investigate the observed cleanup/integration costs before expanding scope. Interviews and pilot results should inform deprecations; absence of usage data is not evidence that an option has no value.
