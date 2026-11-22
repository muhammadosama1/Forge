import XCTest
@testable import forge

final class TemplateDiagnosticTests: XCTestCase {
    func testUnterminatedTagIdentifiesOpeningLineAndClosingDelimiter() {
        for (opening, closing) in [("{{", "}}"), ("{%", "%}")] {
            for suffix in ["", "\n{{ name }}\n{% if yes %}{% endif %}"] {
                let raw = "{{ name }}\nSwift code\n\n\(opening) unfinished" + suffix
                XCTAssertThrowsError(try TemplateRenderer.renderSource(raw, context: ["name": "Profile", "yes": true],
                                                                      name: "View.stencil")) { error in
                    let message = (error as? ForgeError)?.message ?? ""
                    XCTAssertTrue(message.contains("View.stencil:4: unterminated template tag"), message)
                    XCTAssertTrue(message.contains("Close the tag with '\(closing)'"), message)
                }
            }
        }
    }

    func testMissingInsertionNamesOuterBlockWhenNestedConditionsAlsoFail() throws {
        let raw = """
        imports
        {% if isList %}
        {% if isClean %}
        {{ forge.viewModelProperties }}
        {% endif %}
        {% endif %}
        """
        XCTAssertThrowsError(try TemplateRenderer.renderSource(raw, context: [
            "isList": false, "isClean": false, "forge.viewModelProperties": "state",
        ], name: "ViewModel.stencil", required: ["forge.viewModelProperties"], category: "form")) { error in
            let message = (error as? ForgeError)?.message ?? ""
            XCTAssertTrue(message.contains("ViewModel.stencil:4:"), message)
            XCTAssertTrue(message.contains("'if isList' on line 2 is false"), message)
            XCTAssertTrue(message.contains("needs these model properties"), message)
            XCTAssertFalse(message.contains("'if isClean'"), message)
        }
    }

    func testMissingInsertionInElseNamesTheRelevantIfAndElseLines() {
        let raw = """
        {% if isClean %}
        {% if isForm %}
        other content
        {% else %}
        {{ forge.field1Binding }}
        {% endif %}
        {% endif %}
        """
        XCTAssertThrowsError(try TemplateRenderer.renderSource(raw, context: [
            "isClean": true, "isForm": true, "forge.field1Binding": "binding",
        ], name: "View.stencil", required: ["forge.field1Binding"], category: "form")) { error in
            let message = (error as? ForgeError)?.message ?? ""
            XCTAssertTrue(message.contains("View.stencil:5:"), message)
            XCTAssertTrue(message.contains("else branch on line 4"), message)
            XCTAssertTrue(message.contains("'if isForm' on line 2 is true"), message)
            XCTAssertTrue(message.contains("branch that runs for form"), message)
        }
    }

    func testDuplicateInsertionNamesOriginalActiveLine() {
        let raw = "{{ forge.listItems }}\n{% if isList %}\n{{ forge.listItems }}\n{% endif %}"
        XCTAssertThrowsError(try TemplateRenderer.renderSource(raw, context: [
            "isList": true, "forge.listItems": "items",
        ], name: "View.stencil", required: ["forge.listItems"], category: "list")) { error in
            let message = (error as? ForgeError)?.message ?? ""
            XCTAssertTrue(message.contains("View.stencil:3:"), message)
            XCTAssertTrue(message.contains("already active on line 1"), message)
        }
    }
}
