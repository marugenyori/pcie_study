import SwiftUI

struct ContentView: View {
    /// ウィジェットから開いたニュース
    @State private var openedNews: NewsItem?
    /// ウィジェットから開いた「今日の1問」
    @State private var showsDailyQuestion = false

    @State private var tab = AppTab.today
    /// タブごとの画面の作り直し用（変えるとそのタブがいちばん上の画面に戻る）
    @State private var resetIDs: [AppTab: UUID] = [:]

    /// 同じタブをもう一度押したら、そのタブのいちばん上に戻る
    private var tabSelection: Binding<AppTab> {
        Binding(get: { tab }, set: { newValue in
            if newValue == tab { resetIDs[newValue] = UUID() }
            tab = newValue
        })
    }

    private func goToTabRoot(_ target: AppTab) {
        resetIDs[target] = UUID()
        tab = target
    }

    var body: some View {
        TabView(selection: tabSelection) {
            TodayView()
                .id(resetIDs[.today])
                .tabItem { Label("今日", systemImage: "flame") }
                .tag(AppTab.today)
            LearnView()
                .id(resetIDs[.learn])
                .tabItem { Label("学ぶ", systemImage: "book") }
                .tag(AppTab.learn)
            QuizHomeView()
                .id(resetIDs[.quiz])
                .tabItem { Label("クイズ", systemImage: "checkmark.circle") }
                .tag(AppTab.quiz)
            DiagramsHomeView()
                .id(resetIDs[.diagrams])
                .tabItem { Label("図解", systemImage: "square.grid.2x2") }
                .tag(AppTab.diagrams)
            ToolsHomeView()
                .id(resetIDs[.tools])
                .tabItem { Label("ツール", systemImage: "function") }
                .tag(AppTab.tools)
        }
        .environment(\.goToTabRoot, goToTabRoot)
        .onOpenURL { url in
            if let item = NewsLink.item(from: url) {
                showsDailyQuestion = false
                openedNews = item
            } else if DailyPick.isLink(url) {
                openedNews = nil
                showsDailyQuestion = true
            }
        }
        .sheet(item: $openedNews) { item in
            NewsDetailSheet(item: item)
        }
        .sheet(isPresented: $showsDailyQuestion) {
            DailyQuestionSheet()
        }
    }
}

#Preview {
    ContentView()
        .environment(ProgressStore())
        .environment(ReminderManager())
        .environment(AppSettings())
        .environment(SpecRAGClient())
        .environment(EnglishStore())
        .environment(SyncClient())
}
