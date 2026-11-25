import Foundation

/// Pure presentation priority for the single focus card on the Today page.
/// It never decides whether a target or meal can be saved.
struct TodayFocusPresentation: Equatable {
    enum Kind: Equatable {
        case confirmTarget
        case reviewMeal
        case startLogging
        case recordDinner
        case completed
        case maintain
    }

    let kind: Kind

    init(
        hasTarget: Bool,
        targetRequiresConfirmation: Bool,
        hasPendingOrFailedMeal: Bool,
        hasDinner: Bool,
        isGoalMet: Bool
    ) {
        if hasTarget && targetRequiresConfirmation {
            kind = .confirmTarget
        } else if hasPendingOrFailedMeal {
            kind = .reviewMeal
        } else if !hasTarget {
            kind = .startLogging
        } else if !hasDinner {
            kind = .recordDinner
        } else if isGoalMet {
            kind = .completed
        } else {
            kind = .maintain
        }
    }

    var title: String {
        switch kind {
        case .confirmTarget: "确认今日目标"
        case .reviewMeal: "完成这一餐的确认"
        case .startLogging: "记录今天的第一餐"
        case .recordDinner: "记录晚餐"
        case .completed: "今天已完成，保持轻松"
        case .maintain: "保持当前节奏"
        }
    }

    var message: String {
        switch kind {
        case .confirmTarget:
            "今日目标尚未生效。核对热量与宏量营养后，再开始记录会更准确。"
        case .reviewMeal:
            "有一餐仍待确认或分析未完成。继续核对内容，已填写的信息会保留。"
        case .startLogging:
            "从文字或图片开始，确认后的餐食才会计入今日摄入。"
        case .recordDinner:
            "今天还没有晚餐记录。用餐后花一分钟记下，就能看到更完整的今日概况。"
        case .completed:
            "今日热量处于目标范围内。无需追求绝对精确，按自己的节奏继续即可。"
        case .maintain:
            "根据已确认记录安排下一餐即可；营养不完整时，当前合计仅作参考。"
        }
    }

    var actionTitle: String {
        switch kind {
        case .confirmTarget: "核对并确认目标"
        case .reviewMeal: "继续确认"
        case .startLogging, .recordDinner: "记一餐"
        case .completed, .maintain: "查看今日记录"
        }
    }

    var needsAttention: Bool {
        kind == .confirmTarget || kind == .reviewMeal
    }
}
