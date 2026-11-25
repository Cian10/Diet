import Foundation

public struct DailyTrend: Identifiable {
    public var id: Date { date }
    public var date: Date
    public var intake: NutritionTotals
    public var target: DailyTarget?
    public var phaseType: PhaseType?
    public var hasConfirmedEntries: Bool

    public init(
        date: Date,
        intake: NutritionTotals,
        target: DailyTarget?,
        phaseType: PhaseType?,
        hasConfirmedEntries: Bool
    ) {
        self.date = date
        self.intake = intake
        self.target = target
        self.phaseType = phaseType
        self.hasConfirmedEntries = hasConfirmedEntries
    }

    public var isEligibleForTargetCompletion: Bool {
        hasConfirmedEntries && intake.isComplete && target != nil
    }

    public var meetsCalorieTarget: Bool {
        guard isEligibleForTargetCompletion, let target else { return false }
        let tolerance = max(target.calories * 0.1, 1)
        return abs(intake.calories - target.calories) <= tolerance
    }
}

public struct TrendsOverview {
    public var recordedDays: Int
    public var averageCalories: Double?
    public var targetCompletionRate: Double?
    public var weightChangeKilograms: Double?
    public var weightSpanDays: Int
    public var hasSufficientData: Bool

    public init(
        recordedDays: Int,
        averageCalories: Double?,
        targetCompletionRate: Double?,
        weightChangeKilograms: Double?,
        weightSpanDays: Int,
        hasSufficientData: Bool
    ) {
        self.recordedDays = recordedDays
        self.averageCalories = averageCalories
        self.targetCompletionRate = targetCompletionRate
        self.weightChangeKilograms = weightChangeKilograms
        self.weightSpanDays = weightSpanDays
        self.hasSufficientData = hasSufficientData
    }
}

@MainActor
public final class TrendsService {
    private let mealStore: MealEntryStoring
    private let targetStore: DailyTargetStoring
    private let phaseStore: PhasePlanStoring
    private let profileStore: ProfileStoring
    private let calculator: NutritionCalculator
    private let calendar: Calendar

    public init(
        mealStore: MealEntryStoring,
        targetStore: DailyTargetStoring,
        phaseStore: PhasePlanStoring,
        profileStore: ProfileStoring,
        calculator: NutritionCalculator = NutritionCalculator(),
        calendar: Calendar = .current
    ) {
        self.mealStore = mealStore
        self.targetStore = targetStore
        self.phaseStore = phaseStore
        self.profileStore = profileStore
        self.calculator = calculator
        self.calendar = calendar
    }

    public func dailyTrends(endingOn endDate: Date = Date(), days: Int = 7) throws -> [DailyTrend] {
        precondition(days > 0)
        let entries = try mealStore.allEntries()
        let plans = try phaseStore.allPlans()
        let end = calendar.startOfDay(for: endDate)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) else { return [] }
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let dayEntries = entries.filter { calendar.isDate($0.consumedAt, inSameDayAs: date) }
            return DailyTrend(
                date: date,
                intake: calculator.dailyNutrition(entries: dayEntries, on: date, calendar: calendar),
                target: try? targetStore.target(on: date),
                phaseType: plans.first(where: { $0.contains(date) })?.phaseType,
                hasConfirmedEntries: dayEntries.contains(where: { $0.isConfirmed })
            )
        }
    }

    public func overview(days: [DailyTrend], weights: [WeightRecord]) -> TrendsOverview {
        let recorded = days.filter(\.hasConfirmedEntries)
        let eligible = days.filter(\.isEligibleForTargetCompletion)
        let average = recorded.isEmpty ? nil : recorded.reduce(0.0) { $0 + $1.intake.calories } / Double(recorded.count)
        let completion = eligible.isEmpty ? nil : Double(eligible.filter(\.meetsCalorieTarget).count) / Double(eligible.count)
        let sortedWeights = weights.sorted { $0.date < $1.date }
        let first = sortedWeights.count >= 2 ? sortedWeights.first : nil
        let last = sortedWeights.count >= 2 ? sortedWeights.last : nil
        let span = first.flatMap { start in last.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: start.date), to: calendar.startOfDay(for: $0.date)).day ?? 0 } } ?? 0
        return TrendsOverview(
            recordedDays: recorded.count,
            averageCalories: average,
            targetCompletionRate: completion,
            weightChangeKilograms: first.flatMap { start in last.map { $0.weightKilograms - start.weightKilograms } },
            weightSpanDays: span,
            hasSufficientData: recorded.count >= 3
        )
    }

    public func weeklyReview(endingOn endDate: Date = Date()) throws -> (days: [DailyTrend], overview: TrendsOverview) {
        let days = try dailyTrends(endingOn: endDate)
        guard let end = days.last?.date, let start = days.first?.date else {
            return (days, overview(days: days, weights: []))
        }
        let weights = try profileStore.allWeightRecords().filter {
            calendar.startOfDay(for: $0.date) >= start && calendar.startOfDay(for: $0.date) <= end
        }
        return (days, overview(days: days, weights: weights))
    }
}
