import Foundation
import Observation

@MainActor
@Observable
final class ExerciseGuideViewModel {
    var searchText = ""
    @ObservationIgnored private let browse: BrowseExerciseGuideUseCase

    init(browse: BrowseExerciseGuideUseCase) {
        self.browse = browse
    }

    var sections: [ExerciseGuideSection] { browse.sections(matching: searchText) }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func exercise(id: Exercise.ID) -> Result<Exercise, ExerciseGuideError> {
        Result { () throws(ExerciseGuideError) -> Exercise in try browse.exercise(id: id) }
    }

    func videoURL(for exercise: Exercise) -> URL? { browse.videoURL(for: exercise) }
}
