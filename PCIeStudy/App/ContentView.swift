import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            LearnView()
                .tabItem { Label("学ぶ", systemImage: "book") }
            QuizHomeView()
                .tabItem { Label("クイズ", systemImage: "checkmark.circle") }
            DiagramsHomeView()
                .tabItem { Label("図解", systemImage: "square.grid.2x2") }
            ToolsHomeView()
                .tabItem { Label("ツール", systemImage: "function") }
            GlossaryView()
                .tabItem { Label("用語集", systemImage: "character.book.closed") }
        }
    }
}

#Preview {
    ContentView()
        .environment(ProgressStore())
}
