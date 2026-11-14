# Forge product vision and current understanding

This document records the product goals and decisions discussed with Forge's creator, alongside the behavior visible in the repository as of November 2026. It is a guide for future design and prioritization, not a claim that every goal is implemented today.

## Purpose and audience

Forge is a Swift command-line tool for scaffolding SwiftUI features. Its intended audience is any iOS engineer, from an individual developer to an engineer working within a corporate team. It should fit different project structures, architecture preferences, and team conventions without making the common workflow difficult.

The central goal is to generate all predictable feature setup and wiring so developers spend their time on business logic and other code that requires judgment. Generated code should be a useful, connected starting point that developers can customize afterward. Forge should not try to infer feature-specific business rules.

## What useful generated code means

Forge should generate related pieces that work together, rather than a collection of empty, disconnected files. Examples discussed:

- For a list feature, generate the `List` in the View, a matching item collection or state in the ViewModel or equivalent architecture component, and the connection between them.
- For a form feature, generate a couple of text fields, corresponding state, and working bindings or update actions.
- Generate a dependency container according to the team's chosen approach, such as native composition or Factory.
- Generate the ordinary architecture setup, tests, and other boilerplate appropriate to the selected stack.
- In the future, generate basic Swift data models that developers can update. The input and design for model generation are deliberately deferred because they would add complexity now.

The developer remains responsible for complex feature logic, product-specific behavior, and any customization of the scaffold.

## Choice without mandatory complexity

Forge should continue supporting all five current presentation patterns: MVVM, MVI, VIPER, VIP, and MVP. Each engineer or team should be able to choose its preferred pattern. Optional Clean Architecture layers and UI categories should remain compatible with those choices.

`.forge.yml` is the intended place for teams to configure their stack and conventions. Preferences include state binding through Combine or Swift Concurrency and Observation, dependency injection through native or custom containers or Factory, testing framework, output paths, and naming. A straightforward command should still produce a useful result with built-in defaults. CLI options can override project defaults where supported.

The main product challenge is increasing flexibility without exposing users to a large number of decisions or allowing incompatible combinations to fail silently. A simple path should work out of the box; advanced customization should be available when a team needs it.

## Custom templates: direction and recommendation

The creator wants Forge's templates to become accessible and editable by users. The initial idea is to keep templates at the project root. Support for templates obtained from a GitHub repository is also a possible later step. The storage format, discovery rules, and update process are not yet decided.

Recommended first step: allow a project to override an individual built-in template while the other generated files continue using Forge's defaults. For example, a team could replace its MVVM ViewModel template without copying an entire MVVM template set. Forge should provide the template's values and file destination, check for missing values and output conflicts before writing, and report compatibility problems clearly. Built-in templates remain Forge's responsibility to keep mutually compatible. A team that replaces a template controls that template's source and the resulting code. Broader template packs and remote distribution can build on the same concepts later.

This recommendation is a design direction, not an implemented or final template API.

## Project integration: target behavior

Forge should update the destination project when it generates a feature. That includes registering generated files with the relevant Xcode target and adding a selected dependency such as Factory if the project does not already contain it. This should also apply to the relevant test target and package setup where appropriate. The precise rules for choosing targets and changing existing project files still need design.

Project updates should be repeatable without duplicate entries, and Forge should give a clear error when it cannot safely make a requested change. This is a recommended implementation constraint for the agreed integration goal.

## What the repository currently does

- `forge make <FeatureName>` generates feature files using one of five presentation architectures. A terminal prompt chooses an architecture when neither a flag nor configuration supplies one.
- `-form` and `-list` select functional UI templates. `-clean` adds Domain and Data layers; `--no-domain` keeps Data while omitting Domain files.
- `.forge.yml` can select architecture, binding, testing framework, DI strategy, flags, paths, and naming. `forge init` writes a starter configuration.
- `--package` creates a standalone Swift package and its manifest. `--target` verifies an existing package target, routes files into its standard source and test directories, and updates literal manifests with a test target and Factory dependencies when selected. Dynamic manifests and custom target paths are not yet supported.
- Built-in templates are embedded in Swift source. There is currently no user template override mechanism.
- The Factory package dependency is declared for generated standalone packages and supported existing Swift packages when Factory is selected. Forge does not currently add it to an existing Xcode app project.
- Forge registers generated Swift sources with the sole app target in an Xcode project, or with the app target selected by `--xcode-target` or `paths.xcode_target`. When tests are enabled, Forge can register them with an existing app-hosted unit-test target and resolve the app module through Xcode. Factory setup still requires manual wiring in Xcode. `--files-only` keeps the project file untouched.
- Generation checks for existing destination files before writing and refuses to overwrite them. It does not currently offer an update or regeneration workflow.
- The repository includes unit tests and a generated-code verification script that builds and tests a matrix of architecture, layer, and UI category combinations on macOS.

## Open design questions

These questions are not settled by the discussion or the current implementation:

1. What exact format and location should project templates use, and how should Forge expose built-in templates for editing?
2. How should template compatibility be declared or checked when architecture, binding, DI, and test options are combined?
3. How should Forge identify the correct app and test targets and handle project formats it cannot safely edit?
4. How should dependency changes work for an existing Swift package versus an Xcode project?
5. What should happen when users rerun Forge for an existing feature: refuse, add only missing files, or support a controlled update workflow?
6. When remote templates are introduced, how should versions and trust be managed?

## Near-term prioritization implied by the discussion

Focus on flexibility for differing team setups while keeping the default experience simple. The most concrete opportunities are project integration and local template overrides. Data-model generation and remote template distribution are future possibilities, with data-model generation explicitly deferred for now.
