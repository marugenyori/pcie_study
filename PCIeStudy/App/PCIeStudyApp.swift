import SwiftUI
import WidgetKit

@main
struct PCIeStudyApp: App {
    @State private var progress = ProgressStore()
    @State private var reminder = ReminderManager()
    @State private var settings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .applyAppSettings(settings)
                .environment(progress)
                .environment(reminder)
                .environment(settings)
                .onChange(of: progress.stats) {
                    // 学習記録が変わったら、ウィジェットと通知の内容を更新する
                    WidgetCenter.shared.reloadAllTimelines()
                    Task { await reminder.reschedule(stats: progress.stats) }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    progress.reloadShared()
                    Task { await reminder.reschedule(stats: progress.stats) }
                }
        }
    }
}
