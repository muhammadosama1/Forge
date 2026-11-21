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


def customize_mvvm(directory):
    """Compile a team stack through public, live, preview, and test construction."""
    config = directory / ".forge.yml"
    config.write_text(config.read_text() + """
    coordinator:
      template: coordinator.swift.stencil
      output: "Navigation/{{ name }}Coordinator.swift"
      target: source
    controls:
      template: controls.swift.stencil
      output: "Presentation/{{ name }}Controls.swift"
      target: source
    teamTests:
      template: teamTests.swift.stencil
      output: "Team/{{ name }}TeamTests.swift"
      target: test
""")
    templates = directory / ".templates"
    (templates / "coordinator.swift.stencil").write_text("""
import Foundation

struct {{ name }}Coordinator {
    enum Source: Equatable { case live, preview }
    let source: Source
}

enum {{ name }}TeamOperations {
    static let profileID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    static func submit(_ name: String, _ note: String) throws {
        guard name == "Edited name", note == "Edited note" else { throw URLError(.badServerResponse) }
    }

    static func retrying<Value>(_ value: Value) -> () async throws -> Value {
        var didAttempt = false
        return {
            guard didAttempt else {
                didAttempt = true
                throw URLError(.notConnectedToInternet)
            }
            return value
        }
    }
}
""")
    (templates / "controls.swift.stencil").write_text("""
import SwiftUI

struct {{ name }}TeamTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text)
            .textFieldStyle(.roundedBorder)
    }
}

struct {{ name }}TeamRow: View {
    let title: String

    var body: some View {
        Label(title, systemImage: "star")
    }
}
""")
    (templates / "teamTests.swift.stencil").write_text("""
import XCTest
@testable import {{ moduleName }}

final class {{ name }}TeamTests: XCTestCase {
    @MainActor
    func testLiveFeatureUsesTeamConstruction() async {
        let view = {{ name }}Feature.makeView() as? {{ name }}View
        XCTAssertEqual(view?.teamCoordinatorSource, .live)
        let model = {{ name }}DependencyContainer.makeViewModel()
        XCTAssertEqual(model.coordinator?.source, .live)
        let preview = {{ name }}Preview.makeViewModel()
        XCTAssertEqual(preview.coordinator?.source, .preview)
{% if isForm %}
        await model.submit()
        XCTAssertNotNil(model.errorMessage)
        model.field1 = "Edited name"
        model.field2 = "Edited note"
        await model.submit()
        XCTAssertTrue(model.didSubmit)
        XCTAssertNil(model.errorMessage)
{% endif %}
{% if isList %}
        await model.load()
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(model.items.isEmpty)
        await model.load()
        XCTAssertEqual(model.items.map(\\.title), ["Team profile"])
        XCTAssertNil(model.errorMessage)
{% endif %}
    }
}
""")
    model = templates / "viewModel.swift.stencil"
    model.write_text(model.read_text().replace("{{ forge.viewModelInitializers }}", """    let coordinator: {{ name }}Coordinator?

    init(coordinator: {{ name }}Coordinator? = nil{{ forge.viewModelInitializerParametersAfterComma }}) {
        self.coordinator = coordinator
        {{ forge.viewModelInitializerAssignments }}
    }

{% if isClean %}
{% if isForm %}
    convenience init(
        coordinator: {{ name }}Coordinator? = nil,
        {% if hasNoDomain %}repository: {{ name }}RepositoryImpl{% else %}useCase: {{ name }}UseCase{% endif %}
    ) {
        self.init(coordinator: coordinator, submitAction: { first, second in
{% if hasNoDomain %}
            try await repository.submit{{ name }}(field1: first, field2: second)
{% else %}
            try await useCase.submit(field1: first, field2: second)
{% endif %}
        })
    }
{% endif %}
{% if isList %}
    convenience init(
        coordinator: {{ name }}Coordinator? = nil,
        {% if hasNoDomain %}repository: {{ name }}RepositoryImpl{% else %}useCase: {{ name }}UseCase{% endif %}
    ) {
        self.init(coordinator: coordinator, loadItems: {
{% if hasNoDomain %}
            let value = try await repository.fetch{{ name }}()
{% else %}
            let value = try await useCase.execute()
{% endif %}
            return [{{ name }}Item(id: value.id, title: value.title)]
        })
    }
{% endif %}
{% endif %}"""))

    container = templates / "dependencyContainer.swift.stencil"

    def inject_coordinator(source, origin):
        def constructor(match):
            prefix = "{{ name }}ViewModel(coordinator: .init(source: ." + origin + ")"
            if not match[1]:
                return prefix + ", "
            if origin == "preview":
                return prefix + ")"
            return prefix + """{% if isForm %}, submitAction: {{ name }}TeamOperations.submit{% endif %}{% if isList %}, loadItems: {{ name }}TeamOperations.retrying([
                {{ name }}Item(id: {{ name }}TeamOperations.profileID, title: "Team profile")
            ]){% endif %})"""

        return re.sub(r"\{\{ name \}\}ViewModel\((?!coordinator:)(\))?", constructor, source)

    # Give previews an explicit dependency before wiring live calls in both DI branches.
    composition = re.sub(r"^enum \{\{ name \}\}Preview \{[\s\S]*?^\}",
                         lambda match: inject_coordinator(match[0], "preview"),
                         container.read_text(), flags=re.MULTILINE)
    container.write_text(inject_coordinator(composition, "live")
                         .replace("{{ name }}RemoteDataSource()", "{{ name }}RemoteDataSource.teamFixture()"))

    remote = templates / "remoteDataSource.swift.stencil"
    remote.write_text(remote.read_text() + """
{% if isClean %}
extension {{ name }}RemoteDataSource {
    static func teamFixture() -> {{ name }}RemoteDataSource {
        {{ name }}RemoteDataSource(
            fetch: {{ name }}TeamOperations.retrying(
                {{ name }}Response(id: {{ name }}TeamOperations.profileID, title: "Team profile")
            ),
            submit: {{ name }}TeamOperations.submit
        )
    }
}
{% endif %}
""")
    view = templates / "view.swift.stencil"
    view.write_text(
        view.read_text()
        .replace("struct {{ name }}View: View {",
                 "struct {{ name }}View: View {\n    let teamCoordinatorSource: {{ name }}Coordinator.Source?")
        .replace("init(viewModel: {{ name }}ViewModel) {",
                 "init(viewModel: {{ name }}ViewModel) {\n        teamCoordinatorSource = viewModel.coordinator?.source")
        .replace('TextField("Field 1", text: {{ forge.field1Binding }})',
                 '{{ name }}TeamTextField(title: "Display name", text: {{ forge.field1Binding }})')
        .replace("Text(item.title)", "{{ name }}TeamRow(title: item.title)")
    )


