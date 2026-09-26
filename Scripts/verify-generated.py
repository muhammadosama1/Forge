#!/usr/bin/env python3
"""Build generated SwiftUI packages and run their tests (macOS, Swift 6.2+)."""

import argparse
import itertools
import os
from pathlib import Path
import platform
import re
import shlex
import signal
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET


ARCHITECTURES = ("mvvm", "mvi", "viper", "vip", "mvp")
LAYERS = {"standalone": [], "clean": ["-clean"], "no-domain": ["--no-domain"]}
LAYOUTS = {"default": [], "form": ["-form"], "list": ["-list"]}
ROOT = Path(__file__).resolve().parents[1]


def positive_int(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return number


def run(command, cwd, log, timeout):
    """Keep the full command output and stop its compiler processes on timeout."""
    log.write("$ " + shlex.join(str(part) for part in command) + "\n")
    log.flush()
    with subprocess.Popen(
        command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, start_new_session=True,
    ) as process:
        try:
            output, _ = process.communicate(timeout=timeout)
        except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            output, _ = process.communicate()
            log.write(output)
            log.flush()
            if isinstance(error, KeyboardInterrupt):
                raise
            raise RuntimeError(f"command timed out after {timeout} seconds")
        log.write(output)
        log.flush()
        if process.returncode:
            raise RuntimeError(f"command exited with status {process.returncode}")
        return output


def show_failure(name, error, log_path):
    print(f"FAIL {name}: {error}", flush=True)
    print(f"Full log: {log_path}", flush=True)
    if log_path.exists():
        print("\n".join(log_path.read_text().splitlines()[-80:]), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--architecture", action="append", choices=ARCHITECTURES,
        help="repeat to select architectures; default: all except TCA",
    )
    parser.add_argument("--forge", type=Path, help="use an already-built Forge executable")
    parser.add_argument("--jobs", type=positive_int, default=4, help="Swift compiler jobs (default: 4)")
    parser.add_argument(
        "--timeout", type=positive_int, default=300,
        help="timeout per command in seconds (default: 300)",
    )
    parser.add_argument("--logs-dir", type=Path, default=ROOT / ".build/generated-verification")
    args = parser.parse_args()

    if platform.system() != "Darwin":
        parser.error("generated SwiftUI packages require macOS")
    logs_dir = args.logs_dir.resolve()
    logs_dir.mkdir(parents=True, exist_ok=True)
    setup_log = logs_dir / "setup.log"
    try:
        with setup_log.open("w") as log:
            version = run(["swift", "--version"], ROOT, log, args.timeout)
            match = re.search(r"Swift version (\d+)\.(\d+)", version)
            if not match or tuple(map(int, match.groups())) < (6, 2):
                raise RuntimeError("Swift 6.2 or later is required")
            if args.forge:
                forge = args.forge.resolve()
                if not forge.is_file() or not os.access(forge, os.X_OK):
                    raise RuntimeError(f"Forge executable not found: {forge}")
            else:
                run(["swift", "build", "--jobs", str(args.jobs)], ROOT, log, args.timeout)
                bin_path = run(["swift", "build", "--show-bin-path"], ROOT, log, args.timeout)
                forge = Path(bin_path.strip()) / "forge"
    except (OSError, RuntimeError) as error:
        show_failure("setup", error, setup_log)
        return 1

    architectures = list(dict.fromkeys(args.architecture or ARCHITECTURES))
    cases = list(itertools.product(architectures, LAYERS, LAYOUTS))
    failures = []
    for index, (architecture, layer, layout) in enumerate(cases, start=1):
        name = f"{architecture}-{layer}-{layout}"
        # Exercise SwiftPM's hyphen-to-underscore module naming in one case.
        target = "Feature-Kit" if (architecture, layer, layout) == ("mvvm", "standalone", "list") else "FeatureKit"
        log_path = logs_dir / f"{name}.log"
        xml_path = logs_dir / f"{name}.xml"
        # Never accept a report left over from an earlier run.
        xml_path.unlink(missing_ok=True)
        print(f"[{index}/{len(cases)}] {name}", flush=True)
        try:
            with tempfile.TemporaryDirectory(prefix="forge-verify-") as directory:
                with log_path.open("w") as log:
                    # The module deliberately differs from the feature name.
                    run([
                        str(forge), "make", "Sample", f"-{architecture}",
                        "--package", "--tests", "--target", target,
                        "--path", directory, *LAYERS[layer], *LAYOUTS[layout],
                    ], ROOT, log, args.timeout)
                    run([
                        "swift", "test", "--package-path", str(Path(directory) / "Sample"),
                        "--jobs", str(args.jobs), "--parallel", "--num-workers", "1",
                        "--xunit-output", str(xml_path),
                    ], ROOT, log, args.timeout)
                    report = ET.parse(xml_path).getroot()
                    executed = [test for test in report.iter("testcase") if test.find("skipped") is None]
                    if not executed:
                        raise RuntimeError("no generated tests executed")
                    if any(test.find("failure") is not None or test.find("error") is not None for test in executed):
                        raise RuntimeError("generated tests reported failures")
            print(f"PASS {name}: {len(executed)} tests", flush=True)
        except (OSError, RuntimeError, ET.ParseError) as error:
            failures.append(name)
            show_failure(name, error, log_path)

    print(f"\n{len(cases) - len(failures)}/{len(cases)} generated packages passed.", flush=True)
    print(f"Logs and test reports: {logs_dir}", flush=True)
    if failures:
        print("Failed: " + ", ".join(failures), flush=True)
    return int(bool(failures))


if __name__ == "__main__":
    sys.exit(main())
