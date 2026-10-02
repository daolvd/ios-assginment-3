//
//  JSONExerciseRepository.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation

@MainActor
final class JSONExerciseRepository: ExerciseRepository {
    private(set) var exercises: [Exercise] = []
    private let fileURL: URL
    private let bundle: Bundle

    init(bundle: Bundle = .main) throws {
        self.bundle = bundle
        guard let fileURL = bundle.url(forResource: "exercises", withExtension: "json")
            ?? bundle.url(forResource: "exercises", withExtension: "json", subdirectory: "Resources")
        else { throw CocoaError(.fileNoSuchFile) }
        self.fileURL = fileURL
        exercises = try load()
    }

    @discardableResult
    func load() throws -> [Exercise] {
        let data = try Data(contentsOf: fileURL)
        exercises = try JSONDecoder().decode(Catalogue.self, from: data).exercises
        return exercises
    }

    func exercise(id: String) -> Exercise? {
        exercises.first { $0.id == id }
    }

    func videoURL(for exercise: Exercise) -> URL? {
        if let videoURL = exercise.videoURL, let url = URL(string: videoURL) { return url }
        guard let videoFile = exercise.videoFile else { return nil }
        let file = videoFile as NSString
        let name = file.deletingPathExtension
        let ext = file.pathExtension
        return bundle.url(forResource: name, withExtension: ext, subdirectory: "Videos")
            ?? bundle.url(forResource: name, withExtension: ext, subdirectory: "Resources/Videos")
            ?? bundle.url(forResource: name, withExtension: ext)
    }

    private nonisolated struct Catalogue: Decodable {
        let exercises: [Exercise]
    }
}
