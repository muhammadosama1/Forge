#!/usr/bin/env python3
"""Exercise a built Forge binary through realistic CLI workflows."""

import argparse
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def run(command, *, succeeds=True, cwd=None):
    result = subprocess.run(command, text=True, capture_output=True, timeout=300, cwd=cwd)
    if (result.returncode == 0) != succeeds:
        raise AssertionError(
            f"Unexpected exit {result.returncode}: {' '.join(map(str, command))}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result.stdout + result.stderr


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--forge", type=Path, required=True, help="built Forge executable")
    parser.add_argument("--expected-version", help="expected `forge --version` value")
    args = parser.parse_args()
    forge = args.forge.resolve()
    require(forge.is_file(), f"Forge executable not found: {forge}")

    help_text = run([forge, "--help"])
    require("forge make" in help_text and "forge init" in help_text, "Help omits main commands")
    version = run([forge, "--version"]).strip()
    require(version.startswith("forge "), f"Unexpected version output: {version}")
    if args.expected_version:
        require(version == f"forge {args.expected_version}", f"Expected forge {args.expected_version}, got {version}")
    print(f"PASS help and version ({version})", flush=True)

    with tempfile.TemporaryDirectory(prefix="forge-release-smoke-") as temporary:
        root = Path(temporary)
        if args.expected_version:
            install_dir = root / "installed-bin"
            run(["make", "install", f"INSTALL_DIR={install_dir}",
                 f"VERSION={args.expected_version}"], cwd=Path(__file__).resolve().parents[1])
            installed = install_dir / "forge"
            require(installed.is_file() and run([installed, "--version"]).strip() == version,
                    "make install did not install the expected binary")
            print("PASS local installation", flush=True)

        project = root / "Project With Spaces"
        run([forge, "init", "--path", project])
        config = project / ".forge.yml"
        require(config.is_file(), "forge init did not create .forge.yml")
        require("already exists" in run([forge, "init", "--path", project], succeeds=False),
                "forge init did not protect an existing config")
        config.write_text("""architecture: mvi
binding: concurrency
testing: swift-testing
flags:
  clean: true
  tests: true
""")
        print("PASS init and overwrite protection", flush=True)

        run([forge, "make", "Search", "-form", "--path", project])
        require((project / "Search/Presentation/SearchStore.swift").is_file(),
                "Configured MVI feature was not generated")
        require((project / "Search/Domain/SearchEntity.swift").is_file(),
                "Configured Clean layers were not generated")
        view = (project / "Search/Presentation/SearchView.swift").read_text()
        require("TextField" in view and "@State" in view, "Form/Observation output is incomplete")
        tests = list((project / "Search/Tests").glob("*.swift"))
        require(tests and "import Testing" in tests[0].read_text(), "Swift Testing was not selected")

        run([forge, "make", "Profile", "-mvvm", "--no-clean", "--no-tests", "--path", project])
        require((project / "Profile/Presentation/ProfileViewModel.swift").is_file(),
                "CLI architecture override failed")
        require(not (project / "Profile/Domain").exists() and not (project / "Profile/Tests").exists(),
                "CLI negative flags did not override project defaults")
        print("PASS configured generation and CLI overrides", flush=True)

        standalone = root / "Standalone"
        standalone.mkdir()
        (standalone / ".forge.yml").write_text("""architecture: mvvm
binding: concurrency
testing: swift-testing
""")
        run([forge, "make", "Catalog", "-list", "--package", "--tests", "--path", standalone])
        package_root = standalone / "Catalog"
        require((package_root / "Package.swift").is_file(), "Standalone package manifest is missing")
        result = run(["swift", "test", "--package-path", package_root, "--jobs", "4"])
        require("Test run with" in result and "0 tests in 0 suites" not in result,
                "Standalone package did not execute generated tests")
        print("PASS standalone package builds and runs generated tests", flush=True)

        named = root / "NamedPackage"
        named.mkdir()
        (named / ".forge.yml").write_text("""architecture: mvvm
flags:
  tests: true
naming:
  type_prefix: App
  type_suffix: Feature
  folder_prefix: Module
  folder_suffix: Screen
""")
        run([forge, "make", "Login", "--package", "--path", named])
        named_package = named / "ModuleLoginScreen"
        require((named_package / "Sources/AppLoginFeature/Presentation/AppLoginFeatureView.swift").is_file(),
                "Naming rules did not route generated types and folders")
        named_tests = named_package / "Tests/AppLoginFeatureTests/AppLoginFeatureViewModelTests.swift"
        require(named_tests.is_file() and "@testable import AppLoginFeature" in named_tests.read_text(),
                "Named package tests do not import the generated module")
        named_output = run(["swift", "test", "--package-path", named_package, "--jobs", "4"])
        require(re.search(r"Executed [1-9]\d* tests?", named_output) is not None,
                "Named package did not execute generated tests:\n" + named_output[-1500:])
        print("PASS naming rules and generated module imports", flush=True)

        existing = root / "ExistingPackage"
        existing.mkdir()
        manifest = existing / "Package.swift"
        manifest.write_text("""// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "Sample",
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [.target(name: "FeatureKit", dependencies: [])]
)
""")
        (existing / ".forge.yml").write_text("architecture: mvvm\ndi: factory\npaths:\n  target: FeatureKit\n")
        run([forge, "make", "Login", "--tests", "--path", existing])
        require((existing / "Sources/FeatureKit/Login/Presentation/LoginViewModel.swift").is_file(),
                "Existing package source routing failed")
        require((existing / "Tests/FeatureKitTests/Login/LoginViewModelTests.swift").is_file(),
                "Existing package test routing failed")
        run(["swift", "package", "--package-path", existing, "dump-package"])
        run([forge, "make", "Profile", "--target", "FeatureKit", "--tests", "--path", existing])
        updated = manifest.read_text()
        require(updated.count("https://github.com/hmlongco/Factory.git") == 1,
                "Factory package dependency was duplicated")
        require(updated.count('.product(name: "Factory"') == 1,
                "Factory target dependency was duplicated")
        require(updated.count('.testTarget(name: "FeatureKitTests"') == 1,
                "Test target was duplicated")
        run(["swift", "package", "--package-path", existing, "dump-package"])
        factory_tests = run(["swift", "test", "--package-path", existing, "--jobs", "4"])
        counts = [int(count) for count in re.findall(r"Executed (\d+) tests", factory_tests)]
        require(counts and max(counts) > 0,
                "Existing package with Factory did not execute generated tests")
        print("PASS existing package integration and repeatability", flush=True)

        before = manifest.read_text()
        require("not declared" in run([forge, "make", "Missing", "--target", "UnknownKit",
                                       "--path", existing], succeeds=False),
                "Unknown target did not give an actionable error")
        require(not (existing / "Sources/UnknownKit/Missing").exists(),
                "Unknown target left feature files behind")
        require("overwrite" in run([forge, "make", "Login", "--target", "FeatureKit",
                                    "--path", existing], succeeds=False),
                "Repeated feature generation did not refuse to overwrite")
        require(manifest.read_text() == before, "Failed commands changed Package.swift")
        require("not a valid feature name" in run([forge, "make", "123Invalid", "-mvvm",
                                                  "--path", standalone], succeeds=False),
                "Invalid feature name did not give an actionable error")
        invalid_config = root / "InvalidConfig"
        invalid_config.mkdir()
        (invalid_config / ".forge.yml").write_text(
            'architecture: mvvm\nnaming:\n' + r'  type_prefix: "Bad\q"' + '\n'
        )
        bad_yaml = run([forge, "make", "Invalid", "--path", invalid_config], succeeds=False)
        require("YAML syntax error at line 3" in bad_yaml and not (invalid_config / "Invalid").exists(),
                "Malformed config did not fail clearly before generating files")
        print("PASS error messages and no partial output", flush=True)

    print("Release smoke scenarios passed.", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, OSError, subprocess.TimeoutExpired) as error:
        print(f"FAIL release smoke: {error}", file=sys.stderr)
        sys.exit(1)
