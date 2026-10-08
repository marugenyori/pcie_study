import SwiftUI
import WidgetKit

@main
struct PCIeStudyWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        DailyQuestionWidget()
        NewsWidget()
    }
}

// MARK: - タイムライン

struct StudyEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let todayCount: Int
    let goal: Int
    let goalMet: Bool
    let question: QuizQuestion

    static func make(for date: Date, stats: StudyStats) -> StudyEntry {
        StudyEntry(date: date,
                   streak: stats.currentStreak(today: date),
                   todayCount: stats.count(on: date),
                   goal: stats.dailyGoal,
                   goalMet: stats.isGoalMet(on: date),
                   question: DailyPick.question(for: date))
    }

    static var placeholder: StudyEntry {
        StudyEntry(date: .now, streak: 7, todayCount: 3, goal: 5, goalMet: false,
                          question: DailyPick.question(for: .now))
    }
}

struct StudyProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudyEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (StudyEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .make(for: .now, stats: StudyStats.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudyEntry>) -> Void) {
        let stats = StudyStats.load()
        let now = Date.now
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        // 日付が変わったら「今日」の値と問題が切り替わる
        let entries = [StudyEntry.make(for: now, stats: stats),
                       StudyEntry.make(for: tomorrow, stats: stats)]
        completion(Timeline(entries: entries, policy: .after(tomorrow)))
    }
}

// MARK: - 連続日数ウィジェット

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StreakWidget", provider: StudyProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("連続学習")
        .description("連続日数と、今日の目標までの進み具合を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct StreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudyEntry

    private var ratio: Double {
        min(1, Double(entry.todayCount) / Double(max(entry.goal, 1)))
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: ratio) {
                Image(systemName: "flame.fill")
            } currentValueLabel: {
                Text("\(entry.streak)")
            }
            .gaugeStyle(.accessoryCircularCapacity)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("\(entry.streak)日連続", systemImage: "flame.fill")
                    .font(.headline)
                Text(entry.goalMet ? "今日の目標達成！" : "今日 \(entry.todayCount)/\(entry.goal)問")
                    .font(.caption)
                ProgressView(value: ratio)
            }

        case .accessoryInline:
            Label("\(entry.streak)日連続・今日 \(entry.todayCount)/\(entry.goal)問", systemImage: "flame.fill")

        case .systemMedium:
            HStack(spacing: 16) {
                streakBlock
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("今日の1問")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(entry.question.question)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(4)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                }
            }

        default:
            streakBlock
        }
    }

    private var streakBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(entry.streak > 0 ? .orange : .secondary)
                Text("\(entry.streak)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("日").font(.subheadline.bold())
            }
            Text("連続学習").font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(entry.goalMet ? "目標達成！" : "今日 \(entry.todayCount)/\(entry.goal)問")
                .font(.caption.bold())
                .foregroundStyle(entry.goalMet ? .green : .primary)
            ProgressView(value: ratio)
                .tint(entry.goalMet ? .green : .orange)
        }
    }
}

// MARK: - 今日の1問ウィジェット

struct DailyQuestionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyQuestionWidget", provider: StudyProvider()) { entry in
            DailyQuestionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("今日の1問")
        .description("毎日1問、PCIe のクイズを表示します。タップするとアプリで答えられます。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct DailyQuestionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudyEntry

    var body: some View {
        let q = entry.question
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("今日の1問", systemImage: "questionmark.bubble.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
                Spacer()
                Label("\(entry.streak)", systemImage: "flame.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
            Text(q.question)
                .font(family == .systemLarge ? .headline : .subheadline.weight(.semibold))
                .lineLimit(family == .systemLarge ? 4 : 3)
                .minimumScaleFactor(0.85)
            if family == .systemLarge {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(q.choices.enumerated()), id: \.offset) { i, choice in
                        HStack(alignment: .top, spacing: 6) {
                            Text(["A", "B", "C", "D", "E"][min(i, 4)])
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(choice)
                                .font(.caption)
                                .lineLimit(2)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            Spacer(minLength: 0)
            Text("タップしてアプリで答える")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - PCIe ニュースウィジェット

struct NewsEntry: TimelineEntry {
    let date: Date
    let item: NewsItem
    /// 新しい順で何件目か（1始まり）と、ローテーションする件数
    let position: Int
    let total: Int
}

struct NewsProvider: TimelineProvider {
    /// 新しい順にこの件数を、時間ごとに順番に表示する
    static let rotationCount = 10
    /// 表示を切り替える間隔
    static let interval: TimeInterval = 3 * 3600

    static var items: [NewsItem] { Array(NewsData.all.prefix(rotationCount)) }

    /// 時刻から決まるニュース（同じ時間帯なら、どのウィジェットでも同じものになる）
    static func entry(for date: Date) -> NewsEntry? {
        let items = Self.items
        guard !items.isEmpty else { return nil }
        let slot = Int(date.timeIntervalSince1970 / interval)
        let i = (slot % items.count + items.count) % items.count
        return NewsEntry(date: date, item: items[i], position: i + 1, total: items.count)
    }

    func placeholder(in context: Context) -> NewsEntry {
        Self.entry(for: .now) ?? NewsEntry(date: .now, item: NewsData.all[0], position: 1, total: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (NewsEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NewsEntry>) -> Void) {
        let now = Date.now
        // 今の時間帯と、この先24時間ぶんの切り替え時刻を並べる
        let slotStart = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970 / Self.interval) * Self.interval)
        let steps = Int(86_400 / Self.interval)
        var entries: [NewsEntry] = []
        if let first = Self.entry(for: now) { entries.append(first) }
        for n in 1...steps {
            if let e = Self.entry(for: slotStart.addingTimeInterval(Double(n) * Self.interval)) {
                entries.append(e)
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct NewsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NewsWidget", provider: NewsProvider()) { entry in
            NewsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(NewsLink.url(for: entry.item))
        }
        .configurationDisplayName("PCIe ニュース")
        .description("PCIe の新しいニュースを、3時間ごとに切り替えて表示します。タップするとそのニュースを開きます。")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemSmall, .systemMedium])
    }
}

struct NewsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NewsEntry

    private var item: NewsItem { entry.item }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label("\(item.tag.rawValue)・\(item.dateLabel)", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption2.bold())
                    .widgetAccentable()
                    .lineLimit(1)
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .accessoryInline:
            Label(item.title, systemImage: "antenna.radiowaves.left.and.right")

        case .systemMedium:
            VStack(alignment: .leading, spacing: 6) {
                header
                Text(item.title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Spacer(minLength: 0)
            }

        default:
            VStack(alignment: .leading, spacing: 6) {
                header
                Text(item.title)
                    .font(.subheadline.bold())
                    .lineLimit(5)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                Text("\(entry.position)/\(entry.total)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(item.tag.rawValue)
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.tint.opacity(0.15), in: Capsule())
                .foregroundStyle(.tint)
            Text(item.dateLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
