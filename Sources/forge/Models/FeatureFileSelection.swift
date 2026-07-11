import Foundation

/// Controls which `FeatureFile` entries are included in a generation run.
struct FeatureFileSelection {
    /// The set of file roles selected for the current generation.
    let includedFiles: Set<FeatureFile>

    /// Returns a selection containing every file that `type` can produce.
    static func all(for type: FeatureType) -> FeatureFileSelection {
        FeatureFileSelection(including: Set(type.availableFiles))
    }

    /// Creates a selection from an explicit set of file roles.
    init(including includedFiles: Set<FeatureFile>) {
        self.includedFiles = includedFiles
    }

    /// Returns `true` when `file` is part of this selection.
    func contains(_ file: FeatureFile) -> Bool {
        includedFiles.contains(file)
    }
}

