import SwiftUI

@main
struct SmokeApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Forge")
        }
    }
}

// A host-owned dependency and controls that generated Swift can adopt.
struct SmokeFeatureContext {
    let origin: String

    static func submit(_ name: String, _ note: String) throws {
        guard name == "Edited name", note == "Edited note" else { throw URLError(.badServerResponse) }
    }

    static func retrying<Value>(_ value: Value) -> () async throws -> Value {
        var attempted = false
        return {
            guard attempted else {
                attempted = true
                throw NSError(domain: "SmokeHost", code: 1, userInfo: [NSLocalizedDescriptionKey: "Host offline"])
            }
            return value
        }
    }
}

struct SmokeTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text)
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier("team-display-name")
    }
}

struct SmokeListRow: View {
    let title: String

    var body: some View {
        Label(title, systemImage: "person")
    }
}
