import SwiftUI
import UIKit
import WidgetKit

@main
struct PCIeStudyApp: App {
    @State private var progress = ProgressStore()
    @State private var reminder = ReminderManager()
    @State private var settings = AppSettings()
    @State private var specRAG = SpecRAGClient()
    @State private var english = EnglishStore()
    @State private var sync = SyncClient()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .applyAppSettings(settings)
                .environment(progress)
                .environment(reminder)
                .environment(settings)
                .environment(specRAG)
                .environment(english)
                .environment(sync)
                .onChange(of: progress.stats) {
                    // 学習記録が変わったら、ウィジェットと通知の内容を更新する
                    WidgetCenter.shared.reloadAllTimelines()
                    Task { await reminder.reschedule(stats: progress.stats) }
                }
                .onChange(of: scenePhase) { _, phase in
                    // ブラウザ版と記録を同期する（開いたときと、閉じるとき）
                    if phase == .active || phase == .background {
                        syncWithPC(inBackground: phase == .background)
                    }
                    guard phase == .active else { return }
                    progress.reloadShared()
                    Task { await reminder.reschedule(stats: progress.stats) }
                    Task {
                        // GitHub に新しいニュースがあれば読み込み、ウィジェットにも反映する
                        if await NewsData.refresh() {
                            WidgetCenter.shared.reloadTimelines(ofKind: "NewsWidget")
                        }
                    }
                }
        }
    }

    private func syncWithPC(inBackground: Bool) {
        // 閉じるときは、終わるまで少しだけ動かしてもらう
        let task = inBackground ? UIApplication.shared.beginBackgroundTask(withName: "sync") : .invalid
        Task {
            await sync.sync(progress: progress, english: english, base: specRAG.baseURL)
            if task != .invalid { UIApplication.shared.endBackgroundTask(task) }
        }
    }
}
