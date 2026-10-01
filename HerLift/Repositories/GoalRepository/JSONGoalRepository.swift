//
//  JSONGoalRepository.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation

@MainActor
final class JSONGoalRepository: GoalRepository {
    private(set) var goals: [Goal] = []
    private let fileURL: URL

    init(bundle: Bundle = .main) throws {
        guard let fileURL = bundle.url(forResource: "goals", withExtension: "json")
            ?? bundle.url(forResource: "goals", withExtension: "json", subdirectory: "Resources")
        else { throw CocoaError(.fileNoSuchFile) }
        self.fileURL = fileURL
        goals = try load()
    }

    @discardableResult
    func load() throws -> [Goal] {
        let data = try Data(contentsOf: fileURL)
        goals = try JSONDecoder().decode([Goal].self, from: data)
        return goals
    }

    func goal(id: String) -> Goal? {
        goals.first { $0.id == id }
    }
}
