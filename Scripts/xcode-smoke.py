#!/usr/bin/env python3
"""Generate and run Factory-backed XCTest and Swift Testing suites in a hosted iOS test target."""

import argparse
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


FIXTURE = Path(__file__).resolve().parent / "fixtures" / "xcode-smoke"


def run(command, cwd, *, timeout=300):
    try:
        result = subprocess.run(
            command, cwd=cwd, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, timeout=timeout,
        )
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or b"").decode(errors="replace")
        tail = "\n".join(output.splitlines()[-100:])
        raise RuntimeError(f"{' '.join(map(str, command))} timed out after {timeout}s\n{tail}") from error
    if result.returncode:
        raise RuntimeError(f"{' '.join(map(str, command))} exited {result.returncode}\n{result.stdout}")
    return result.stdout


def use_synchronized_folders(project, project_file):
    # Add synchronized folders to the fixture's existing app and hosted test targets.
    app_group = "A00000000000000000000016"
    test_group = "A00000000000000000000017"
    contents = project_file.read_text(encoding="utf-8")
    contents = contents.replace("objectVersion = 56;", "objectVersion = 77;")
    contents = contents.replace("objects = {", f"""objects = {{
        {app_group} = {{ isa = PBXFileSystemSynchronizedRootGroup; path = App; sourceTree = "<group>"; }};
        {test_group} = {{ isa = PBXFileSystemSynchronizedRootGroup; path = Tests; sourceTree = "<group>"; }};""")
    contents = contents.replace(
        "children = (A00000000000000000000006,",
        f"children = ({app_group}, {test_group}, A00000000000000000000006,",
    )
    for target, group in (("SmokeApp", app_group), ("SmokeTests", test_group)):
        contents = contents.replace(f"name = {target};", f"name = {target}; fileSystemSynchronizedGroups = ({group});")
    project_file.write_text(contents, encoding="utf-8")
    for directory in ("App", "Tests"):
        (project / directory).mkdir()


