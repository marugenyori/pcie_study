import Foundation
import Observation
import UserNotifications

/// 毎日の学習リマインダー（ローカル通知）
@Observable
final class ReminderManager {
    private(set) var isEnabled: Bool
    private(set) var hour: Int
    private(set) var minute: Int
    /// 通知の許可が拒否されている
    private(set) var isDenied = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let center = UNUserNotificationCenter.current()

    private static let idPrefix = "daily-reminder-"
    /// 先の分まで予約しておく日数（毎回内容を変えるため、繰り返し通知は使わない）
    private static let daysAhead = 7

    private enum Keys {
        static let enabled = "reminderEnabled"
        static let hour = "reminderHour"
        static let minute = "reminderMinute"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Keys.enabled)
        hour = defaults.object(forKey: Keys.hour) as? Int ?? 20
        minute = defaults.object(forKey: Keys.minute) as? Int ?? 0
    }

    var time: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }

    /// 通知をオンにする。許可されなかったら false
    @MainActor
    func enable(stats: StudyStats) async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        isDenied = !granted
        isEnabled = granted
        defaults.set(granted, forKey: Keys.enabled)
        await reschedule(stats: stats)
        return granted
    }

    @MainActor
    func disable() async {
        isEnabled = false
        defaults.set(false, forKey: Keys.enabled)
        await removePending()
    }

    @MainActor
    func setTime(_ date: Date, stats: StudyStats) async {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        hour = c.hour ?? 20
        minute = c.minute ?? 0
        defaults.set(hour, forKey: Keys.hour)
        defaults.set(minute, forKey: Keys.minute)
        await reschedule(stats: stats)
    }

    @MainActor
    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        isDenied = settings.authorizationStatus == .denied
    }

    /// 今後7日分の通知を予約し直す。今日の目標を達成済みなら今日の分は送らない
    @MainActor
    func reschedule(stats: StudyStats, now: Date = .now) async {
        await removePending()
        guard isEnabled else { return }
        let cal = Calendar.current
        let streak = stats.currentStreak(today: now)

        for offset in 0..<Self.daysAhead {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)),
                  let fire = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fire > now else { continue }
            if offset == 0 && stats.isGoalMet(on: now) { continue }

            let content = UNMutableNotificationContent()
            content.sound = .default
            let question = DailyPick.question(for: day)
            if offset == 0 {
                let remaining = stats.remainingToday(today: now)
                content.title = streak > 0 ? "🔥 \(streak)日連続中！今日もあと\(remaining)問" : "今日のPCIe、あと\(remaining)問"
            } else if offset == 1 && streak > 0 {
                content.title = "🔥 連続記録を伸ばそう"
            } else {
                content.title = "今日の1問"
            }
            content.body = question.question

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: Self.idPrefix + StudyStats.key(for: day),
                                                content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    @MainActor
    private func removePending() async {
        let ids = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
