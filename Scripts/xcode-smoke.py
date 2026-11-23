#!/usr/bin/env python3
"""Build a disposable iOS host and verify generated features with hosted tests and UI tests."""

import argparse
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


FIXTURE = Path(__file__).resolve().parent / "fixtures" / "xcode-smoke"


def run(command, cwd, *, timeout=300, succeeds=True):
    try:
        result = subprocess.run(
            command, cwd=cwd, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, timeout=timeout,
        )
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or b"").decode(errors="replace")
        tail = "\n".join(output.splitlines()[-100:])
        raise RuntimeError(f"{' '.join(map(str, command))} timed out after {timeout}s\n{tail}") from error
    if (result.returncode == 0) != succeeds:
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
    selected_projects = [(workspace / line.removeprefix("Xcode project: ")).resolve()
                         for line in plan.splitlines() if line.startswith("Xcode project: ")]
    planned_files = {(workspace / line[4:]).resolve() for line in plan.splitlines() if line.startswith("  + ")}
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

    # Adopt templates in an existing app with its own dependency and controls.
    run([forge, "init", "-mvvm", "--path", workspace], nested)
    run([forge, "validate"], nested)
    run([forge, "make", "SmokeStarterForm", "-form", "--no-tests"], nested)
    with config.open("a", encoding="utf-8") as stream:
        stream.write("""
    coordinator:
      template: coordinator.stencil
      output: "Navigation/{{ name }}Coordinator.swift"
      target: source
    teamTests:
      template: teamTests.stencil
      output: "Team/{{ name }}TeamTests.swift"
      target: test
""")
    templates = workspace / ".templates"
    (templates / "coordinator.stencil").write_text("""
struct {{ name }}Coordinator {
    let context: SmokeFeatureContext
}
""", encoding="utf-8")
    (templates / "teamTests.stencil").write_text("""
import Testing
@testable import {{ moduleName }}

@Suite struct {{ name }}TeamTests {
    @MainActor
    @Test func liveFeatureUsesHostDependency() async {
        let view = {{ name }}DependencyContainer.makeView()
        #expect(view.teamOrigin == "live")
        let model = {{ name }}DependencyContainer.makeViewModel()
        #expect(model.coordinator.context.origin == "live")
        #expect({{ name }}Preview.makeViewModel().coordinator.context.origin == "preview")
{% if isForm %}
        await model.submit()
        #expect(model.errorMessage != nil)
        model.field1 = "Edited name"
        model.field2 = "Edited note"
        await model.submit()
        #expect(model.didSubmit)
        #expect(model.errorMessage == nil)
{% endif %}
{% if isList %}
        await model.load()
        #expect(model.errorMessage != nil)
        #expect(model.items.isEmpty)
        await model.load()
        #expect(model.items.map(\\.title) == ["Host profile"])
        #expect(model.errorMessage == nil)
{% endif %}
    }
}
""", encoding="utf-8")

    model = templates / "viewModel.swift.stencil"
    edited = model.read_text(encoding="utf-8").replace("{{ forge.viewModelInitializers }}", """    let coordinator: {{ name }}Coordinator

    init(context: SmokeFeatureContext = .init(origin: "test"){{ forge.viewModelInitializerParametersAfterComma }}) {
        coordinator = {{ name }}Coordinator(context: context)
        {{ forge.viewModelInitializerAssignments }}
    }""")
    model.write_text(edited, encoding="utf-8")
    view = templates / "view.swift.stencil"
    view.write_text(
        view.read_text(encoding="utf-8")
        .replace("struct {{ name }}View: View {", "struct {{ name }}View: View {\n    let teamOrigin: String")
        .replace("init(viewModel: {{ name }}ViewModel) {",
                 "init(viewModel: {{ name }}ViewModel) {\n        teamOrigin = viewModel.coordinator.context.origin")
        .replace('TextField("Field 1", text: {{ forge.field1Binding }})',
                 'SmokeTextField(title: "Display name", text: {{ forge.field1Binding }})')
        .replace('TextField("Field 2", text: {{ forge.field2Binding }})',
                 'TextField("Field 2", text: {{ forge.field2Binding }}).accessibilityIdentifier("team-note")')
        .replace("Text(item.title)", "SmokeListRow(title: item.title)"),
        encoding="utf-8",
    )
    container = templates / "dependencyContainer.swift.stencil"
    def initialize_model(source, origin):
        def replacement(match):
            prefix = '{{ name }}ViewModel(context: .init(origin: "' + origin + '")'
            if not match[1]:
                return prefix + ", "
            if origin == "preview":
                return prefix + ")"
            return prefix + """{% if isForm %}, submitAction: SmokeFeatureContext.submit{% endif %}{% if isList %}, loadItems: SmokeFeatureContext.retrying([
                {{ name }}Item(id: UUID(), title: "Host profile")
            ]){% endif %})"""
        return re.sub(r"\{\{ name \}\}ViewModel\((?!context:)(\))?", replacement, source)

    composition = re.sub(r"^enum \{\{ name \}\}Preview \{[\s\S]*?^\}",
                         lambda match: initialize_model(match[0], "preview"),
                         container.read_text(encoding="utf-8"), flags=re.MULTILINE)
    container.write_text(initialize_model(composition, "live"), encoding="utf-8")

    # Break only form generation, then follow the validator's repair in this host.
    marker = "{{ forge.viewModelProperties }}"
    model.write_text(edited.replace(marker, """{% if isForm %}
{% if isList %}
{{ forge.viewModelProperties }}
{% endif %}
{% else %}
{{ forge.viewModelProperties }}
{% endif %}"""), encoding="utf-8")
    broken_plan = run([forge, "validate"], nested, succeeds=False)
    if "'if isList'" not in broken_plan or "branch that runs for form" not in broken_plan:
        raise RuntimeError(f"Expected a repair for the blocking condition:\n{broken_plan}")
    run([forge, "make", "SmokeStackList", "-list", "--tests", "--dry-run"], nested)
    before_failed_make = project_file.read_bytes()
    run([forge, "make", "SmokeStackForm", "-form", "--tests"], nested, succeeds=False)
    failed_feature = project / features / "SmokeStackForm"
    if failed_feature.exists() or project_file.read_bytes() != before_failed_make:
        raise RuntimeError("Invalid form generation changed the host project")
    model.write_text(edited, encoding="utf-8")
    run([forge, "validate"], nested)

    stack_features = (("SmokeStackForm", "-form"), ("SmokeStackList", "-list"))
    for feature, flag in stack_features:
        run([forge, "make", feature, flag, "--tests"], nested)
    host = project / "SmokeApp.swift"
    host.write_text(host.read_text(encoding="utf-8").replace('Text("Forge")', """if ProcessInfo.processInfo.arguments.contains("--show-directory") {
                SmokeStackListDependencyContainer.makeView()
            } else {
                TabView {
                    SmokeStackFormDependencyContainer.makeView()
                        .tabItem { Label("Profile", systemImage: "person") }
                    SmokeStackListDependencyContainer.makeView()
                        .tabItem { Label("Directory", systemImage: "list.bullet") }
                }
            }"""), encoding="utf-8")

    derived_data = root / f"DerivedData-{layout}"
    output = run([
        "xcodebuild", "test", "-project", project / "Smoke.xcodeproj", "-scheme", "Smoke",
        "-destination", destination, "-derivedDataPath", derived_data,
        "-parallel-testing-enabled", "NO", "ONLY_ACTIVE_ARCH=YES",
    ], project, timeout=420)
    xctest = r"Test Case '-\[SmokeTests\.SmokeXCTestViewModelTests [^\]]+\]' passed"
    swift_testing = r"Suite SmokeSwiftTestingViewModelTests passed"
    stack_suites = tuple(rf"Suite {feature}TeamTests passed" for feature, _ in stack_features)
    ui_test = r"Test Case '-\[SmokeUITests\.SmokeUITests testCustomizedFormAndListThroughHostUI\]' passed"
    if not all(re.search(pattern, output) for pattern in (xctest, swift_testing, *stack_suites, ui_test)):
        raise RuntimeError(f"Expected generated and team suites to run and pass\n{output}")
    expected_sources = {f"{feature}ViewModel.swift" for feature in names} | {f"{feature}Coordinator.swift" for feature, _ in stack_features} | {"SmokeStarterFormViewModel.swift"}
    expected_tests = {f"{feature}ViewModelTests.swift" for feature in names} | {f"{feature}TeamTests.swift" for feature, _ in stack_features}
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
    print(f"PASS hosted XCTest, Swift Testing, and editable stack adoption in Xcode ({layout} folders)", flush=True)


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
