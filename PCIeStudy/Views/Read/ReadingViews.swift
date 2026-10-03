import SwiftUI

// MARK: - コラム

struct ColumnListView: View {
    var body: some View {
        List(ColumnData.all) { column in
            NavigationLink {
                ColumnDetailView(column: column)
            } label: {
                ColumnRow(column: column)
            }
        }
        .navigationTitle("コラム")
    }
}

struct ColumnRow: View {
    let column: ReadingColumn

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: column.symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(column.title).font(.body.weight(.medium))
                Text(column.lead)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ColumnDetailView: View {
    let column: ReadingColumn

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("コラム・約\(column.minutes)分", systemImage: column.symbol)
                        .font(.caption.bold())
                        .foregroundStyle(.tint)
                    Text(column.title).font(.title.bold())
                    Text(column.lead).font(.subheadline).foregroundStyle(.secondary)
                }

                ForEach(Array(column.blocks.enumerated()), id: \.offset) { _, block in
                    ContentBlockView(block: block)
                }

                if let id = column.chapterID, let chapter = LessonData.chapter(id: id) {
                    Divider().padding(.vertical, 8)
                    NavigationLink {
                        ChapterDetailView(chapter: chapter)
                    } label: {
                        Label("関連する章：\(chapter.number). \(chapter.title)", systemImage: chapter.symbol)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("コラム")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ニュース

struct NewsListView: View {
    var body: some View {
        List {
            Section {
                ForEach(NewsData.all) { item in
                    NewsRow(item: item, showsSummary: true)
                }
            } footer: {
                Text("最終更新：\(NewsData.updated)。ニュースはアプリのアップデートで更新されます。")
            }
        }
        .navigationTitle("PCIe ニュース")
    }
}

struct NewsRow: View {
    let item: NewsItem
    var showsSummary = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(item.tag.rawValue)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(.tint)
                Text(item.dateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(item.title)
                .font(.subheadline.bold())
                .fixedSize(horizontal: false, vertical: true)
            if showsSummary {
                Text(item.summary)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text("出典：\(item.source)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let urlString = item.url, let url = URL(string: urlString) {
                        Link(destination: url) {
                            Label("記事を開く", systemImage: "safari")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
