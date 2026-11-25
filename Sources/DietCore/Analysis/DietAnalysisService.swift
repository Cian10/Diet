import Foundation

public enum DietAnalysisRange: Int, CaseIterable, Sendable, Identifiable {
    case sevenDays = 7
    case fourteenDays = 14
    case thirtyDays = 30

    public var id: Int { rawValue }
    public var days: Int { rawValue }
    public var displayName: String { "近 \(days) 天" }
}

public enum DietAnalysisError: LocalizedError, Equatable {
    case noConfirmedEntries

    public var errorDescription: String? {
        switch self {
        case .noConfirmedEntries:
            "所选范围内没有已确认的饮食记录，未发起分析。"
        }
    }
}

public struct DietAnalysisRequest: Sendable, Equatable {
    public let range: DietAnalysisRange
    public let windowStart: Date
    public let windowEnd: Date
    public let confirmedEntryCount: Int
    public let systemPrompt: String
    public let userPrompt: String

    public init(
        range: DietAnalysisRange,
        windowStart: Date,
        windowEnd: Date,
        confirmedEntryCount: Int,
        systemPrompt: String,
        userPrompt: String
    ) {
        self.range = range
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.confirmedEntryCount = confirmedEntryCount
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
    }
}

@MainActor
public final class DietAnalysisService {
    private let mealStore: MealEntryStoring
    private let targetStore: DailyTargetStoring
    private let llmProvider: LLMClientProviding
    private let calculator: NutritionCalculator
    private let calendar: Calendar

    public init(
        mealStore: MealEntryStoring,
        targetStore: DailyTargetStoring,
        llmProvider: LLMClientProviding,
        calculator: NutritionCalculator = NutritionCalculator(),
        calendar: Calendar = .current
    ) {
        self.mealStore = mealStore
        self.targetStore = targetStore
        self.llmProvider = llmProvider
        self.calculator = calculator
        self.calendar = calendar
    }

