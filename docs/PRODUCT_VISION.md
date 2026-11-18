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
