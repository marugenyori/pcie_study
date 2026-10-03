import SwiftUI

/// 毎日開く「今日」タブ
struct TodayView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(ReminderManager.self) private var reminder

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    StreakCard()
                    DailyQuestionCard()
                    quickActions
                    columnCard
                    newsCard
                    AchievementsCard()
                    ReminderCard()
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .screenBackground()
            .navigationTitle(todayTitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { DisplaySettingsButton() }
            }
        }
    }

    private var todayTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日（E）"
        return f.string(from: .now)
    }

    // MARK: すぐ始める

    private var quickActions: some View {
        let weak = QuizData.questions(ids: progress.weakQuestionIDs)
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle("すぐ始める", symbol: "play.circle.fill")
            HStack(spacing: 10) {
                NavigationLink {
                    QuizSessionView(title: "ランダム10問", key: "random10", questions: QuizData.random(10),
                                    regenerate: { QuizData.random(10) })
                } label: {
                    ActionTile(title: "ランダム10問", detail: "全範囲から", symbol: "shuffle", tint: .blue)
                }
                NavigationLink {
                    QuizSessionView.weakQuestions(progress: progress)
                } label: {
                    ActionTile(title: "苦手な問題", detail: weak.isEmpty ? "なし" : "\(weak.count)問",
                               symbol: "target", tint: .orange)
                }
                .disabled(weak.isEmpty)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 今日のコラム

    private var columnCard: some View {
        let column = ColumnData.today()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle("今日のコラム", symbol: "newspaper.fill")
                Spacer()
                NavigationLink("すべて") { ColumnListView() }
                    .font(.subheadline)
            }
            NavigationLink {
                ColumnDetailView(column: column)
            } label: {
                ColumnRow(column: column)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle(cornerRadius: 16)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: ニュース

    private var newsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle("PCIe ニュース", symbol: "antenna.radiowaves.left.and.right")
                Spacer()
                NavigationLink("すべて") { NewsListView() }
                    .font(.subheadline)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(NewsData.all.prefix(3).enumerated()), id: \.element.id) { i, item in
                    if i > 0 { Divider() }
                    NavigationLink {
                        NewsListView()
                    } label: {
                        NewsRow(item: item)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .cardStyle(cornerRadius: 16)
        }
    }
}

// MARK: - 部品

struct SectionTitle: View {
    let title: String
    let symbol: String

    init(_ title: String, symbol: String) {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.headline)
    }
}

private struct ActionTile: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
            Text(title).font(.subheadline.bold())
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 16)
    }
}

// MARK: - 連続日数と今日の目標

private struct StreakCard: View {
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        let stats = progress.stats
        let streak = stats.currentStreak()
        let todayCount = stats.count(on: .now)
        let ratio = min(1, Double(todayCount) / Double(max(stats.dailyGoal, 1)))
        let met = stats.isGoalMet(on: .now)

        return VStack(spacing: 16) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(streak > 0 ? .orange : .secondary)
                        Text("\(streak)")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .contentTransition(.numericText())
                        Text("日連続").font(.headline)
                    }
                    Text(message(streak: streak, met: met, remaining: stats.remainingToday()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("最長記録 \(stats.bestStreak)日")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    ProgressRing(value: ratio, lineWidth: 10, color: met ? .green : .orange)
                    VStack(spacing: 0) {
                        Text("\(todayCount)").font(.title2.bold().monospacedDigit())
                        Text("/ \(stats.dailyGoal)問").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 84, height: 84)
            }

            RecentDaysView(stats: stats)

            HStack {
                Text("1日の目標")
                    .font(.subheadline)
                Spacer()
                Picker("1日の目標", selection: Binding(
                    get: { stats.dailyGoal },
                    set: { progress.setDailyGoal($0) }
                )) {
                    ForEach(StudyStats.goalChoices, id: \.self) { Text("\($0)問").tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
        }
        .padding()
        .cardStyle(cornerRadius: 20)
        .animation(.spring, value: todayCount)
    }

    private func message(streak: Int, met: Bool, remaining: Int) -> String {
        if met { return "今日の目標を達成しました！" }
        if streak > 0 { return "あと\(remaining)問で記録を伸ばせます" }
        return "あと\(remaining)問で今日の目標達成"
    }
}

/// 直近4週間の達成状況
private struct RecentDaysView: View {
    let stats: StudyStats

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let days: [Date] = (0..<28).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }

        VStack(alignment: .leading, spacing: 6) {
            Text("直近4週間").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 14), spacing: 4) {
                ForEach(days, id: \.self) { day in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color(for: day))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if cal.isDateInToday(day) {
                                RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.6), lineWidth: 1.5)
                            }
                        }
                        .accessibilityLabel("\(StudyStats.key(for: day))：\(stats.count(on: day))問")
                }
            }
        }
    }

    private func color(for day: Date) -> Color {
        let n = stats.count(on: day)
        if stats.isGoalMet(on: day) { return .orange }
        if n > 0 { return .orange.opacity(0.35) }
        return Color(.tertiarySystemFill)
    }
}

