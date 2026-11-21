import XCTest
@testable import forge

final class ModelFragmentsTests: XCTestCase {
    func testManagedInitializersAcrossArchitecturesLayersCategoriesAndBindings() throws {
        for architecture in [PresentationArchitecture.mvvm, .mvi] {
            let role: FeatureFile = architecture == .mvvm ? .viewModel : .store
            let owner = architecture == .mvvm ? "SampleViewModel" : "SampleStore"
            for (clean, noDomain) in [(false, false), (true, false), (true, true)] {
                let type = FeatureType.resolve(presentation: architecture, clean: clean)
                for category in StackConfig.categories {
                    for observation in [false, true] {
                        let label = "\(type), noDomain=\(noDomain), \(String(describing: category)), observation=\(observation)"
                        let spec = try XCTUnwrap(type.templateSpecs(for: category).first { $0.file == role }, label)
                        let source = try TemplateRenderer.render(spec.templateName + ".stencil", context: [
                            "name": "Sample", "isConcurrency": observation, "isClean": clean,
                            "hasNoDomain": noDomain, "isForm": category == .form, "isList": category == .list,
                        ])
                        let fragments = try ModelFragments(model: source, owner: owner, role: role.rawValue)
                        let expectedDependencies: [String]
                        if architecture == .mvi {
                            expectedDependencies = ["state", "reducer"]
                                + (clean || category == .list ? ["loadValue"] : [])
                                + (category == .form ? ["submitAction"] : [])
                        } else if category == .form {
                            expectedDependencies = ["submitAction"]
                        } else if category == .list {
                            expectedDependencies = ["loadItems"]
                        } else if clean {
                            expectedDependencies = [noDomain ? "repository" : "useCase"]
                        } else {
                            expectedDependencies = []
                        }

                        XCTAssertEqual(fragments.initializers.isEmpty, expectedDependencies.isEmpty, label)
                        XCTAssertTrue(fragments.actions.contains(architecture == .mvi ? "func send(" :
                            (category == .form ? "func submit(" : "func load(")), label)
                        XCTAssertEqual(fragments.assignments.split(whereSeparator: \.isNewline).map(String.init),
                                       expectedDependencies.map { "        self.\($0) = \($0)" }, label)
                        for dependency in expectedDependencies {
                            XCTAssertTrue(fragments.parameters.contains("\(dependency):"), label)
                        }

                        let prefix = "forge." + role.rawValue
                        var values: [String: Any] = [:]
                        fragments.add(to: &values, prefix: prefix)
                        for (parameterKey, leadingParameter) in [
                            ("InitializerParameters", ""),
                            ("InitializerParametersAfterComma", "teamID: String"),
                        ] {
                            let initializer = try TemplateRenderer.renderSource("""
                            init(\(leadingParameter){{ \(prefix + parameterKey) }}) {
                                {{ \(prefix)InitializerAssignments }}
                            }
                            """, context: values, name: label)
                            let separator = leadingParameter.isEmpty || expectedDependencies.isEmpty ? "" : ", "
                            XCTAssertTrue(initializer.hasPrefix("init(\(leadingParameter)\(separator)\(fragments.parameters)) {\n"), label)
                            for dependency in expectedDependencies {
                                XCTAssertTrue(initializer.contains("\n    self.\(dependency) = \(dependency)\n"), label)
                            }
                        }
                    }
                }
            }
        }
    }

    func testMissingBuiltInBoundariesAreReported() {
        let invalidModels = [
            "struct SampleStore {}",
            "\nfinal class SampleStore {}",
            "\nfinal class SampleStore {\n    let value = 1\n}",
            "\nfinal class SampleStore {\n    init(value: Int) {\n    func send() {}\n}",
        ]
        for model in invalidModels {
            XCTAssertThrowsError(try ModelFragments(model: model, owner: "SampleStore", role: "store")) {
                XCTAssertTrue(($0 as? ForgeError)?.message.contains("built-in 'store' template") == true)
            }
        }
    }
}
