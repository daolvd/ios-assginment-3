//
//  Goal.swift
//  HerLift
//
//  Created by Van Dao Le on 1/10/2026.
//

import Foundation

nonisolated struct Goal: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let requiresTargetWeight: Bool
}
