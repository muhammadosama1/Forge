import Foundation

enum StackWorkflow {
    static func initialize(at root: URL, requested: PresentationArchitecture?, adopt: Bool) throws {
        let fm = FileManager.default
        let candidates = ConfigLoader.configFilenames.map { root.appendingPathComponent($0) }
        let existing = candidates.filter { fm.fileExists(atPath: $0.path) }
        guard existing.count <= 1 else {
            throw ForgeError.invalidArguments("Both config filenames exist in '\(root.path)'. Keep one before running forge init.")
        }
        let configURL = existing.first ?? candidates[0]
        guard (try? fm.destinationOfSymbolicLink(atPath: configURL.path)) == nil else {
            throw ForgeError.invalidArguments("The configuration at '\(configURL.path)' is a symlink. Run setup in the project containing the actual file.")
        }
        let original = try existing.first.map { try String(contentsOf: $0, encoding: .utf8) }
        let config = try existing.first.flatMap { try ConfigLoader.load(explicitPath: $0)?.config }
        if let selected = config?.architecture, let requested, selected != requested {
            throw ForgeError.invalidArguments("The project already uses \(selected.rawValue.uppercased()). Run forge init without an architecture flag to keep it.")
        }
        if let stack = config?.stack {
            try StackTemplates(config: stack, directory: root.appendingPathComponent(".templates"))
                .checkReferences()
            print("Forge is already initialized at \(configURL.path). Run forge validate to check .templates/.")
            return
        }
        let legacy = root.appendingPathComponent(".forge/templates")
        if fm.fileExists(atPath: legacy.path), !adopt {
            let names = ((try? fm.contentsOfDirectory(atPath: legacy.path)) ?? []).sorted().joined(separator: ", ")
            throw ForgeError.invalidArguments("Found legacy overrides at '\(legacy.path)' (\(names)). Run forge init --adopt to activate .templates/. The legacy files will stay on disk for reference.")
        }

        let architecture: PresentationArchitecture
        if let selected = requested ?? config?.architecture {
            architecture = selected
        } else if Terminal.isInteractive {
            architecture = try Terminal.promptSelection(title: "Which architecture does this project use?",
                                                        options: PresentationArchitecture.allCases) { option in
                switch option {
                case .mvvm: return "MVVM · ViewModel with connected forms and lists"
                case .mvi: return "MVI · State, intents, and a store with connected forms and lists"
                case .viper: return "VIPER · Presenter, interactor, and router"
                case .vip: return "VIP · Clean Swift interactor, presenter, and worker"
                case .mvp: return "MVP · Presenter and model"
                }
            }
        } else {
            throw ForgeError.invalidArguments("Set architecture in .forge.yml or pass an architecture flag such as -mvvm.")
        }
        let templates = StackTemplates.starter(for: architecture)
        var text = original ?? ProjectConfig.starterTemplate.replacingOccurrences(of: "architecture: mvvm",
                                                                                   with: "architecture: \(architecture.rawValue)")
        if original != nil, config?.architecture == nil {
            text += "\narchitecture: \(architecture.rawValue)\n"
        }
        text += "\n\nstack:\n  version: 1\n  files:\n"
        for template in templates.keys.sorted() {
            let role = String(template.dropLast(".swift.stencil".count))
            text += "    \(role):\n      template: \(template)\n"
        }
        text += """

        # Add team-specific files under stack.files, for example:
        #     coordinator:
        #       template: coordinator.swift.stencil
        #       output: "Navigation/{{ name }}Coordinator.swift"
        #       target: source

        """
        _ = try ProjectConfig(from: YAMLParser.parse(text))

        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let lock = try GenerationLock.acquire(for: root)
        defer { GenerationLock.release(lock) }
        let current = candidates.filter { fm.fileExists(atPath: $0.path) }
        guard current == existing, try current.first.map({ try String(contentsOf: $0, encoding: .utf8) }) == original else {
            throw ForgeError.invalidArguments("The configuration changed during setup. Review it and run forge init again.")
        }
        let directory = root.appendingPathComponent(".templates", isDirectory: true)
        guard resolvedPath(directory) == resolvedPath(root) + "/.templates",
              (try? fm.destinationOfSymbolicLink(atPath: directory.path)) == nil else {
            throw ForgeError.invalidArguments("Move the .templates symlink out of the project before running forge init.")
        }
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        var missing: [(String, URL)] = []
        for (name, content) in templates.sorted(by: { $0.key < $1.key }) {
            let url = directory.appendingPathComponent(name)
            if fm.fileExists(atPath: url.path) {
                guard (try? fm.destinationOfSymbolicLink(atPath: url.path)) == nil,
                      (try? String(contentsOf: url, encoding: .utf8)) == content else {
                    throw ForgeError.invalidArguments("Setup found an existing template at '\(url.path)'. Move it aside, run forge init, then apply your changes to the new template.")
                }
            } else {
                missing.append((content, url))
            }
        }

        var published: [PublishedFile] = []
        defer { published.forEach { $0.removeStagingFile() } }
        do {
            for (content, url) in missing {
                published.append(try PublishedFile.write(content, to: url))
            }
            if original == nil {
                published.append(try PublishedFile.write(text, to: configURL))
            } else {
                guard try String(contentsOf: configURL, encoding: .utf8) == original else {
                    throw ForgeError.invalidArguments("The configuration changed during setup. Review it and run forge init again.")
                }
                try text.write(to: configURL, atomically: true, encoding: .utf8)
            }
        } catch {
            for file in published.reversed() where !file.rollBack() {
                fputs("Review '\(file.url.path)' after the interrupted setup.\n", stderr)
            }
            throw error
        }
        print("""
        Initialized Forge with \(architecture.rawValue.uppercased()) at \(root.path).
          \(configURL.lastPathComponent)    Project configuration
          .templates/   Editable architecture templates

        Generate your first feature with forge make Profile -form.
        When you're ready, describe your team's stack under stack in \(configURL.lastPathComponent)
        and customize the files in .templates/. Run forge validate after editing.
        """)
    }

