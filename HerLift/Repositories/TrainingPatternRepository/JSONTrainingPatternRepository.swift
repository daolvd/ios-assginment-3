import Foundation

@MainActor
final class JSONTrainingPatternRepository: TrainingPatternRepository {
    private(set) var patterns: [TrainingPattern] = []
    private let fileURL: URL

    init(bundle: Bundle = .main) throws {
        guard let fileURL = bundle.url(forResource: "training_patterns", withExtension: "json")
            ?? bundle.url(forResource: "training_patterns", withExtension: "json", subdirectory: "Resources")
        else { throw CocoaError(.fileNoSuchFile) }
        self.fileURL = fileURL
        patterns = try load()
    }

    @discardableResult
    func load() throws -> [TrainingPattern] {
        let data = try Data(contentsOf: fileURL)
        patterns = try JSONDecoder().decode([TrainingPattern].self, from: data)
        return patterns
    }
}