// MARK: - 今日の1問

private struct DailyQuestionCard: View {
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        let q = DailyPick.question()
        let answered = progress.dailyAnswer()

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle("今日の1問", symbol: "questionmark.bubble.fill")
                Spacer()
                if let chapter = LessonData.chapter(id: q.chapterID) {
                    Text(chapter.title)
                        .font(.caption)
                        .foregroundStyle(chapter.level.color)
                }
            }
            Text(q.question)
                .font(.body.bold())
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(Array(q.choices.enumerated()), id: \.offset) { i, choice in
                    Button {
                        withAnimation { progress.answerDaily(q, choice: i) }
                    } label: {
                        HStack(alignment: .top) {
                            Text(choice)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            if let answered {
                                if i == q.answer {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                } else if i == answered {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                }
                            }
                        }
                        .font(.subheadline)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .choiceTile(choiceState(i, answered: answered, q: q), cornerRadius: 12)
                    }
                    .buttonStyle(.plain)
                    .disabled(answered != nil)
                }
            }

            if let answered {
                VStack(alignment: .leading, spacing: 6) {
                    Label(answered == q.answer ? "正解！" : "不正解",
                          systemImage: answered == q.answer ? "checkmark.seal.fill" : "xmark.octagon.fill")
                        .font(.headline)
                        .foregroundStyle(answered == q.answer ? .green : .red)
                    Text(q.explanation)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("明日また新しい問題が出ます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .cardStyle(cornerRadius: 20)
    }

    private func choiceState(_ i: Int, answered: Int?, q: QuizQuestion) -> ChoiceState {
        guard let answered else { return .normal }
        if i == q.answer { return .correct }
        if i == answered { return .wrong }
        return .dimmed
    }
}

// MARK: - 実績

private struct AchievementsCard: View {
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        let items = Achievement.all(for: progress)
        let unlocked = items.filter(\.unlocked).count

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle("実績", symbol: "rosette")
                Spacer()
                Text("\(unlocked) / \(items.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 10) {
                ForEach(items) { a in
                    VStack(spacing: 6) {
                        Image(systemName: a.unlocked ? a.symbol : "lock.fill")
                            .font(.title2)
                            .foregroundStyle(a.unlocked ? Color.orange : Color.secondary)
                            .frame(height: 30)
                        Text(a.title)
                            .font(.caption2.bold())
                            .multilineTextAlignment(.center)
                        Text(a.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .cardStyle(cornerRadius: 12)
                    .opacity(a.unlocked ? 1 : 0.6)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding()
        .cardStyle(cornerRadius: 20)
    }
}

// MARK: - リマインダー

private struct ReminderCard: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(ReminderManager.self) private var reminder

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("毎日のリマインダー", symbol: "bell.badge.fill")
            Toggle("通知で知らせる", isOn: Binding(
                get: { reminder.isEnabled },
                set: { on in
                    Task {
                        if on {
                            _ = await reminder.enable(stats: progress.stats)
                        } else {
                            await reminder.disable()
                        }
                    }
                }
            ))
            if reminder.isEnabled {
                DatePicker("時刻", selection: Binding(
                    get: { reminder.time },
                    set: { date in Task { await reminder.setTime(date, stats: progress.stats) } }
                ), displayedComponents: .hourAndMinute)
                Text("その日の「今日の1問」をお知らせします。目標を達成した日は通知しません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if reminder.isDenied {
                Text("通知が許可されていません。設定アプリの「通知」から、このアプリの通知をオンにしてください。")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .cardStyle(cornerRadius: 20)
        .task { await reminder.refreshAuthorization() }
    }
}
