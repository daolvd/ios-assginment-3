import Foundation

@MainActor
extension PlanRuleEngine {
    private static let maximumScheduleAttempts = 20
    private static let desiredMajorMuscleSets = 4
    private static let desiredMajorMuscleExposures = 2

    // EN: These numbers are preference points, not sets or seconds. They help compare exercises.
    // VI: Các số này là điểm ưu tiên, không phải sets hay giây. Chúng giúp so sánh các bài.
    // EN: An exercise must pass canAdd first; a high score cannot override a failed check.
    // VI: Bài phải qua canAdd trước; điểm cao không giúp bài vượt qua điều kiện bị vi phạm.
    private enum Score {
        static let preferredMuscle = 20_000
        static let missingMovement = 10_000
        static let setDeficit = 1_000
        static let dayBalance = 100
        static let sessionShortfall = 1_000
        static let candidateOverlap = 20
        static let familiarExercise = 10
        static let majorCoverage = 100
        static let exposureCoverage = 20
        static let layoutOverlap = 10
        static let guidedEquipment = 30
        static let seated = 5
        static let compound = 10
        static let coreLast = 10
    }

    /// EN: Try up to 20 ways to fill the week, then keep the valid schedule with the lowest penalty.
    /// VI: Thử tối đa 20 cách thêm bài vào tuần, rồi giữ lịch hợp lệ có điểm phạt thấp nhất.
    /// EN: Each attempt picks one exercise at a time. It does not test every possible combination.
    /// VI: Mỗi lần thử chọn từng bài một. Thuật toán không thử tất cả tổ hợp bài có thể có.
    func selectSchedule(context: Context) throws(CreatePersonalisedPlanError) -> [DaySelection] {
        let selected = context.request.trainingWeekdays.sorted()
        // EN: For 2–6 selected days, use those exact days. For 7 days, try each possible rest day.
        // VI: Chọn 2–6 ngày thì dùng đúng các ngày đó. Chọn 7 ngày thì thử lần lượt từng ngày nghỉ.
        // EN: Example: first try resting Sunday, then Saturday, continuing back to Monday.
        // VI: Ví dụ: thử nghỉ Chủ nhật trước, rồi thứ Bảy, tiếp tục lùi đến thứ Hai.
        let schedules = selected.count == 7 ? (1...7).reversed().map { off in selected.filter { $0 != off } } : [selected]
        var best: (days: [DaySelection], score: Int)?
        for attempt in 0..<Self.maximumScheduleAttempts {
            // EN: % picks a day pattern; division picks how to fill that pattern with exercises.
            // VI: % chọn bộ ngày tập; phép chia chọn cách thêm bài vào bộ ngày đó.
            // EN: With 7 rest-day options, attempts 0–6 use phase 0; attempt 7 starts phase 1.
            // VI: Khi có 7 cách chọn ngày nghỉ, lần thử 0–6 dùng phase 0; lần thử 7 bắt đầu phase 1.
            // EN: phase changes the starting muscle and the direction in which days are filled.
            // VI: phase đổi nhóm cơ bắt đầu và đổi việc thêm bài từ ngày đầu hay từ ngày cuối.
            let weekdays = schedules[attempt % schedules.count]
            guard let days = compose(weekdays, phase: attempt / schedules.count, context: context),
                  requiredMovements.isSubset(of: Set(days.flatMap(\.entries).map(\.movement))) else { continue }
            // EN: Reject a week missing knee, hip, push or pull movements, then compare the remaining weeks.
            // VI: Loại tuần thiếu bài dùng gối, dùng hông, đẩy hoặc kéo, rồi so sánh các tuần còn lại.
            let score = layoutScore(days, context: context)
            // EN: On equal penalties, prefer resting Sunday. Otherwise keep the earlier result.
            // VI: Nếu điểm phạt bằng nhau, ưu tiên nghỉ Chủ nhật. Trường hợp khác giữ kết quả tìm thấy trước.
            if best == nil || score < best!.score || (score == best!.score && !weekdays.contains(7) && best!.days.contains { $0.weekday == 7 }) {
                best = (days, score)
            }
        }
        guard let best else { throw .invalidTrainingPlan }
        return best.days
    }

