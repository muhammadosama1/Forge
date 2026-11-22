import XCTest
@testable import forge

final class StackConfigTests: XCTestCase {
    func testRejectsUnsupportedVersionCategoriesAndRoles() {
        let cases: [([String: Any], String)] = [
            (["version": 2], "stack.version: 1"),
            (["version": 1, "categories": "form"], "stack.categories to a mapping"),
            (["version": 1, "files": "helper"], "stack.files to a mapping"),
            (["version": 1, "categories": ["grid": true]], "stack.categories.grid"),
            (["version": 1, "categories": ["default": false, "form": false, "list": false]], "Enable at least one screen"),
            (["version": 1, "files": ["view": ["template": "view.stencil", "output": "View.swift"]]], "inherits its output and target"),
            (["version": 1, "files": ["store": ["template": "store.stencil", "output": "Store.swift", "target": "source"]]], "selected architecture"),
            (["version": 1, "files": ["helper": ["template": "helper.stencil", "output": "Helper.swift", "target": "invalid"]]], "target: source or test"),
        ]
        for (values, expected) in cases {
            XCTAssertThrowsError(try StackConfig(values, architecture: .mvvm)) { error in
                let message = (error as? ForgeError)?.message ?? ""
                XCTAssertTrue(message.contains(expected), message)
            }
        }
    }

    func testRejectsAbsoluteAndTraversingTemplateAndOutputPaths() {
        for path in ["/absolute/file", "../escape", "nested/../../escape", "./relative", "nested//file", "nested\\file"] {
            let config: [String: Any] = ["version": 1, "files": [
                "helper": ["template": path + ".stencil", "output": "Helper.swift", "target": "source"],
            ]]
            XCTAssertThrowsError(try StackConfig(config, architecture: .mvvm)) { error in
                XCTAssertTrue((error as? ForgeError)?.message.contains("relative .stencil path") == true)
            }
            let output: [String: Any] = ["version": 1, "files": [
                "helper": ["template": "helper.stencil", "output": path + ".swift", "target": "source"],
            ]]
            XCTAssertThrowsError(try StackConfig(output, architecture: .mvvm)) { error in
                XCTAssertTrue((error as? ForgeError)?.message.contains("relative Swift output") == true)
            }
        }
    }
}
