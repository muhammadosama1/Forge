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
            of: "{{ forge.viewModelProperties }}", with: "    let teamValue = 42\n{{ forge.viewModelProperties }}")
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
        try edited.replacingOccurrences(of: "{{ forge.viewModelProperties }}",
                                         with: "{% if isForm %}{% else %}{{ forge.viewModelProperties }}{% endif %}")
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
            XCTAssertTrue(message.contains("Missing active '{{ forge.viewModelProperties }}' for form"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("NewLogin").path))
        try edited.write(to: template, atomically: true, encoding: .utf8)
        try StackWorkflow.validate(arguments: ["validate", "--path", root.path])
        try make("NewLogin", ["-form"])
        try make("NewOrders", ["-list"])
    }

    func testCustomInitializerAddsCommaOnlyForManagedParametersAndPreservesIndentation() throws {
        try initialize()
        let template = root.appendingPathComponent(".templates/viewModel.swift.stencil")
        let custom = """
            let teamID: String

            init(teamID: String{{ forge.viewModelInitializerParametersAfterComma }}) {
                self.teamID = teamID
                {{ forge.viewModelInitializerAssignments }}
            }
        """
        let source = try String(contentsOf: template, encoding: .utf8)
        try source.replacingOccurrences(of: "{{ forge.viewModelInitializers }}", with: custom)
            .write(to: template, atomically: true, encoding: .utf8)
        try StackWorkflow.validate(arguments: ["validate", "--path", root.path])
        try make("Default")
        try make("Login", ["-form"])
        for (name, declaration) in [
            ("Default", "init(teamID: String)"),
            ("Login", "init(teamID: String, submitAction:")
        ] {
            let model = try String(contentsOf: root.appendingPathComponent("\(name)/Presentation/\(name)ViewModel.swift"), encoding: .utf8)
            XCTAssertTrue(model.contains(declaration))
            XCTAssertTrue(model.contains("        self.teamID = teamID"))
            XCTAssertFalse(model.contains("                self.submitAction = submitAction"))
        }
    }

    func testRejectsDuplicateOrMixedInsertionPointsAndAcceptsLegacyMembers() throws {
        try initialize()
        let template = root.appendingPathComponent(".templates/viewModel.swift.stencil")
        let source = try String(contentsOf: template, encoding: .utf8)
        let properties = "{{ forge.viewModelProperties }}"
        for (replacement, issue) in [
            (properties + "\n" + properties, "is repeated"),
            (properties + "\n{{ forge.viewModelMembers }}", "Mixed model insertion points")
        ] {
            try source.replacingOccurrences(of: properties, with: replacement).write(to: template, atomically: true, encoding: .utf8)
            XCTAssertThrowsError(try make("Login", ["-form"])) { error in
                let message = (error as? ForgeError)?.message ?? ""
                XCTAssertTrue(message.contains(issue))
                XCTAssertTrue(message.contains("form"))
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Login").path))
        try source.replacingOccurrences(of: properties, with: "{{ forge.viewModelMembers }}")
            .replacingOccurrences(of: "{{ forge.viewModelInitializers }}", with: "")
            .replacingOccurrences(of: "{{ forge.viewModelActions }}", with: "")
            .write(to: template, atomically: true, encoding: .utf8)
        try StackWorkflow.validate(arguments: ["validate", "--path", root.path])
        try make("Login", ["-form"])
    }

    func testEachCustomInitializerMarkerIsRequiredOnItsActivePath() throws {
        try initialize("-mvi")
        let template = root.appendingPathComponent(".templates/store.swift.stencil")
        let source = try String(contentsOf: template, encoding: .utf8)
        let custom = source.replacingOccurrences(of: "{{ forge.storeInitializers }}", with: """
            init({{ forge.storeInitializerParameters }}) {
                {{ forge.storeInitializerAssignments }}
            }
        """)
        for key in ["InitializerParameters", "InitializerAssignments"] {
            let marker = "{{ forge.store\(key) }}"
            let conditional = custom.replacingOccurrences(of: marker, with: "{% if isForm %}{% else %}\(marker){% endif %}")
            try conditional.write(to: template, atomically: true, encoding: .utf8)
            try make("Orders", ["-list", "--dry-run"])
            XCTAssertThrowsError(try make("Login", ["-form"])) { error in
                let message = (error as? ForgeError)?.message ?? ""
                XCTAssertTrue(message.contains("Missing active '\(marker)' for form"), message)
                XCTAssertTrue(message.contains("Restore it"), message)
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Login").path))
        }
        try custom.write(to: template, atomically: true, encoding: .utf8)
        try StackWorkflow.validate(arguments: ["validate", "--path", root.path])
        try make("Login", ["-form"])
    }

    func testValidationAndSetupRerunReportMissingInactiveTemplates() throws {
        try initialize()
        let testTemplate = root.appendingPathComponent(".templates/viewModelTests.swift.stencil")
        try FileManager.default.removeItem(at: testTemplate)
        // Test generation is off in the starter defaults.
        try make("Profile", ["--dry-run"])
        XCTAssertThrowsError(try StackWorkflow.validate(arguments: ["validate", "--path", root.path])) { error in
            let message = (error as? ForgeError)?.message ?? ""
            XCTAssertTrue(message.contains(testTemplate.path))
            XCTAssertTrue(message.contains("Restore the template or correct its path"))
        }
        XCTAssertThrowsError(try initialize())
        XCTAssertFalse(FileManager.default.fileExists(atPath: testTemplate.path))
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

    func testSetupRollsBackPublishedTemplatesAfterADanglingSymlinkConflict() throws {
        let files = FileManager.default
        let templates = root.appendingPathComponent(".templates", isDirectory: true)
        try files.createDirectory(at: templates, withIntermediateDirectories: true)
        let lastTemplate = try XCTUnwrap(StackTemplates.starter(for: .mvvm).keys.sorted().last)
        let collision = templates.appendingPathComponent(lastTemplate)
        let missingTarget = root.appendingPathComponent("missing.stencil")
        try files.createSymbolicLink(at: collision, withDestinationURL: missingTarget)
        XCTAssertThrowsError(try initialize()) { error in
            XCTAssertTrue((error as? ForgeError)?.message.contains(lastTemplate) == true)
        }
        XCTAssertEqual(try files.contentsOfDirectory(atPath: templates.path), [lastTemplate])
        XCTAssertEqual(try files.destinationOfSymbolicLink(atPath: collision.path), missingTarget.path)
        XCTAssertFalse(files.fileExists(atPath: root.appendingPathComponent(".forge.yml").path))
        try files.removeItem(at: collision)
        try initialize()
        try StackWorkflow.validate(arguments: ["validate", "--path", root.path])
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

    func testSetupRejectsConflictingConfigFilesAndArchitecture() throws {
        let yaml = root.appendingPathComponent(".forge.yaml")
        let yml = root.appendingPathComponent(".forge.yml")
        let settings = "architecture: mvi\n"
        try settings.write(to: yaml, atomically: true, encoding: .utf8)
        try settings.write(to: yml, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try initialize("-mvi")) { error in
            XCTAssertTrue((error as? ForgeError)?.message.contains("Both config filenames exist") == true)
        }
        try FileManager.default.removeItem(at: yml)
        XCTAssertThrowsError(try initialize("-mvvm")) { error in
            XCTAssertTrue((error as? ForgeError)?.message.contains("project already uses MVI") == true)
        }
        XCTAssertEqual(try String(contentsOf: yaml, encoding: .utf8), settings)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".templates").path))
    }

    func testSetupRejectsSymlinkedConfigurationAndTemplateDirectory() throws {
        let destination = root.appendingPathComponent("target", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let externalConfig = destination.appendingPathComponent("settings.yml")
        let settings = "architecture: mvvm\n"
        try settings.write(to: externalConfig, atomically: true, encoding: .utf8)
        let config = root.appendingPathComponent(".forge.yml")
        try FileManager.default.createSymbolicLink(at: config, withDestinationURL: externalConfig)
        XCTAssertThrowsError(try initialize()) { error in
            XCTAssertTrue((error as? ForgeError)?.message.contains("is a symlink") == true)
        }
        try FileManager.default.removeItem(at: config)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent(".templates"), withDestinationURL: destination)
        XCTAssertThrowsError(try initialize()) { error in
            XCTAssertTrue((error as? ForgeError)?.message.contains(".templates symlink") == true)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path), ["settings.yml"])
        XCTAssertEqual(try String(contentsOf: externalConfig, encoding: .utf8), settings)
        XCTAssertFalse(FileManager.default.fileExists(atPath: config.path))
    }

    func testValidationHandlesMissingStackBadArgumentsAndDisabledCategories() throws {
        XCTAssertThrowsError(try StackWorkflow.validate(arguments: ["validate", "--path", root.path])) { error in
            XCTAssertTrue((error as? ForgeError)?.message.contains("No editable stack is active") == true)
        }
        XCTAssertThrowsError(try StackWorkflow.validate(arguments: ["validate", "--config"])) { error in
            XCTAssertTrue((error as? ForgeError)?.message.contains("Use forge validate") == true)
        }

        try initialize()
        let config = root.appendingPathComponent(".forge.yml")
        let original = try String(contentsOf: config, encoding: .utf8)
        try original.replacingOccurrences(of: "  version: 1", with: "  version: 1\n  categories:\n    form: false")
            .write(to: config, atomically: true, encoding: .utf8)
        let template = root.appendingPathComponent(".templates/viewModel.swift.stencil")
        let edited = try String(contentsOf: template, encoding: .utf8).replacingOccurrences(
            of: "{{ forge.viewModelActions }}", with: "{% if isForm %}{% else %}{{ forge.viewModelActions }}{% endif %}")
        try edited.write(to: template, atomically: true, encoding: .utf8)
        try StackWorkflow.validate(arguments: ["validate", "--config", config.path])
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
        try make("FilesOnly", ["--files-only", "--no-tests"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("FilesOnly/Navigation/FilesOnlyCoordinator.swift").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("FilesOnly/Tests").path))
        try updated.replacingOccurrences(of: "Navigation/{{ name }}Coordinator.swift",
                                          with: "presentation/{{ name }}view.swift")
            .write(to: config, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try make("Conflict")) { error in
            XCTAssertTrue((error as? ForgeError)?.message.contains("Output conflict") == true)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Conflict").path))
    }
}
