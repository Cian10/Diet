import Foundation

public enum BiologicalSex: String, Codable, CaseIterable, Sendable {
    case female
    case male

    public var displayName: String {
        switch self {
        case .female: "女性"
        case .male: "男性"
        }
    }
}

public enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case sedentary
    case light
    case moderate
    case high
    case veryHigh

    public var displayName: String {
        switch self {
        case .sedentary: "久坐为主"
        case .light: "轻度活动"
        case .moderate: "中度活动"
        case .high: "高度活动"
        case .veryHigh: "极高活动"
        }
    }
}

public enum PhaseType: String, Codable, CaseIterable, Sendable {
    case bulking
    case cutting
    case maintenance
    case recovery

    public var displayName: String {
        switch self {
        case .bulking: "增肌"
        case .cutting: "减脂"
        case .maintenance: "维持"
        case .recovery: "休息／恢复"
        }
    }
}

public enum PhaseStatus: String, Codable, Sendable {
    case scheduled
    case active
    case ended

    public var displayName: String {
        switch self {
        case .scheduled: "未开始"
        case .active: "进行中"
        case .ended: "已结束"
        }
    }
}

public enum EnergyStrategy: String, Codable, CaseIterable, Sendable {
    case automatic
    case manual

    public var displayName: String {
        switch self {
        case .automatic: "按规则计算（模块 05）"
        case .manual: "手动设置目标"
        }
    }
}

public enum MealType: String, Codable, CaseIterable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack
    case other
}

public enum MealEntryStatus: String, Codable, Sendable {
    case draft
    case confirmed
    case failed
}

public enum NutritionSource: String, Codable, Sendable {
    case userLabel
    case verified
    case genericReference
    case modelEstimate
    case userCorrection
}

public enum NutritionBasisUnit: String, Codable, Sendable {
    case grams
    case milliliters
    case serving
}

public enum EstimationInputType: String, Codable, Sendable {
    case text
    case image
    case manual
}

public enum EstimationQuality: String, Codable, Sendable {
    case high
    case medium
    case low
    case unknown
}

public enum AdjustmentStatus: String, Codable, Sendable {
    case pending
    case accepted
    case rejected
}
