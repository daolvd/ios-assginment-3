import Foundation

/// Starting weights for a new plan, in kilograms, by exercise, experience, age band and BMI band. The numbers are
/// app defaults for the first sets: about 15 reps while she could still do a few more.
nonisolated struct StartingWeightTable: Decodable, Equatable, Sendable {
    struct AgeBand: Decodable, Equatable, Sendable {
        let id: String
        /// The band holds every age up to and including this one.
        let upToAge: Int
    }

    struct BMIBand: Decodable, Equatable, Sendable {
        let id: String
        /// The band holds every BMI below this one.
        let below: Double
    }

    struct HealthFactor: Decodable, Equatable, Sendable {
        let noConcern: Double
        /// For someone who reported a health concern and was cleared by a doctor.
        let concernClearedByDoctor: Double
    }

    /// Youngest band first.
    let ageBands: [AgeBand]
    /// Lowest band first; each row of weights follows this order.
    let bmiBands: [BMIBand]
    let healthFactor: HealthFactor
    /// The weight steps of each kind of equipment, such as 2.5 kg on a machine.
    let stepKg: [String: Double]
    let minimumKg: [String: Double]
    /// Exercise id → training level → age band id → one weight per BMI band.
    let weights: [Exercise.ID: [String: [String: [Double]]]]

    /// The BMI used when her height or weight is unknown, in the middle of the healthy range.
    static let typicalBMI = 22.0

    /// Her starting weight for the exercise, or nil for a bodyweight exercise or one the table does not list.
    /// The health factor only lowers the weight, which is then rounded down to the equipment's step and kept at
    /// or above its smallest weight.
    func kg(for exercise: Exercise, user: UserPlanningProfile) -> Double? {
        guard exercise.loadType != "bodyweight", let byLevel = weights[exercise.id],
              let byAge = byLevel[user.level.rawValue] ?? byLevel[TrainingLevel.beginner.rawValue],
              let ageBand = ageBand(for: user.age), let row = byAge[ageBand.id],
              let bmiIndex = bmiIndex(for: Self.bmi(of: user)), row.indices.contains(bmiIndex)
        else { return nil }

        let factor = user.reportsHealthConcern ? healthFactor.concernClearedByDoctor : healthFactor.noConcern
        let step = stepKg[exercise.equipment] ?? 1
        let minimum = minimumKg[exercise.equipment] ?? step
        let rounded = (row[bmiIndex] * factor / step + 1e-9).rounded(.down) * step
        return max(rounded, minimum)
    }

    /// The first band that holds her age; the youngest band when her age is unknown.
    private func ageBand(for age: Int?) -> AgeBand? {
        guard let age else { return ageBands.first }
        return ageBands.first { age <= $0.upToAge } ?? ageBands.last
    }

    private func bmiIndex(for bmi: Double) -> Int? {
        bmiBands.firstIndex { bmi < $0.below } ?? (bmiBands.isEmpty ? nil : bmiBands.count - 1)
    }

    /// Weight in kilograms over height in metres squared.
    static func bmi(of user: UserPlanningProfile) -> Double {
        guard let weight = user.weightKg, let height = user.heightCm, height > 0 else { return typicalBMI }
        let metres = height / 100
        return weight / (metres * metres)
    }
}
