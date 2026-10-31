import SwiftUI

struct ContentView: View {
    /// ウィジェットから開いたニュース
    @State private var openedNews: NewsItem?
    /// ウィジェットから開いた「今日の1問」
    @State private var showsDailyQuestion = false

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今日", systemImage: "flame") }
            LearnView()
                .tabItem { Label("学ぶ", systemImage: "book") }
            QuizHomeView()
                .tabItem { Label("クイズ", systemImage: "checkmark.circle") }
            DiagramsHomeView()
                .tabItem { Label("図解", systemImage: "square.grid.2x2") }
            ToolsHomeView()
                .tabItem { Label("ツール", systemImage: "function") }
        }
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
}
