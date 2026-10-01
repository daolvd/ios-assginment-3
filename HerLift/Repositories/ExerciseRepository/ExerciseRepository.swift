//
//  ExerciseRepository.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation

@MainActor
protocol ExerciseRepository {
    var exercises: [Exercise] { get }
    func load() throws -> [Exercise]
    func exercise(id: String) -> Exercise?
}
