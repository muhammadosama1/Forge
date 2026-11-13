import Darwin
import Foundation

struct PublishedFile {
    let url: URL
    private let stagingURL: URL
    private let identity: stat

    static func write(_ content: String, to url: URL) throws -> PublishedFile {
        let stagingURL = url.deletingLastPathComponent()
            .appendingPathComponent(".forge-\(UUID().uuidString).tmp")
        var published = false
        defer {
            if !published { try? FileManager.default.removeItem(at: stagingURL) }
        }
        try Data(content.utf8).write(to: stagingURL, options: .atomic)
        var identity = stat()
        guard lstat(stagingURL.path, &identity) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        guard link(stagingURL.path, url.path) == 0 else {
            let code = errno
            if code == EEXIST { throw ForgeError.fileAlreadyExists(url.path) }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(code))
        }
        published = true
        return PublishedFile(url: url, stagingURL: stagingURL, identity: identity)
    }

    // Keep the staging link until the transaction ends so the inode cannot be reused.
    func removeStagingFile() {
        try? FileManager.default.removeItem(at: stagingURL)
    }

    /// Returns false if a path remains and needs review.
    func rollBack() -> Bool {
        var current = stat()
        guard lstat(url.path, &current) == 0 else { return errno == ENOENT }
        guard current.st_dev == identity.st_dev, current.st_ino == identity.st_ino else {
            return false
        }
        return unlink(url.path) == 0 || errno == ENOENT
    }
}
