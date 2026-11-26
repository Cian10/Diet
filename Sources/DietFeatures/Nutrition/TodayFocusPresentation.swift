import Foundation
import DietCore

/// Pure presentation priority for the focus state on the Today page.
/// It never decides whether a target or meal can be saved.
struct TodayFocusPresentation: Equatable {
    enum Kind: Equatable {
        case reviewMeal
        case startLogging
        case recordMeal(MealType)
        case completed
        case maintain
    }

    let kind: Kind

    init(
        hasTarget: Bool,
        hasPendingOrFailedMeal: Bool,
        recordedMealTypes: Set<MealType>,
        hour: Int,
        isGoalMet: Bool
    ) {
        if hasPendingOrFailedMeal {
            kind = .reviewMeal
        } else if !hasTarget {
            kind = .startLogging
        } else if (5..<11).contains(hour), !recordedMealTypes.contains(.breakfast) {
            kind = .recordMeal(.breakfast)
        } else if (11..<16).contains(hour), !recordedMealTypes.contains(.lunch) {
            kind = .recordMeal(.lunch)
        } else if (16..<23).contains(hour), !recordedMealTypes.contains(.dinner) {
            kind = .recordMeal(.dinner)
        } else if isGoalMet {
            kind = .completed
        } else {
            kind = .maintain
        }
    }

    static func suggestedMealType(for hour: Int, recorded: Set<MealType>) -> MealType {
        switch hour {
        case 5..<11:
            return recorded.contains(.breakfast) ? .snack : .breakfast
        case 11..<16:
            return recorded.contains(.lunch) ? .snack : .lunch
        case 16..<23:
            return recorded.contains(.dinner) ? .snack : .dinner
        default:
            return .snack
        }
    }

    var title: String {
        switch kind {
        case .reviewMeal: "完成待确认餐食"
        case .startLogging: "记录今天的第一餐"
        case .recordMeal(let mealType): "记录\(mealType.displayName)"
        case .completed: "今天已完成，保持轻松"
        case .maintain: "保持当前节奏"
        }
    }

    var message: String {
        switch kind {
        case .reviewMeal:
            "有一餐仍待确认或分析未完成。继续核对内容，已填写的信息会保留。"
        case .startLogging:
            "从文字或图片开始，确认后的餐食才会计入今日摄入。"
        case .recordMeal(let mealType):
            "今天还没有\(mealType.displayName)记录。用餐后花一分钟记下，就能看到更完整的今日概况。"
        case .completed:
            "今日热量处于目标范围内。无需追求绝对精确，按自己的节奏继续即可。"
        case .maintain:
            "根据已确认记录安排下一餐即可；营养不完整时，当前合计仅作参考。"
        }
    }

    var actionTitle: String {
        switch kind {
        case .reviewMeal: "继续确认"
        case .startLogging, .recordMeal: "记一餐"
        case .completed, .maintain: "查看今日记录"
        }
    }

    var needsAttention: Bool {
        kind == .reviewMeal
    }
}
