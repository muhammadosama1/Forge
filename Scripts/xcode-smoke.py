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


def run(command, cwd):
    result = subprocess.run(
        command, cwd=cwd, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, timeout=300,
    )
    if result.returncode:
        raise RuntimeError(f"{' '.join(map(str, command))} exited {result.returncode}\n{result.stdout}")
    return result.stdout


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
        project = root / "Fixture"
        shutil.copytree(FIXTURE, project)
        config = project / ".forge.yml"
        config.write_text("testing: xctest\n", encoding="utf-8")

        run([forge, "make", "SmokeXCTest", "-mvvm", "--tests", "--path", project], project)
        config.write_text("testing: swift-testing\n", encoding="utf-8")
        run([
            forge, "make", "SmokeSwiftTesting", "-mvvm", "--tests", "--path", project,
            "--xcode-test-target", "SmokeTests",
        ], project)

        for feature in ("SmokeXCTest", "SmokeSwiftTesting"):
            source = project / feature / "Tests" / f"{feature}ViewModelTests.swift"
            if "@testable import ForgeSmokeModule" not in source.read_text(encoding="utf-8"):
                raise RuntimeError(f"Wrong test module import in {source}")

        output = run([
            "xcodebuild", "test", "-project", project / "Smoke.xcodeproj", "-scheme", "Smoke",
            "-destination", args.destination, "-derivedDataPath", root / "DerivedData",
            "-parallel-testing-enabled", "NO",
        ], project)
        xctest = r"Test Case '-\[SmokeTests\.SmokeXCTestViewModelTests [^\]]+\]' passed"
        swift_testing = r"Suite SmokeSwiftTestingViewModelTests passed"
        if not all(re.search(pattern, output) for pattern in (xctest, swift_testing)):
            raise RuntimeError(f"Expected both generated suites to run and pass\n{output}")
        print("PASS generated XCTest and Swift Testing suites in Xcode")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
