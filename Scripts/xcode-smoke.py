#!/usr/bin/env python3
"""Generate and run XCTest and Swift Testing suites in a hosted iOS test target."""

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
    project = root / layout
    shutil.copytree(FIXTURE, project)
    project_file = project / "Smoke.xcodeproj" / "project.pbxproj"
    if synchronized:
        use_synchronized_folders(project, project_file)
    original_project = project_file.read_bytes()
    config = project / ".forge.yml"
    config.write_text("testing: xctest\n", encoding="utf-8")

    run([forge, "make", "SmokeXCTest", "-mvvm", "--tests", "--path", project], project)
    config.write_text("testing: swift-testing\n", encoding="utf-8")
    run([
        forge, "make", "SmokeSwiftTesting", "-mvvm", "--tests", "--path", project,
        "--xcode-test-target", "SmokeTests",
    ], project)

    features = ("SmokeXCTest", "SmokeSwiftTesting")
    for feature in features:
        test_directory = project / "Tests" / feature if synchronized else project / feature / "Tests"
        source = test_directory / f"{feature}ViewModelTests.swift"
        if "@testable import ForgeSmokeModule" not in source.read_text(encoding="utf-8"):
            raise RuntimeError(f"Wrong test module import in {source}")

    if synchronized:
        if project_file.read_bytes() != original_project:
            raise RuntimeError("Forge rewrote the synchronized fixture")
        for feature in features:
            source = project / "App" / feature / "Presentation" / f"{feature}ViewModel.swift"
            if not source.is_file() or (project / "App" / feature / "Tests").exists():
                raise RuntimeError(f"Wrong synchronized output for {feature}")

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
    if synchronized:
        expected_tests = {f"{feature}ViewModelTests.swift" for feature in features}
        for target in ("SmokeApp", "SmokeTests"):
            file_lists = list(derived_data.glob(f"Build/Intermediates.noindex/**/{target}.SwiftFileList"))
            compiled_files = {
                Path(line).name
                for file_list in file_lists
                for line in file_list.read_text(encoding="utf-8").splitlines()
            }
            expected = expected_tests if target == "SmokeTests" else {f"{feature}ViewModel.swift" for feature in features}
            if not expected <= compiled_files or (target == "SmokeApp" and expected_tests & compiled_files):
                raise RuntimeError(f"Wrong Swift source membership for {target}: {sorted(compiled_files)}")
    print(f"PASS generated XCTest and Swift Testing suites in Xcode ({layout} folders)", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--forge", type=Path, required=True, help="built Forge executable")
    parser.add_argument("--destination", required=True, help="xcodebuild iOS Simulator destination")
    args = parser.parse_args()
    forge = args.forge.resolve()
    if not forge.is_file():
        parser.error(f"Forge executable not found: {forge}")

    with tempfile.TemporaryDirectory(prefix="forge-xcode-smoke-") as temporary:
        root = Path(temporary)
        smoke(forge, args.destination, root, synchronized=False)
        smoke(forge, args.destination, root, synchronized=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
