//
//  GoalRepository.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation

@MainActor
protocol GoalRepository {
    var goals: [Goal] { get }
    func load() throws -> [Goal]
    func goal(id: String) -> Goal?
}
