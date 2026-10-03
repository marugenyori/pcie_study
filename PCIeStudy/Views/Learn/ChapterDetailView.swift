import SwiftUI

struct ChapterDetailView: View {
    let chapter: Chapter
    @Environment(ProgressStore.self) private var progress

    private var chapterQuestions: [QuizQuestion] {
        QuizData.questions(forChapter: chapter.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                ForEach(Array(chapter.blocks.enumerated()), id: \.offset) { _, block in
                    ContentBlockView(block: block)
                }

                Divider().padding(.vertical, 8)
                actions
            }
            .padding()
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    progress.toggleCompleted(chapter.id)
                } label: {
                    Image(systemName: progress.isCompleted(chapter.id) ? "checkmark.circle.fill" : "circle")
                }
                .accessibilityLabel(progress.isCompleted(chapter.id) ? "未読に戻す" : "読了にする")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                LevelBadge(level: chapter.level)
                Text("第\(chapter.number)章").font(.caption).foregroundStyle(.secondary)
            }
            Text(chapter.title).font(.title.bold())
            Text(chapter.summary).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 12) {
            if let diagram = chapter.diagram {
                NavigationLink {
                    DiagramDestination(kind: diagram)
                } label: {
                    Label("図解で確認：\(diagram.title)", systemImage: diagram.symbol)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if !chapterQuestions.isEmpty {
                NavigationLink {
                    QuizSessionView(title: chapter.title, key: chapter.id, questions: chapterQuestions)
                } label: {
                    Label("この章のクイズ（\(chapterQuestions.count)問）", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button {
                progress.toggleCompleted(chapter.id)
            } label: {
                Label(progress.isCompleted(chapter.id) ? "読了済み（タップで取り消し）" : "読了にする",
                      systemImage: progress.isCompleted(chapter.id) ? "checkmark.circle.fill" : "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(progress.isCompleted(chapter.id) ? Color.green : nil)

            if let next = LessonData.next(after: chapter) {
                NavigationLink(value: next) {
                    HStack {
                        Text("次の章：\(next.number). \(next.title)")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .simultaneousGesture(TapGesture().onEnded {
                    progress.markCompleted(chapter.id)
                })
            }
        }
    }
}

struct ContentBlockView: View {
    let block: ContentBlock
    @Environment(AppSettings.self) private var settings

    var body: some View {
        switch block {
        case .heading(let s):
            Text(s)
                .font(.title3.bold())
                .padding(.top, 8)

        case .text(let s):
            Text(markdown: s)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(settings.lineSpacing)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        Text(markdown: item)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(settings.lineSpacing)
                    }
                }
            }

        case .table(let header, let rows):
            TableBlockView(header: header, rows: rows)

        case .note(let s):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text(markdown: s)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

        case .figure(let s):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(verbatim: s)
                    .font(.system(.caption, design: .monospaced))
                    .fixedSize()
                    .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct TableBlockView: View {
    let header: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(Array(header.enumerated()), id: \.offset) { _, h in
                        Text(h)
                            .font(.caption.bold())
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.tint.opacity(0.15))
                    }
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(markdown: cell)
                                .font(.caption)
                                .padding(8)
                                .frame(maxWidth: 240, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .background(index.isMultiple(of: 2) ? Color.clear : Color(.secondarySystemBackground))
                        }
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator)))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