    public func prepare(
        range: DietAnalysisRange,
        now: Date = Date()
    ) throws -> DietAnalysisRequest {
        let todayStart = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -(range.days - 1), to: todayStart),
              let windowEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) else {
            throw LLMError.invalidResponse("无法计算饮食分析日期范围。")
        }

        let confirmedEntries = try mealStore.allEntries().filter {
            $0.isConfirmed && $0.consumedAt >= windowStart && $0.consumedAt < windowEnd
        }
        guard !confirmedEntries.isEmpty else { throw DietAnalysisError.noConfirmedEntries }

        let dayLines = try (0..<range.days).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: windowStart) else {
                throw LLMError.invalidResponse("无法生成饮食分析日期。")
            }
            return try dailyMaterial(for: date, entries: confirmedEntries)
        }

        let systemPrompt = """
        你是一名饮食记录分析助手。你只基于用户主动提供的已确认记录和本地营养汇总作答，不重新计算营养，也不把未知营养当作零。
        请使用中文输出约 600–900 字，采用短段落和少量要点。优先覆盖总体饮食模式、与每日目标对照、做得较好的地方、可执行的改进建议以及数据局限。
        必须区分记录事实、估算值和你的建议；不推断未记录的餐食，不为缺失日期臆造摄入，也不提供疾病诊断、治疗方案或替代医生的医疗建议。数据不足时应直接说明局限性。
        不要返回 JSON，不要使用 Markdown 表格。
        """

        let userPrompt = """
        分析范围：\(range.displayName)（\(dayLabel(windowStart)) 至 \(dayLabel(todayStart))，包含今天）
        已确认餐食数：\(confirmedEntries.count)

        以下内容由 App 根据本轮所选范围内的已确认记录生成。未记录日期不代表零摄入；标注为未知的项目未计入确定营养汇总。

        \(dayLines.joined(separator: "\n\n"))
        """

        return DietAnalysisRequest(
            range: range,
            windowStart: windowStart,
            windowEnd: windowEnd,
            confirmedEntryCount: confirmedEntries.count,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )
    }

    public func analyze(
        range: DietAnalysisRange,
        now: Date = Date()
    ) async throws -> String {
        let request = try prepare(range: range, now: now)
        let partial = try await llmProvider.client().generateText(TextGenerationRequest(
            systemPrompt: request.systemPrompt,
            userPrompt: request.userPrompt
        ))
        let report = partial.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !report.isEmpty else {
            throw LLMError.invalidResponse("模型返回了空文本。")
        }
        return report
    }

    private func dailyMaterial(for date: Date, entries: [MealEntry]) throws -> String {
        let dayEntries = entries.filter { calendar.isDate($0.consumedAt, inSameDayAs: date) }
        let target = try targetStore.target(on: date)
        let intake = calculator.dailyNutrition(entries: dayEntries, on: date, calendar: calendar)

        var lines = ["日期：\(dayLabel(date))"]
        if let target {
            lines.append(
                "已保存目标：热量 \(number(target.calories, digits: 0)) kcal；"
                + "蛋白质 \(number(target.proteinGrams)) g；"
                + "碳水 \(number(target.carbohydrateGrams)) g；"
                + "脂肪 \(number(target.fatGrams)) g。"
            )
        } else {
            lines.append("已保存目标：无；不做目标完成度推断。")
        }

        if dayEntries.isEmpty {
            lines.append("本地汇总：无已确认餐食记录，不代表零摄入。")
            return lines.joined(separator: "\n")
        }

        if intake.isComplete {
            lines.append("本地汇总（完整）：\(totalsText(intake))。")
        } else {
            let unknown = intake.unknownItemNames.joined(separator: "、")
            let unknownText = unknown.isEmpty ? "部分项目缺少可计算营养" : "无法计算：\(unknown)"
            lines.append("本地汇总（已知部分，不完整）：\(totalsText(intake))；\(unknownText)，未按零处理。")
        }

        for entry in dayEntries {
            lines.append(mealMaterial(for: entry))
        }
        return lines.joined(separator: "\n")
    }

    private func mealMaterial(for entry: MealEntry) -> String {
        var lines = ["- \(timeLabel(entry.consumedAt)) \(mealTypeName(entry.mealType))"]
        if let text = nonempty(entry.originalText) {
            lines.append("  用户记录：\(text)")
        }
        if let note = nonempty(entry.note) {
            lines.append("  备注：\(note)")
        }
        if entry.components.isEmpty {
            lines.append("  组成：未提供食物组成。")
        } else {
            for component in entry.components {
                lines.append("  组成：\(componentMaterial(component))")
            }
        }

        let missing = Array(Set(entry.estimationRecords.flatMap(\.missingInformation)))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted()
        if !missing.isEmpty {
            lines.append("  缺失信息：\(missing.joined(separator: "；"))")
        }
        return lines.joined(separator: "\n")
    }

    private func componentMaterial(_ component: EntryComponent) -> String {
        let base = "\(component.displayName) \(number(component.originalQuantity)) \(component.originalUnit)"
        guard let snapshot = component.nutritionSnapshot else {
            return "\(base)；营养数据未知，未按零处理"
        }
        var text = base
            + "；营养快照每 \(number(snapshot.basisQuantity)) \(basisUnitName(snapshot.basisUnit))："
            + "热量 \(number(snapshot.calories, digits: 0)) kcal，"
            + "蛋白质 \(number(snapshot.proteinGrams)) g，"
            + "碳水 \(number(snapshot.carbohydrateGrams)) g，"
            + "脂肪 \(number(snapshot.fatGrams)) g"
        if let fiber = snapshot.fiberGrams {
            text += "，纤维 \(number(fiber)) g"
        }
        return text + "。"
    }

    private func totalsText(_ totals: NutritionTotals) -> String {
        var values = [
            "热量 \(number(totals.calories, digits: 0)) kcal",
            "蛋白质 \(number(totals.proteinGrams)) g",
            "碳水 \(number(totals.carbohydrateGrams)) g",
            "脂肪 \(number(totals.fatGrams)) g"
        ]
        if let fiber = totals.fiberGrams {
            values.append("纤维 \(number(fiber)) g")
        }
        return values.joined(separator: "，")
    }

    private func dayLabel(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func timeLabel(_ date: Date) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private func number(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number
            .precision(.fractionLength(0...digits))
            .locale(Locale(identifier: "en_US_POSIX")))
    }

    private func mealTypeName(_ mealType: MealType) -> String {
        switch mealType {
        case .breakfast: "早餐"
        case .lunch: "午餐"
        case .dinner: "晚餐"
        case .snack: "加餐"
        case .other: "其他餐次"
        }
    }

    private func basisUnitName(_ unit: NutritionBasisUnit) -> String {
        switch unit {
        case .grams: "克"
        case .milliliters: "毫升"
        case .serving: "份"
        }
    }

    private func nonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
