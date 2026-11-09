# Release readiness and publishing

Run the release gate on macOS with Swift 6.2 or newer and Python 3. Choose the intended version before testing:

```sh
make release-check VERSION=2.0.0
```

The command stamps the ignored `Sources/forge/Version.swift`, builds the release binary, runs Forge's unit tests, exercises CLI workflows from a temporary user's project, then builds and tests two 45-case generated architecture/layer/layout matrices: the defaults and a combined Observation, Swift Testing, and Factory configuration. The smoke test covers local installation, `init`, project configuration, CLI overrides, naming rules and module imports, a standalone package using Observation and Swift Testing, an existing package that builds and runs generated tests with Factory, repeat generation, and errors that must leave no partial feature files. It also checks that `forge --version` matches `VERSION`.

`Scripts/release-smoke.py` can be run against an already built binary while investigating a failure:

```sh
python3 Scripts/release-smoke.py --forge .build/release/forge --expected-version 2.0.0
```

Before publishing:

1. Review `git status` and the full diff. Commit the intended code, documentation, and tests; leave generated verification output and `Version.swift` untracked/ignored.
2. Resolve every failing release check. Review the CLI output and the generated project structure for the workflows in the smoke test.
3. Move the relevant `Unreleased` changelog entries under a dated version heading. Keep any unfinished work under `Unreleased`.
4. Run `make release-check VERSION=<version>` again on the final commit. Confirm the release binary reports `forge <version>`.
5. Create and push the `v<version>` tag from that commit, then publish the release and update the Homebrew tap with the corresponding artifact and checksum. Verify installation and `forge --version` from the distributed binary.

Tagging, uploading binaries, and changing the Homebrew tap are manual publishing steps. A passing local check does not publish anything.