def customize_mvi(directory):
    """Compile a team-owned store initializer and use it from the feature factory."""
    config = directory / ".forge.yml"
    config.write_text(config.read_text() + """
    teamTests:
      template: teamTests.swift.stencil
      output: "Team/{{ name }}TeamTests.swift"
      target: test
""")
    templates = directory / ".templates"
    store = templates / "store.swift.stencil"
    store.write_text(store.read_text().replace("{{ forge.storeInitializers }}", """    let teamSource: String

    init(teamSource: String = "test"{{ forge.storeInitializerParametersAfterComma }}) {
        self.teamSource = teamSource
        {{ forge.storeInitializerAssignments }}
    }

{% if isClean %}
    convenience init(
        teamSource: String = "test",
        state: {{ name }}State = {{ name }}State(),
        {% if hasNoDomain %}repository: {{ name }}RepositoryImpl{% else %}useCase: {{ name }}UseCase{% endif %},
        reducer: {{ name }}Reducer
    ) {
        self.init(teamSource: teamSource, state: state, reducer: reducer, loadValue: {
{% if hasNoDomain %}
            try await repository.fetch{{ name }}()
{% else %}
            try await useCase.execute()
{% endif %}
        }{% if isForm %}, submitAction: { first, second in
{% if hasNoDomain %}
            try await repository.submit{{ name }}(field1: first, field2: second)
{% else %}
            try await useCase.submit(field1: first, field2: second)
{% endif %}
        }{% endif %})
    }
{% endif %}"""))
    container = templates / "dependencyContainer.swift.stencil"
    preview = r"^enum \{\{ name \}\}Preview \{[\s\S]*?^\}"
    initializer = "{{ name }}Store(reducer: {{ name }}Reducer()"
    def inject_team_source(source, origin):
        def clean_constructor(match):
            return '{{ name }}Store(teamSource: "' + origin + '", ' + match[1] + ':'

        source = re.sub(r"\{\{ name \}\}Store\((repository|useCase):", clean_constructor, source)
        replacement = '{{ name }}Store(teamSource: "' + origin + '", reducer: {{ name }}Reducer()'
        if origin == "live":
            replacement += """{% if isForm %}, submitAction: { first, second in
                guard first == "Edited name", second == "Edited note" else { throw URLError(.badServerResponse) }
            }{% endif %}{% if isList %}, loadValue: {
                [{{ name }}Item(id: UUID(), title: "Team profile")]
            }{% endif %}"""
        return source.replace(initializer, replacement)

    source = re.sub(preview, lambda match: inject_team_source(match[0], "preview"), container.read_text(), flags=re.MULTILINE)
    # The preview already starts with teamSource, so the live replacements skip it.
    container.write_text(inject_team_source(source, "live")
                         .replace("{{ name }}RemoteDataSource()", "{{ name }}RemoteDataSource.teamFixture()"))
    remote = templates / "remoteDataSource.swift.stencil"
    remote.write_text(remote.read_text() + """
{% if isClean %}
extension {{ name }}RemoteDataSource {
    static func teamFixture() -> {{ name }}RemoteDataSource {
        {{ name }}RemoteDataSource(
            fetch: { {{ name }}Response(id: UUID(), title: "Team profile") },
            submit: { first, second in
                guard first == "Edited name", second == "Edited note" else { throw URLError(.badServerResponse) }
            }
        )
    }
}
{% endif %}
""")
    view = templates / "view.swift.stencil"
    view.write_text(
        view.read_text()
        .replace("struct {{ name }}View: View {", "struct {{ name }}View: View {\n    let teamSource: String")
        .replace("init(store: {{ name }}Store) {", "init(store: {{ name }}Store) {\n        teamSource = store.teamSource")
    )
    (templates / "teamTests.swift.stencil").write_text("""
import XCTest
@testable import {{ moduleName }}

final class {{ name }}TeamTests: XCTestCase {
    @MainActor
    func testLiveFeatureUsesCustomStoreInitializer() async {
        let view = {{ name }}Feature.makeView() as? {{ name }}View
        XCTAssertEqual(view?.teamSource, "live")
        let store = {{ name }}DependencyContainer.makeStore()
        XCTAssertEqual(store.teamSource, "live")
        XCTAssertEqual({{ name }}Preview.makeStore().teamSource, "preview")
{% if isForm %}
        await store.send(.submit)
        XCTAssertNotNil(store.state.errorMessage)
        store.updateField1("Edited name")
        store.updateField2("Edited note")
        await store.send(.submit)
        XCTAssertTrue(store.state.didSubmit)
        XCTAssertNil(store.state.errorMessage)
{% endif %}
{% if isList %}
        await store.send(.onAppear)
        XCTAssertEqual(store.state.items.map(\\.title), ["Team profile"])
{% endif %}
    }
}
""")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--architecture", action="append", choices=ARCHITECTURES,
        help="repeat to select architectures; default: all",
    )
    parser.add_argument("--stack", action="store_true", help="generate with editable architecture templates")
    parser.add_argument("--forge", type=Path, help="use an already-built Forge executable")
    parser.add_argument("--jobs", type=positive_int, default=4, help="Swift compiler jobs (default: 4)")
    parser.add_argument(
        "--timeout", type=positive_int, default=300,
        help="timeout per command in seconds (default: 300)",
    )
    parser.add_argument(
        "--binding", choices=("combine", "concurrency"), default="combine",
        help="state binding strategy (combine, concurrency; default: combine)",
    )
    parser.add_argument(
        "--testing", choices=("xctest", "swift-testing"), default="xctest",
        help="unit testing framework (xctest, swift-testing; default: xctest)",
    )
    parser.add_argument(
        "--di", choices=("native", "factory"), default="native",
        help="dependency injection strategy (native, factory; default: native)",
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
    team_tests = {
        "mvvm": "testLiveFeatureUsesTeamConstruction",
        "mvi": "testLiveFeatureUsesCustomStoreInitializer",
    }
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
                config_lines = [
                    f"binding: {args.binding}",
                    f"testing: {args.testing}",
                    f"di: {args.di}",
                ]
                (Path(directory) / ".forge.yml").write_text("\n".join(config_lines) + "\n")
                with log_path.open("w") as log:
                    if args.stack:
                        run([str(forge), "init", f"-{architecture}", "--path", directory], ROOT, log, args.timeout)
                        if architecture == "mvvm":
                            customize_mvvm(Path(directory))
                        elif architecture == "mvi":
                            customize_mvi(Path(directory))
                        run([str(forge), "validate", "--path", directory], ROOT, log, args.timeout)
                    # The module deliberately differs from the feature name.
                    run([
                        str(forge), "make", "Sample", f"-{architecture}",
                        "--package", "--tests", "--target", target,
                        "--path", directory, *LAYERS[layer], *LAYOUTS[layout],
                    ], ROOT, log, args.timeout)

                    # Compile a separate consumer with a normal import. @testable hides API visibility bugs.
                    consumer = Path(directory) / "Consumer"
                    (consumer / "Sources" / "Consumer").mkdir(parents=True)
                    (consumer / "Package.swift").write_text(f'''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Consumer", platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../Sample")],
    targets: [.target(name: "Consumer", dependencies: [.product(name: "{target}", package: "Sample")])])
''')
                    (consumer / "Sources" / "Consumer" / "Consumer.swift").write_text(f'''import SwiftUI
import {target.replace("-", "_")}
@MainActor public func feature() -> some View {{ SampleFeature.makeView() }}
''')
                    run(["swift", "build", "--package-path", str(consumer), "--jobs", str(args.jobs)],
                        ROOT, log, args.timeout)

                    expected_team_test = team_tests.get(architecture) if args.stack else None
                    if args.testing == "swift-testing":
                        test_output = run([
                            "swift", "test", "--package-path", str(Path(directory) / "Sample"),
                            "--jobs", str(args.jobs),
                        ], ROOT, log, args.timeout)
                        match = re.search(r"✔ Test run with (\d+) tests? in (\d+) suites? passed", test_output)
                        if not match or int(match.group(1)) == 0:
                            raise RuntimeError("no generated swift-testing tests passed")
                        executed_count = int(match.group(1))
                        if expected_team_test:
                            if not re.search(rf"Test Case '.*\b{expected_team_test}\]' passed", test_output):
                                raise RuntimeError(f"{expected_team_test} did not run and pass")
                            executed_count += 1
                    else:
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
                        if expected_team_test and not any(test.get("name") == expected_team_test for test in executed):
                            raise RuntimeError(f"{expected_team_test} did not run and pass")
                        executed_count = len(executed)
            print(f"PASS {name}: {executed_count} tests", flush=True)
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