    /// EN: First put one exercise into every day. Then add one extra exercise at a time.
    /// VI: Trước tiên thêm một bài vào mỗi ngày. Sau đó thêm từng bài bổ sung.
    func compose(_ weekdays: [Int], phase: Int, context: Context) -> [DaySelection]? {
        var days = weekdays.map { DaySelection(weekday: $0) }
        let order = phase.isMultiple(of: 2) ? Array(days.indices) : Array(days.indices.reversed())
        for (position, index) in order.enumerated() {
            // EN: Change the preferred muscle for each day. For phase 0, start with quads, chest, then hamstrings.
            // VI: Đổi nhóm cơ ưu tiên theo từng ngày. Với phase 0, bắt đầu bằng đùi trước, ngực, rồi đùi sau.
            // EN: This is a preference; another muscle may be chosen if the preferred exercise is not allowed.
            // VI: Đây là ưu tiên; có thể chọn cơ khác nếu bài của cơ được ưu tiên không được phép thêm.
            let preferred = majorMuscles[(position + phase) % majorMuscles.count]
            let candidates = context.entries.filter { canAdd($0, to: index, days: days, context: context) }
            guard let entry = candidates.max(by: {
                let a = candidateScore($0, at: index, days: days, context: context, preferred: preferred)
                let b = candidateScore($1, at: index, days: days, context: context, preferred: preferred)
                // EN: Pick the highest exercise score. On a tie, pick the alphabetically smaller exercise ID.
                // VI: Chọn bài có điểm cao nhất. Nếu bằng điểm, chọn bài có ID đứng trước theo thứ tự chữ.
                return a != b ? a < b : $0.exercise.id > $1.exercise.id
            }) else { return nil }
            days[index].entries.append(entry)
        }
        // EN: Fill each session towards its own time budget. Stop only when no legal addition fits.
        // VI: Thêm bài để từng buổi gần thời gian đã chọn. Chỉ dừng khi không còn bài hợp lệ nào vừa.
        // EN: Never split sessionMinutes between training days or stop at a fixed weekly set target.
        // VI: Không chia sessionMinutes cho số ngày tập hoặc dừng theo mục tiêu sets tuần cố định.
        while true {
            var best: (day: Int, entry: Entry, score: Int)?
            for index in days.indices {
                // EN: Compare every allowed (day, exercise) pair, add the highest-scoring pair, then compare again.
                // VI: So sánh mọi cặp (ngày, bài) được phép, thêm cặp có điểm cao nhất, rồi so sánh lại.
                for entry in context.entries where canAdd(entry, to: index, days: days, context: context) {
                    let score = candidateScore(entry, at: index, days: days, context: context, preferred: nil)
                    if best == nil || score > best!.score { best = (index, entry, score) }
                }
            }
            guard let best else { break }
            days[best.day].entries.append(best.entry)
        }
        return days
    }

    /// EN: Would this exercise duplicate a daily exercise, exceed set limits, or make the session too long?
    /// VI: Thêm bài này có bị trùng bài trong ngày, vượt sets hoặc làm buổi tập quá dài không?
    /// EN: Also reject the same primary muscle on consecutive days. Example: quads on Monday blocks quads on Tuesday.
    /// VI: Cũng loại cơ chính trùng ở hai ngày liền nhau. Ví dụ: tập đùi trước thứ Hai thì không thêm đùi trước thứ Ba.
    /// EN: Sunday and Monday count as consecutive days too.
    /// VI: Chủ nhật và thứ Hai cũng được tính là hai ngày liền nhau.
    func canAdd(_ entry: Entry, to index: Int, days: [DaySelection], context: Context) -> Bool {
        let all = days.flatMap(\.entries), day = days[index]
        guard !day.entries.contains(where: { $0.exercise.id == entry.exercise.id }),
              (all.count + 1) * PlanRuleMath.initialSets <= context.volume.maximumSets,
              !entry.major || (all.filter { $0.muscle == entry.muscle }.count + 1) * PlanRuleMath.initialSets <= context.volume.maximumMajorMuscleSets else { return false }
        guard !days.filter({ PlanRuleMath.adjacent($0.weekday, day.weekday) }).flatMap(\.entries).contains(where: { $0.muscle == entry.muscle }) else { return false }
        let seconds = PlanRuleMath.sessionSeconds((day.entries + [entry]).map {
            (sets: PlanRuleMath.initialSets, rest: PlanRuleMath.rest($0.exercise, strategy: context.strategy))
        })
        return seconds <= context.request.sessionMinutes * 60
    }

    /// EN: Compare two allowed exercises: the higher score wins.
    /// VI: So sánh hai bài được phép thêm: bài có điểm cao hơn được chọn.
    /// EN: Add points for the preferred muscle (+20000) and a movement still missing from the week (+10000).
    /// VI: Cộng điểm cho cơ đang ưu tiên (+20000) và kiểu chuyển động tuần còn thiếu (+10000).
    /// EN: Add points for missing sets; subtract points when a session is already longer or shares muscles with adjacent days.
    /// VI: Cộng điểm khi cơ còn thiếu sets; trừ điểm khi buổi đã dài hơn hoặc dùng chung cơ với ngày liền kề.
    /// EN: Include exercise-order points and +10 for repeating a familiar exercise when the goal is gym confidence.
    /// VI: Cộng điểm thứ tự bài và +10 cho bài đã có trong tuần khi mục tiêu là tự tin tập gym.
    func candidateScore(_ entry: Entry, at index: Int, days: [DaySelection], context: Context, preferred: MuscleGroup?) -> Int {
        let all = days.flatMap(\.entries)
        let sets = all.filter { $0.muscle == entry.muscle }.count * PlanRuleMath.initialSets
        let missing = requiredMovements.contains(entry.movement) && !all.contains { $0.movement == entry.movement }
        let deficit = entry.major ? max(0, Self.desiredMajorMuscleSets - sets) : (sets == 0 ? 1 : 0)
        // EN: Example: chest has 2 sets so far. The preferred total is 4, so deficit = 2 and the bonus is 2000.
        // VI: Ví dụ: ngực đang có 2 sets. Mục tiêu ưu tiên là 4, nên deficit = 2 và được cộng 2000 điểm.
        // EN: Arms, calves and core get a first-appearance bonus of 1000, rather than a 4-set target.
        // VI: Tay, bắp chân và bụng được cộng 1000 điểm khi chưa xuất hiện, thay vì nhắm tới 4 sets.
        let neighbours = days.filter { PlanRuleMath.adjacent($0.weekday, days[index].weekday) }.flatMap(\.entries)
        let muscles = entry.secondary.union([entry.muscle])
        let overlap = neighbours.reduce(0) { $0 + muscles.intersection($1.secondary.union([$1.muscle])).count }
        return (preferred == entry.muscle ? Score.preferredMuscle : 0) + (missing ? Score.missingMovement : 0) + deficit * Score.setDeficit
            - sessionSeconds(days[index], context: context) / 60 * Score.dayBalance - overlap * Score.candidateOverlap + orderPriority(entry, context: context)
            + (context.goal == .increaseGymConfidence && all.contains { $0.exercise.id == entry.exercise.id } ? Score.familiarExercise : 0)
    }

