import SwiftUI

struct LearnView: View {
    @Environment(ProgressStore.self) private var progress

    private var completionRatio: Double {
        let done = LessonData.all.filter { progress.isCompleted($0.id) }.count
        return Double(done) / Double(LessonData.all.count)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            ProgressRing(value: completionRatio)
                            Text("\(Int(completionRatio * 100))%")
                                .font(.caption.bold())
                        }
                        .frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("学習の進み具合").font(.headline)
                            Text("\(LessonData.all.filter { progress.isCompleted($0.id) }.count) / \(LessonData.all.count) 章 読了")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if progress.answeredTotal > 0 {
                                Text("クイズ正答率 \(Int(progress.overallAccuracy * 100))%（\(progress.answeredTotal)問）")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("読みもの") {
                    NavigationLink {
                        ColumnListView()
                    } label: {
                        Label("コラム（\(ColumnData.all.count)本）", systemImage: "newspaper")
                    }
                    NavigationLink {
                        NewsListView()
                    } label: {
                        Label("PCIe ニュース", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    NavigationLink {
                        GlossaryView()
                    } label: {
                        Label("用語集（\(GlossaryData.all.count)語）", systemImage: "character.book.closed")
                    }
                }

                ForEach(Level.allCases) { level in
                    Section {
                        ForEach(LessonData.all.filter { $0.level == level }) { chapter in
                            NavigationLink(value: chapter) {
                                ChapterRow(chapter: chapter, completed: progress.isCompleted(chapter.id))
                            }
                        }
                    } header: {
                        HStack {
                            LevelBadge(level: level)
                            Text(levelDescription(level))
                        }
                    }
                }
            }
            .screenBackground()
            .navigationTitle("PCIeを学ぶ")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { DisplaySettingsButton() }
            }
            .navigationDestination(for: Chapter.self) { chapter in
                ChapterDetailView(chapter: chapter)
            }
        }
    }

    private func levelDescription(_ level: Level) -> String {
        switch level {
        case .beginner: return "全体像をつかむ"
        case .intermediate: return "プロトコルの仕組み"
        case .advanced: return "実装・デバッグに踏み込む"
        }
    }
}

struct ChapterRow: View {
    let chapter: Chapter
    let completed: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: chapter.symbol)
                .font(.title3)
                .foregroundStyle(chapter.level.color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(chapter.number). \(chapter.title)")
                    .font(.body.weight(.medium))
                Text(chapter.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    LearnView().environment(ProgressStore())
}
