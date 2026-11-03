import BackgroundTasks
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
        appScene
            .backgroundTask(.appRefresh(Self.newsRefreshTask)) {
                Self.scheduleNewsRefresh()
                if await NewsData.refresh(minInterval: 0) {
                    WidgetCenter.shared.reloadTimelines(ofKind: "NewsWidget")
                }
            }
    }

    private var appScene: some Scene {
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
                    // 閉じているあいだも、ときどきニュースを読み込むよう iPhone に頼んでおく
                    if phase == .background { Self.scheduleNewsRefresh() }
                    guard phase == .active else { return }
                    progress.reloadShared()
                    Task { await reminder.reschedule(stats: progress.stats) }
                    Task {
                        // GitHub に新しいニュースがあれば読み込み、ウィジェットにも反映する（開くたび、10分に1回まで）
                        if await NewsData.refresh(minInterval: 10 * 60) {
                            WidgetCenter.shared.reloadTimelines(ofKind: "NewsWidget")
                        }
                    }
                }
        }
    }

    /// バックグラウンドでニュースを読み込む処理の名前（Info.plist の BGTaskSchedulerPermittedIdentifiers と同じ）
    static let newsRefreshTask = "pciestudy.news-refresh"

    /// アプリを閉じているあいだのニュースの読み込みを頼む（実行の時刻は iPhone が使い方に合わせて決める）
    static func scheduleNewsRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: newsRefreshTask)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 3600)
        try? BGTaskScheduler.shared.submit(request)
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
