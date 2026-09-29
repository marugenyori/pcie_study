import SwiftUI

struct QuizHomeView: View {
    @Environment(ProgressStore.self) private var progress
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            ProgressRing(value: progress.overallAccuracy, color: .blue)
                            Text("\(Int(progress.overallAccuracy * 100))%").font(.caption.bold())
                        }
                        .frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("通算正答率").font(.headline)
                            Text("\(progress.correctTotal) / \(progress.answeredTotal) 問正解")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("全\(QuizData.all.count)問収録")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("おまかせ") {
                    NavigationLink {
                        QuizSessionView(title: "ランダム10問", key: "random10", questions: QuizData.random(10))
                    } label: {
                        QuizMenuRow(symbol: "shuffle", title: "ランダム10問", detail: "全範囲からランダム", best: progress.bestScore(for: "random10"))
                    }
                    NavigationLink {
                        QuizSessionView(title: "全問チャレンジ", key: "all", questions: QuizData.all.shuffled())
                    } label: {
                        QuizMenuRow(symbol: "flame", title: "全問チャレンジ", detail: "\(QuizData.all.count)問", best: progress.bestScore(for: "all"))
                    }
                }

                Section("レベル別") {
                    ForEach(Level.allCases) { level in
                        let qs = QuizData.questions(forLevel: level)
                        NavigationLink {
                            QuizSessionView(title: "\(level.rawValue)レベル", key: "level-\(level.id)", questions: qs.shuffled())
                        } label: {
                            QuizMenuRow(symbol: "chart.bar", title: "\(level.rawValue)レベル", detail: "\(qs.count)問",
                                        best: progress.bestScore(for: "level-\(level.id)"), tint: level.color)
                        }
                    }
                }

                Section("章別") {
                    ForEach(LessonData.all) { chapter in
                        let qs = QuizData.questions(forChapter: chapter.id)
                        if !qs.isEmpty {
                            NavigationLink {
                                QuizSessionView(title: chapter.title, key: chapter.id, questions: qs)
                            } label: {
                                QuizMenuRow(symbol: chapter.symbol, title: "\(chapter.number). \(chapter.title)",
                                            detail: "\(qs.count)問", best: progress.bestScore(for: chapter.id),
                                            tint: chapter.level.color)
                            }
                        }
                    }
                }

                Section {
                    Button("学習記録をリセット", role: .destructive) { showResetAlert = true }
                }
            }
            .navigationTitle("クイズ")
            .alert("学習記録をリセットしますか？", isPresented: $showResetAlert) {
                Button("リセット", role: .destructive) { progress.resetAll() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("読了した章とクイズの成績がすべて消去されます。")
            }
        }
    }
}

struct QuizMenuRow: View {
    let symbol: String
    let title: String
    let detail: String
    let best: Int?
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let best {
                Text("最高 \(best)%")
                    .font(.caption.bold())
                    .foregroundStyle(best >= 80 ? .green : .secondary)
            }
        }
    }
}
