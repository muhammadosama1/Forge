import Foundation
import XCTest
@testable import forge

final class StackWorkflowTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    private func initialize(_ architecture: String = "-mvvm") throws {
        try Command.runInit(arguments: ["init", architecture, "--path", root.path])
    }

    private func make(_ name: String, _ options: [String] = []) throws {
        try Command.parse(arguments: ["make", name, "--path", root.path] + options).run()
    }

    func testStarterRendersAllArchitecturesAndCategories() throws {
        for architecture in PresentationArchitecture.allCases {
            root = root.appendingPathComponent(architecture.rawValue)
            try initialize("-" + architecture.rawValue)
            try StackWorkflow.validate(arguments: ["validate", "--path", root.path])
            for category in StackConfig.categories {
                try make("Example", ["--no-domain", "--tests", "--dry-run"] + (category.map { ["-" + $0.rawValue] } ?? []))
            }
            root.deleteLastPathComponent()
        }
    }

    func testOneEditedModelKeepsFormAndListWiringAndSurvivesInit() throws {
        try initialize()
        let template = root.appendingPathComponent(".templates/viewModel.swift.stencil")
        let edited = try String(contentsOf: template, encoding: .utf8).replacingOccurrences(
            of: "{{ forge.viewModelMembers }}", with: "    let teamValue = 42\n{{ forge.viewModelMembers }}")
        try edited.write(to: template, atomically: true, encoding: .utf8)
        try initialize()
        XCTAssertEqual(try String(contentsOf: template, encoding: .utf8), edited)
        try make("Login", ["-form"])
        try make("Orders", ["-list"])
        for (name, expectedState, expectedBinding) in [
            ("Login", "var field1", "$viewModel.field1"),
            ("Orders", "var items:", "List(viewModel.items)")
        ] {
            let directory = root.appendingPathComponent("\(name)/Presentation")
            let model = try String(contentsOf: directory.appendingPathComponent("\(name)ViewModel.swift"), encoding: .utf8)
            let view = try String(contentsOf: directory.appendingPathComponent("\(name)View.swift"), encoding: .utf8)
            XCTAssertTrue(model.contains("let teamValue = 42"))
            XCTAssertTrue(model.contains(expectedState))
            XCTAssertTrue(view.contains(expectedBinding))
        }
        try edited.replacingOccurrences(of: "{{ forge.viewModelMembers }}",
                                         with: "{% if isForm %}{% else %}{{ forge.viewModelMembers }}{% endif %}")
            .write(to: template, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try StackWorkflow.validate(arguments: ["validate", "--path", root.path])) { error in
            let message = (error as? ForgeError)?.message ?? ""
            XCTAssertTrue(message.contains("\nform:"))
            XCTAssertFalse(message.contains("\ndefault:"))
            XCTAssertFalse(message.contains("\nlist:"))
        }
        try make("NewOrders", ["-list", "--dry-run"])
        XCTAssertThrowsError(try make("NewLogin", ["-form"])) { error in
            let message = (error as? ForgeError)?.message ?? ""
            XCTAssertTrue(message.contains("viewModel.swift.stencil:"))
            XCTAssertTrue(message.contains("Missing active '{{ forge.viewModelMembers }}' for form"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("NewLogin").path))
    }

    func testInterruptedSetupCanResumeAndEditedFilesAreProtected() throws {
        let templates = root.appendingPathComponent(".templates")
        try FileManager.default.createDirectory(at: templates, withIntermediateDirectories: true)
        let view = templates.appendingPathComponent("view.swift.stencil")
        try "// Existing team work".write(to: view, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try initialize())
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".forge.yml").path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: templates.path), ["view.swift.stencil"])

        let starter = try XCTUnwrap(StackTemplates.starter(for: .mvvm)["view.swift.stencil"])
        try starter.write(to: view, atomically: true, encoding: .utf8)
        try initialize()
        try StackWorkflow.validate(arguments: ["validate", "--path", root.path])
        XCTAssertEqual(try String(contentsOf: view, encoding: .utf8), starter)
    }

    func testTemplateSymlinkCannotEscapeAndDisabledScreensFailEarly() throws {
        try initialize()
        let config = root.appendingPathComponent(".forge.yml")
        let original = try String(contentsOf: config, encoding: .utf8)
        try original.replacingOccurrences(of: "  version: 1", with: "  version: 1\n  categories:\n    list: false")
            .write(to: config, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try make("Orders", ["-list"])) { error in
            XCTAssertTrue((error as? ForgeError)?.message.contains("stack.categories.list") == true)
        }
        XCTAssertThrowsError(try make("Orders", ["-mvi"])) { error in
            XCTAssertTrue((error as? ForgeError)?.message.contains("configured stack") == true)
        }
        let view = root.appendingPathComponent(".templates/view.swift.stencil")
        let external = root.appendingPathComponent("outside.stencil")
        try FileManager.default.moveItem(at: view, to: external)
        try FileManager.default.createSymbolicLink(at: view, withDestinationURL: external)
        XCTAssertThrowsError(try make("Profile")) { error in
            XCTAssertTrue((error as? ForgeError)?.message.contains("escapes .templates") == true)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Profile").path))
    }

    func testLegacyAdoptionPreservesConfigCommentsAndRequiresConsent() throws {
        let config = root.appendingPathComponent(".forge.yaml")
        let original = "# Team settings\narchitecture: mvi\nbinding: concurrency\n"
        try original.write(to: config, atomically: true, encoding: .utf8)
        try TemplateCatalog.run(arguments: ["templates", "export", "mviStore", "--path", root.path])
        XCTAssertThrowsError(try initialize("-mvi"))
        try Command.runInit(arguments: ["init", "--adopt", "--path", root.path])
        XCTAssertTrue(try String(contentsOf: config, encoding: .utf8).hasPrefix(original))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(".forge/templates/mviStore.stencil").path))
        try StackWorkflow.validate(arguments: ["validate", "--config", config.path])
    }

    func testCustomRolesRouteToPackageTargetsAndCollisionsFailBeforeWriting() throws {
        try initialize()
        let config = root.appendingPathComponent(".forge.yml")
        let original = try String(contentsOf: config, encoding: .utf8)
        let roles = """
            coordinator:
              template: coordinator.stencil
              output: "Navigation/{{ name }}Coordinator.swift"
              target: source
            helper:
              template: helper.stencil
              output: "Support/{{ name }}Helper.swift"
              target: test

        """
        // Insert before the trailing starter comments and retain their original indentation.
        let updated = original.replacingOccurrences(of: "\n# Add team-specific", with: "\n" + roles + "\n# Add team-specific")
        try updated.write(to: config, atomically: true, encoding: .utf8)
        for name in ["coordinator", "helper"] {
            try "struct {{ name }}\(name.capitalized) {}\n".write(
                to: root.appendingPathComponent(".templates/\(name).stencil"), atomically: true, encoding: .utf8)
        }
        try make("Profile", ["--package", "--tests"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Profile/Sources/Profile/Navigation/ProfileCoordinator.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Profile/Tests/ProfileTests/Support/ProfileHelper.swift").path))
        try updated.replacingOccurrences(of: "Navigation/{{ name }}Coordinator.swift",
                                          with: "presentation/{{ name }}view.swift")
            .write(to: config, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try make("Conflict")) { error in
            XCTAssertTrue((error as? ForgeError)?.message.contains("Output conflict") == true)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Conflict").path))
    }
}