    /// EN: Compare complete weeks: the lower penalty wins. Here we subtract nothing; we add penalties.
    /// VI: So sánh các tuần đã xếp xong: điểm phạt thấp hơn thắng. Ở đây chỉ cộng các khoản phạt.
    /// EN: For each major muscle: add 100 per set below 4, and 20 per training day below 2.
    /// VI: Với mỗi cơ chính: cộng 100 cho mỗi set thiếu so với 4, và 20 cho mỗi ngày thiếu so với 2.
    /// EN: Example: chest has 2 sets on 1 day → 2 × 100 + 1 × 20 = 220 penalty points.
    /// VI: Ví dụ: ngực có 2 sets trong 1 ngày → 2 × 100 + 1 × 20 = 220 điểm phạt.
    /// EN: Prefer layouts closer to the requested time, then compare muscle coverage and consecutive-day overlap.
    /// VI: Ưu tiên lịch gần thời gian đã chọn, rồi so sánh độ phủ nhóm cơ và cơ trùng ở ngày liền nhau.
    /// EN: Secondary muscles affect the shared-muscle penalty, but do not receive additional direct sets.
    /// VI: Cơ phụ ảnh hưởng khoản phạt cơ trùng, nhưng không được cộng thêm sets trực tiếp.
    func layoutScore(_ days: [DaySelection], context: Context) -> Int {
        let all = days.flatMap(\.entries)
        let coverage = majorMuscles.reduce(0) { score, muscle in
            score + max(0, Self.desiredMajorMuscleSets - all.filter { $0.muscle == muscle }.count * PlanRuleMath.initialSets) * Score.majorCoverage
                + max(0, Self.desiredMajorMuscleExposures - days.filter { $0.entries.contains { $0.muscle == muscle } }.count) * Score.exposureCoverage
        }
        let overlap = days.reduce(0) { score, day in
            let muscles = Set(day.entries.flatMap { $0.secondary.union([$0.muscle]) })
            let next = days.first { $0.weekday == day.weekday % 7 + 1 }
            return score + muscles.intersection(Set(next?.entries.flatMap { $0.secondary.union([$0.muscle]) } ?? [])).count
        }
        let shortfall = days.reduce(0) { $0 + max(0, context.request.sessionMinutes * 60 - sessionSeconds($1, context: context)) }
        return shortfall * Score.sessionShortfall + coverage + overlap * Score.layoutOverlap
    }

    private func sessionSeconds(_ day: DaySelection, context: Context) -> Int {
        PlanRuleMath.sessionSeconds(day.entries.map {
            (sets: PlanRuleMath.initialSets, rest: PlanRuleMath.rest($0.exercise, strategy: context.strategy))
        })
    }

    /// EN: Decide which exercise to do earlier: machine/cable +30 when preferred, seated +5 for low impact.
    /// VI: Chọn bài làm trước: máy/cable +30 khi được ưu tiên, bài ngồi +5 khi cần giảm tác động.
    /// EN: An exercise marked compound adds 10; a core movement subtracts 10 so it tends to come later.
    /// VI: Bài được đánh dấu compound (phối hợp nhiều nhóm cơ) cộng 10; bài bụng trừ 10 để thường làm sau.
    /// EN: These points also contribute to candidateScore when choosing an exercise.
    /// VI: Các điểm này cũng được cộng vào candidateScore khi chọn bài.
    func orderPriority(_ entry: Entry, context: Context) -> Int {
        let machines = context.goal == .increaseGymConfidence || context.strategy.prefersMachineFirst
        return (machines && entry.machine ? Score.guidedEquipment : 0) + (context.strategy.isLowImpact && ExercisePosition(rawValue: entry.exercise.position) == .seated ? Score.seated : 0)
            + (entry.compound ? Score.compound : 0) - (entry.movement == .core ? Score.coreLast : 0)
    }
}