    static func validate(arguments: [String]) throws {
        var root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var configURL: URL?
        var index = 1
        while index < arguments.count {
            let flag = arguments[index]
            guard ["--path", "--config"].contains(flag), index + 1 < arguments.count,
                  !arguments[index + 1].hasPrefix("-") else {
                throw ForgeError.invalidArguments("Use forge validate [--path <project>] [--config <file>].")
            }
            let url = URL(fileURLWithPath: arguments[index + 1])
            if flag == "--path" { root = url } else { configURL = url }
            index += 2
        }
        guard let loaded = try ConfigLoader.load(explicitPath: configURL, startingDirectory: root),
              let architecture = loaded.config.architecture, let stack = loaded.config.stack else {
            throw ForgeError.invalidArguments("No editable stack is active. Run forge init in your project first.")
        }
        let config = loaded.config
        let templates = StackTemplates(config: stack,
            directory: loaded.fileURL.deletingLastPathComponent().appendingPathComponent(".templates"))
        try templates.checkReferences()
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("forge-validation-\(UUID())")
        let feature = try FeatureName(rawValue: "ForgeSample", naming: config.naming)
        let type = FeatureType.resolve(presentation: architecture, clean: config.flags.clean)
        var failures: [String] = []
        for category in StackConfig.categories {
            let name = category?.rawValue ?? "default"
            guard stack.categories.contains(name) else { continue }
            do {
                let generator = FeatureGenerator(projectPath: scratch, shouldCreatePackage: config.paths.package,
                    packageTarget: config.paths.target, filesOnly: true, dryRun: true,
                    shouldGenerateTests: config.flags.tests, shouldSkipDomain: config.flags.noDomain,
                    type: type, category: category, binding: config.binding, testing: config.testing,
                    di: config.di, stack: templates)
                _ = try generator.generate(feature: feature, selection: .all(for: type), validationOnly: true)
                print("Passed \(name) template rendering.")
            } catch {
                let details = (error as? ForgeError)?.message ?? error.localizedDescription
                failures.append("\(name): \(details.replacingOccurrences(of: "\n", with: "\n  "))")
            }
        }
        if !failures.isEmpty {
            throw ForgeError.invalidArguments("Stack validation failed for \(loaded.fileURL.path) [\(architecture.rawValue)].\n" + failures.joined(separator: "\n"))
        }
        print("Template checks passed for \(loaded.fileURL.path). Build generated Swift in your host project to check compilation.")
    }
}
