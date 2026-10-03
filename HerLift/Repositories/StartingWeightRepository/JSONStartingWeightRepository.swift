import Foundation

/// Reads the starting weights bundled with the app.
@MainActor
final class JSONStartingWeightRepository: StartingWeightRepository {
    let table: StartingWeightTable

    init(bundle: Bundle = .main) throws {
        guard let fileURL = bundle.url(forResource: "starting_weights", withExtension: "json")
            ?? bundle.url(forResource: "starting_weights", withExtension: "json", subdirectory: "Resources")
        else { throw CocoaError(.fileNoSuchFile) }
        table = try JSONDecoder().decode(StartingWeightTable.self, from: Data(contentsOf: fileURL))
    }
}
