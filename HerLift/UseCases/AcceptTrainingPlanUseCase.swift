import Foundation

@MainActor
struct AcceptTrainingPlanUseCase {
    private let repository: any TrainingPlanRepository
    private let now: () -> Date

    init(repository: any TrainingPlanRepository, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.now = now
    }

    /// EN: Accept only a saved draft. The repository saves activation and archiving together.
    /// VI: Chỉ chấp nhận draft đã lưu. Repository lưu việc kích hoạt và lưu trữ plan cũ cùng lúc.
    func execute(planID: UUID) throws(AcceptTrainingPlanError) -> TrainingPlan {
        do {
            guard let plan = try repository.load().first(where: { $0.id == planID }) else { throw AcceptTrainingPlanError.planNotFound }
            guard plan.statusRaw == "draft" else { throw AcceptTrainingPlanError.planAlreadyAccepted }
            return try repository.activateDraft(planID: planID, startedOn: Calendar.current.startOfDay(for: now()))
        } catch let error as AcceptTrainingPlanError {
            throw error
        } catch {
            throw .couldNotSavePlan
        }
    }
}

nonisolated enum AcceptTrainingPlanError: Error, LocalizedError {
    case planNotFound, planAlreadyAccepted, couldNotSavePlan

    var errorDescription: String? {
        switch self {
        case .planNotFound: "We couldn't find this plan."
        case .planAlreadyAccepted: "This plan is already active."
        case .couldNotSavePlan: "We couldn't activate your plan. Your plan is still here — tap Accept plan again."
        }
    }
}