def smoke(forge, destination, root, *, synchronized):
    layout = "synchronized" if synchronized else "explicit"
    workspace = root / layout
    project = workspace / "Workspace"
    shutil.copytree(FIXTURE, project)
    project_file = project / "Smoke.xcodeproj" / "project.pbxproj"
    decoy = project / "Other.xcodeproj" / "project.pbxproj"
    decoy.parent.mkdir()
    decoy.write_bytes(project_file.read_bytes())
    original_decoy = decoy.read_bytes()
    nested = project / "Scripts" / "Nested"
    nested.mkdir(parents=True)
    if synchronized:
        use_synchronized_folders(project, project_file)

    features = "App/Features" if synchronized else "Sources/Features"
    config = workspace / ".forge.yml"
    routing = f"paths:\n  xcode_project: Workspace/Smoke.xcodeproj\n  features: Workspace/{features}\n"
    config.write_text(routing, encoding="utf-8")
    if synchronized:
        original_project = project_file.read_bytes()
        run([forge, "make", "SmokeNative", "-mvvm", "--no-tests"], nested)
        if project_file.read_bytes() != original_project:
            raise RuntimeError("Forge rewrote the synchronized fixture during native generation")

    config.write_text(routing + "di: factory\ntesting: xctest\n", encoding="utf-8")
    args = [forge, "make", "SmokeXCTest", "-mvvm", "--tests"]
    original_project = project_file.read_bytes()
    planned_feature = project / features / "SmokeXCTest"
    planned_tests = project / "Tests" / "SmokeXCTest" if synchronized else planned_feature / "Tests"
    plan = run([*args, "--dry-run"], nested)
    selected_projects = [Path(line.removeprefix("Xcode project: ")).resolve()
                         for line in plan.splitlines() if line.startswith("Xcode project: ")]
    planned_files = {Path(line[4:]).resolve() for line in plan.splitlines() if line.startswith("  + ")}
    if (selected_projects != [project_file.parent]
            or planned_feature / "Presentation" / "SmokeXCTestViewModel.swift" not in planned_files
            or planned_tests / "SmokeXCTestViewModelTests.swift" not in planned_files
            or planned_feature.exists() or planned_tests.exists()
            or project_file.read_bytes() != original_project):
        raise RuntimeError(f"Unexpected dry run for configured Xcode paths:\n{plan}")
    run(args, nested)
    factory_project = project_file.read_bytes()
    config.write_text(routing + "di: factory\ntesting: swift-testing\n", encoding="utf-8")
    run([
        forge, "make", "SmokeSwiftTesting", "-mvvm", "--tests",
        "--xcode-test-target", "SmokeTests",
    ], nested)

    updated_project = project_file.read_bytes()
    if decoy.read_bytes() != original_decoy:
        raise RuntimeError("Forge changed the unselected Xcode project")
    for entry in (b"isa = XCRemoteSwiftPackageReference;", b"productName = Factory;", b"productRef = "):
        if updated_project.count(entry) != 1:
            raise RuntimeError(f"Expected one Factory dependency entry matching {entry!r}")
    names = ("SmokeXCTest", "SmokeSwiftTesting")
    for feature in names:
        feature_directory = project / features / feature
        test_directory = project / "Tests" / feature if synchronized else feature_directory / "Tests"
        source = test_directory / f"{feature}ViewModelTests.swift"
        if "@testable import ForgeSmokeModule" not in source.read_text(encoding="utf-8"):
            raise RuntimeError(f"Wrong test module import in {source}")
        if not (feature_directory / "Presentation" / f"{feature}ViewModel.swift").is_file():
            raise RuntimeError(f"Wrong feature destination for {feature}")

    if synchronized and updated_project != factory_project:
        raise RuntimeError("Forge rewrote the synchronized fixture after Factory was already linked")

    derived_data = root / f"DerivedData-{layout}"
    output = run([
        "xcodebuild", "test", "-project", project / "Smoke.xcodeproj", "-scheme", "Smoke",
        "-destination", destination, "-derivedDataPath", derived_data,
        "-parallel-testing-enabled", "NO", "ONLY_ACTIVE_ARCH=YES",
    ], project, timeout=420)
    xctest = r"Test Case '-\[SmokeTests\.SmokeXCTestViewModelTests [^\]]+\]' passed"
    swift_testing = r"Suite SmokeSwiftTestingViewModelTests passed"
    if not all(re.search(pattern, output) for pattern in (xctest, swift_testing)):
        raise RuntimeError(f"Expected both generated suites to run and pass\n{output}")
    expected_sources = {f"{feature}ViewModel.swift" for feature in names}
    expected_tests = {f"{feature}ViewModelTests.swift" for feature in names}
    for target, expected, unexpected in (
        ("SmokeApp", expected_sources, expected_tests),
        ("SmokeTests", expected_tests, expected_sources),
    ):
        file_lists = list(derived_data.glob(f"Build/Intermediates.noindex/**/{target}.SwiftFileList"))
        if not file_lists:
            raise RuntimeError(f"No Swift file list found for {target}")
        for file_list in file_lists:
            compiled_files = [Path(line).name for line in file_list.read_text(encoding="utf-8").splitlines()]
            if any(compiled_files.count(name) != 1 for name in expected) or unexpected.intersection(compiled_files):
                raise RuntimeError(f"Wrong Swift source membership for {target}: {compiled_files}")
    print(f"PASS generated XCTest and Swift Testing suites with Factory in Xcode ({layout} folders)", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--forge", type=Path, required=True, help="built Forge executable")
    parser.add_argument("--destination", required=True, help="xcodebuild iOS Simulator destination")
    args = parser.parse_args()
    forge = args.forge.resolve()
    if not forge.is_file():
        parser.error(f"Forge executable not found: {forge}")

    with tempfile.TemporaryDirectory(prefix="forge-xcode-smoke-") as temporary:
        root = Path(temporary).resolve()
        smoke(forge, args.destination, root, synchronized=False)
        smoke(forge, args.destination, root, synchronized=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
