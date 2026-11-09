import XCTest
@testable import forge

final class InputValidationTests: XCTestCase {
    func testInvalidTargetsAreRejectedFromCLIAndConfig() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        for target in ["", "../Escape", "/tmp/Escape", "A/B", "A\\B", "Feature Kit", "A\"B", "A\nB", "A\0B", "123Kit", "class", "Self", "_"] {
            XCTAssertThrowsError(try Command.parse(arguments: [
                "make", "Login", "-mvvm", "--path", directory.path, "--target", target
            ]), target)
            XCTAssertThrowsError(try ProjectConfig(from: ["paths": ["target": target]]), target)

            let generator = FeatureGenerator(
                projectPath: directory, shouldCreatePackage: true, packageTarget: target,
                shouldGenerateTests: true, shouldSkipDomain: false, type: .mvvm, category: nil
            )
            XCTAssertThrowsError(try generator.generate(
                feature: FeatureName(rawValue: "Login"), selection: .all(for: .mvvm)
            ), target)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
        }
    }

    func testValidTargetNames() throws {
        for target in ["FeatureKit", "Feature-Kit", "Feature_Kit2", "_Feature"] {
            XCTAssertNoThrow(try PackageTargetName.validate(target))
        }
    }

    func testYAMLDecodesQuotedValuesAndPreservesCommentsInsideQuotes() throws {
        let parsed = try YAMLParser.parse(#"""
        double: "App \"Quoted\" # Folder" # comment
        single: 'O''Brien # Folder' # comment
        escapes: "A\nB\tC\\D\/E"
        unicode: "\x41\u0042\U0001F600"
        plain: O'Brien # comment
        "quoted:key": "true"
        'it''s a key': '123'
        """#)
        XCTAssertEqual(parsed["double"] as? String, "App \"Quoted\" # Folder")
        XCTAssertEqual(parsed["single"] as? String, "O'Brien # Folder")
        XCTAssertEqual(parsed["escapes"] as? String, "A\nB\tC\\D/E")
        XCTAssertEqual(parsed["unicode"] as? String, "AB😀")
        XCTAssertEqual(parsed["plain"] as? String, "O'Brien")
        XCTAssertEqual(parsed["quoted:key"] as? String, "true")
        XCTAssertEqual(parsed["it's a key"] as? String, "123")
    }

    func testYAMLRejectsMalformedQuotedScalarsWithLineNumber() {
        for value in [#""unfinished"#, "'unfinished", #""bad\q""#, #""\uZZZZ""#,
                      #""\uD800""#, #""\U00110000""#, #""\x1""#, #""ok" trailing"#,
                      ##""ok"#comment"##] {
            XCTAssertThrowsError(try YAMLParser.parse("architecture: mvvm\nvalue: \(value)")) { error in
                guard case YAMLParser.ParserError.invalidSyntax(let line, _) = error else {
                    return XCTFail("Unexpected error: \(error)")
                }
                XCTAssertEqual(line, 2)
            }
        }
        XCTAssertThrowsError(try YAMLParser.parse("\"unfinished: value"))
        XCTAssertThrowsError(try YAMLParser.parse("'key' extra: value"))
    }
}
