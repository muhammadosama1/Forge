import CryptoKit
import Darwin
import Foundation

enum GenerationLock {
    static func acquire(for resource: URL) throws -> Int32 {
        let directory = try FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("forge/locks", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let (resolved, ancestor) = resolvePath(resource)
        var path = resolved
        if (try? ancestor.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey])
            .volumeSupportsCaseSensitiveNames) == false {
            path = path.precomposedStringWithCanonicalMapping.folding(options: .caseInsensitive, locale: nil)
        }
        let key = SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
        let lockFile = directory.appendingPathComponent(key)

        // Keep the lock file so every waiter opens the same inode.
        let descriptor = open(lockFile.path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw lockError(for: resource, code: errno) }
        while flock(descriptor, LOCK_EX) != 0 {
            let code = errno
            if code == EINTR { continue }
            close(descriptor)
            throw lockError(for: resource, code: code)
        }
        return descriptor
    }

    static func release(_ descriptor: Int32) {
        close(descriptor)
    }

    private static func lockError(for resource: URL, code: Int32) -> ForgeError {
        .invalidArguments("Could not lock generation for '\(resource.path)': \(String(cString: strerror(code)))")
    }
}

// Generated paths may be new. Resolve symlinks from the nearest existing ancestor.
func resolvedPath(_ url: URL) -> String {
    resolvePath(url).path
}

private func resolvePath(_ url: URL) -> (path: String, ancestor: URL) {
    var ancestor = url.standardizedFileURL
    var missing: [String] = []
    while !FileManager.default.fileExists(atPath: ancestor.path),
          !ancestor.path.isEmpty, ancestor.path != "/" {
        missing.append(ancestor.lastPathComponent)
        ancestor.deleteLastPathComponent()
    }
    // realpath gives the same spelling for system aliases such as /var and /private/var.
    if let canonical = realpath(ancestor.path, nil) {
        defer { free(canonical) }
        ancestor = URL(fileURLWithPath: String(cString: canonical))
    }
    let path = missing.reversed().reduce(ancestor) { url, component in
        url.appendingPathComponent(component)
    }.path
    return (path, ancestor)
}
