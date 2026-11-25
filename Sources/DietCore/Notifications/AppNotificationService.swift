import Foundation
import UserNotifications

public struct LocalNotificationRequest {
    public var id: String
    public var title: String
    public var body: String
    public var dateComponents: DateComponents
    public var repeats: Bool
    public var destination: String

    public init(id: String, title: String, body: String, dateComponents: DateComponents, repeats: Bool, destination: String) {
        self.id = id
        self.title = title
        self.body = body
        self.dateComponents = dateComponents
        self.repeats = repeats
        self.destination = destination
    }
}

public enum AppNotificationError: LocalizedError, Equatable {
    case permissionDenied
    public var errorDescription: String? { "通知权限未开启。设置已保存，但系统提醒尚未安排。" }
}

@MainActor
public protocol NotificationScheduling: AnyObject {
    func requestAuthorization() async throws -> Bool
    func schedule(_ request: LocalNotificationRequest) async throws
    func pendingIdentifiers() async -> [String]
    func remove(identifiers: [String]) async
}

@MainActor
public final class InMemoryNotificationScheduler: NotificationScheduling {
    public var authorizationGranted = true
    public private(set) var requests: [String: LocalNotificationRequest] = [:]
    public init() {}
    public func requestAuthorization() async throws -> Bool { authorizationGranted }
    public func schedule(_ request: LocalNotificationRequest) async throws { requests[request.id] = request }
    public func pendingIdentifiers() async -> [String] { Array(requests.keys) }
    public func remove(identifiers: [String]) async { identifiers.forEach { requests.removeValue(forKey: $0) } }
}

@MainActor
public final class UserNotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter
    public init(center: UNUserNotificationCenter = .current()) { self.center = center }

    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    public func schedule(_ request: LocalNotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.userInfo = ["destination": request.destination]
        let trigger = UNCalendarNotificationTrigger(dateMatching: request.dateComponents, repeats: request.repeats)
        try await center.add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
    }

    public func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    public func remove(identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

@MainActor
public protocol NotificationSettingsStoring: AnyObject {
    func loadSettings() throws -> NotificationSettings?
    func saveSettings(_ settings: NotificationSettings) throws
}

@MainActor
public final class InMemoryNotificationSettingsStore: NotificationSettingsStoring {
    private var settings: NotificationSettings?
    public init(settings: NotificationSettings? = nil) { self.settings = settings }
    public func loadSettings() throws -> NotificationSettings? { settings }
    public func saveSettings(_ settings: NotificationSettings) throws { self.settings = settings }
}

@MainActor
public final class AppNotificationService {
    private let scheduler: NotificationScheduling
    private let prefix = "dietapp."

    public init(scheduler: NotificationScheduling) { self.scheduler = scheduler }

    public func synchronize(
        settings: NotificationSettings,
        phase: PhasePlan? = nil,
        intake: NutritionTotals? = nil,
        target: DailyTarget? = nil,
        now: Date = Date()
    ) async throws {
        let pending = await scheduler.pendingIdentifiers().filter { $0.hasPrefix(prefix) }
        await scheduler.remove(identifiers: pending)
        let needsAuthorization = settings.mealRemindersEnabled || settings.progressRemindersEnabled
            || settings.weeklyReviewEnabled || settings.phaseReviewEnabled
        guard needsAuthorization else { return }
        guard try await scheduler.requestAuthorization() else { throw AppNotificationError.permissionDenied }

        if settings.mealRemindersEnabled {
            for minute in Set(settings.mealReminderMinutes) where !Self.isQuiet(minute: minute, settings: settings) {
                let components = Self.timeComponents(minute: minute)
                try await scheduler.schedule(LocalNotificationRequest(
                    id: prefix + "meal.\(minute)",
                    title: "记录这一餐",
                    body: "用文本或照片记录饮食，确认后再计入今日摄入。",
                    dateComponents: components,
                    repeats: true,
                    destination: "diary"
                ))
            }
        }

        if settings.weeklyReviewEnabled, !Self.isQuiet(minute: settings.weeklyReviewMinute, settings: settings) {
            var components = Self.timeComponents(minute: settings.weeklyReviewMinute)
            components.weekday = settings.weeklyReviewWeekday
            try await scheduler.schedule(LocalNotificationRequest(
                id: prefix + "weekly-review",
                title: "每周饮食复盘",
                body: "查看七日记录、体重趋势和是否有需要确认的调整建议。",
                dateComponents: components,
                repeats: true,
                destination: "trends"
            ))
        }

        if settings.phaseReviewEnabled, let end = phase?.endDate {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: end)
            components.hour = 9
            components.minute = 0
            if let date = Calendar.current.date(from: components), date > now {
                try await scheduler.schedule(LocalNotificationRequest(
                    id: prefix + "phase.\(phase!.id.uuidString)",
                    title: "阶段方案复核",
                    body: "当前健身阶段即将到期，请确认是否继续、调整或切换阶段。",
                    dateComponents: components,
                    repeats: false,
                    destination: "profile"
                ))
            }
        }

        if settings.progressRemindersEnabled, let target,
           !Self.isQuiet(minute: settings.progressReminderMinute, settings: settings) {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
            let time = Self.timeComponents(minute: settings.progressReminderMinute)
            components.hour = time.hour
            components.minute = time.minute
            if let date = Calendar.current.date(from: components), date > now {
                let knownCalories = intake?.calories ?? 0
                let difference = target.calories - knownCalories
                let body = intake?.isComplete == false
                    ? "当前为部分合计，请先补全无法计算的食物。目标差额 \(Int(difference.rounded())) kcal。"
                    : "已知摄入 \(Int(knownCalories.rounded())) kcal，目标差额 \(Int(difference.rounded())) kcal。无需因单日偏差修改长期目标。"
                try await scheduler.schedule(LocalNotificationRequest(
                    id: prefix + "progress.today",
                    title: "今日营养进度",
                    body: body,
                    dateComponents: components,
                    repeats: false,
                    destination: "today"
                ))
            }
        }
    }

    private static func timeComponents(minute: Int) -> DateComponents {
        DateComponents(hour: max(0, min(23, minute / 60)), minute: max(0, min(59, minute % 60)))
    }

    private static func isQuiet(minute: Int, settings: NotificationSettings) -> Bool {
        guard let start = settings.quietHoursStartMinute, let end = settings.quietHoursEndMinute else { return false }
        if start == end { return true }
        if start < end { return minute >= start && minute < end }
        return minute >= start || minute < end
    }
}
