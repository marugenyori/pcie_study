import SwiftUI

/// ゲームモードの種類
enum GameMode: String, CaseIterable, Identifiable {
    case timeAttack, survival

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeAttack: return "タイムアタック"
        case .survival: return "サバイバル"
        }
    }

    var symbol: String {
        switch self {
        case .timeAttack: return "stopwatch.fill"
        case .survival: return "heart.fill"
        }
    }

    var tint: Color {
        switch self {
        case .timeAttack: return .blue
        case .survival: return .pink
        }
    }

    var rule: String {
        switch self {
        case .timeAttack: return "60秒でできるだけ多く正解しよう。答えるとすぐ次の問題に進みます。"
        case .survival: return "ライフは3つ。間違えるか「わからない」でライフが減ります。何問続けられるかな？"
        }
    }
}

/// タイムアタックとサバイバル
struct GameModeView: View {
    let mode: GameMode

    private enum Phase { case ready, playing, finished }

    @Environment(ProgressStore.self) private var progress
    @State private var fx = GameFX()
    @State private var phase: Phase = .ready
    @State private var deck: [QuizQuestion] = []
    @State private var index = 0
    @State private var selected: Int?
    @State private var correct = 0
    @State private var combo = 0
    @State private var bestCombo = 0
    @State private var lives = 3
    @State private var xpGained = 0
    @State private var missed: [QuizQuestion] = []
    @State private var endTime = Date.now
    @State private var isNewBest = false
    @State private var correctTick = 0
    @State private var wrongTick = 0

    private static let timeLimit: Double = 60
    private static let maxLives = 3

    var body: some View {
        Group {
            switch phase {
            case .ready: readyView
            case .playing: playingView
            case .finished: resultView
            }
        }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
        .gameEffects(fx)
        .sensoryFeedback(.success, trigger: correctTick)
        .sensoryFeedback(.error, trigger: wrongTick)
        .task(id: phase == .playing) {
            guard phase == .playing, mode == .timeAttack else { return }
            try? await Task.sleep(for: .seconds(Self.timeLimit))
            if phase == .playing { finish() }
        }
    }

    // MARK: - 開始前

    private var readyView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 64))
                    .foregroundStyle(mode.tint.gradient)
                    .padding(.top, 24)
                Text(mode.title)
                    .font(.largeTitle.weight(.heavy))
                Text(mode.rule)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                if let best = progress.gameBest[mode.rawValue] {
                    Label("自己ベスト \(best)問", systemImage: "trophy.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
                Button {
                    start()
                } label: {
                    Text("スタート")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(.primary))
                .tint(mode.tint)
                .padding(.horizontal, 32)
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - プレイ中

    private var playingView: some View {
        let q = deck[index]
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statusBar

                Text(q.question)
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .id(q.id)

                VStack(spacing: 10) {
                    ForEach(Array(q.choices.enumerated()), id: \.offset) { i, choice in
                        Button {
                            answer(i)
                        } label: {
                            Text(choice)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .choiceTile(choiceState(i, q))
                        }
                        .buttonStyle(.plain)
                        .disabled(selected != nil)
                    }
                }

                if mode == .survival {
                    if let selected, selected != q.answer {
                        AnswerDetailView(question: q, selected: selected)
                        Button {
                            next()
                        } label: {
                            Text(lives > 0 ? "次の問題へ" : "結果を見る")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppButtonStyle(.primary))
                    } else if selected == nil {
                        UnknownAnswerButton { answer(QuizQuestion.unknownChoice) }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .animation(.easeInOut(duration: 0.2), value: selected)
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            switch mode {
            case .timeAttack:
                TimelineView(.periodic(from: .now, by: 0.2)) { context in
                    let remaining = max(0, endTime.timeIntervalSince(context.date))
                    HStack(spacing: 8) {
                        Image(systemName: "stopwatch.fill")
                            .foregroundStyle(remaining < 10 ? Color.red : mode.tint)
                        ProgressView(value: remaining, total: Self.timeLimit)
                            .tint(remaining < 10 ? .red : mode.tint)
                            .frame(maxWidth: 140)
                        Text("\(Int(remaining.rounded(.up)))秒")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(remaining < 10 ? Color.red : Color.primary)
                    }
                }
            case .survival:
                HStack(spacing: 4) {
                    ForEach(0..<Self.maxLives, id: \.self) { i in
                        Image(systemName: i < lives ? "heart.fill" : "heart")
                            .foregroundStyle(i < lives ? Color.pink : Color.secondary)
                            .symbolEffect(.bounce, value: lives)
                    }
                }
                .font(.title3)
            }
            Spacer()
            if combo >= 2 {
                Label("\(combo)", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .contentTransition(.numericText())
            }
            Label("\(correct)", systemImage: "checkmark.circle.fill")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.green)
                .contentTransition(.numericText())
        }
        .padding()
        .cardStyle(cornerRadius: 16)
        .animation(.spring, value: correct)
        .animation(.spring, value: combo)
    }

    private func choiceState(_ i: Int, _ q: QuizQuestion) -> ChoiceState {
        guard let selected else { return .normal }
        if i == q.answer { return .correct }
        if i == selected { return .wrong }
        return .dimmed
    }

    // MARK: - 結果

    private var resultView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(mode == .survival ? "ゲームオーバー" : "タイムアップ！")
                    .font(.title.weight(.heavy))
                    .padding(.top, 16)
                VStack(spacing: 4) {
                    Text("\(correct)")
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                        .foregroundStyle(mode.tint.gradient)
                    Text("問正解").font(.headline)
                }
                if isNewBest {
                    Label("自己ベスト更新！", systemImage: "trophy.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                } else if let best = progress.gameBest[mode.rawValue] {
                    Text("自己ベスト \(best)問")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    statTile("獲得XP", "+\(xpGained)", "star.fill", .orange)
                    statTile("最大コンボ", "\(bestCombo)", "flame.fill", .red)
                }

                LevelCard()

                HStack(spacing: 12) {
                    Button {
                        start()
                    } label: {
                        Label("もう一度", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppButtonStyle(.primary))
                    .tint(mode.tint)
                }

                if !missed.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("間違えた問題").font(.title3.bold())
                        ForEach(missed) { q in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(q.question).font(.subheadline.bold())
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("正解：\(q.choices[q.answer])").font(.subheadline).foregroundStyle(.green)
                                Text(q.explanation).font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle(cornerRadius: 12)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private func statTile(_ title: String, _ value: String, _ symbol: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(value).font(.title2.bold().monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .cardStyle(cornerRadius: 16)
    }

    // MARK: - ロジック

    private func start() {
        deck = QuizData.all.shuffled().map { $0.shuffled() }
        index = 0
        selected = nil
        correct = 0
        combo = 0
        bestCombo = 0
        lives = Self.maxLives
        xpGained = 0
        missed = []
        isNewBest = false
        endTime = Date.now.addingTimeInterval(Self.timeLimit)
        phase = .playing
    }

    private func answer(_ i: Int) {
        guard phase == .playing, selected == nil else { return }
        let q = deck[index]
        selected = i
        let ok = i == q.answer
        combo = ok ? combo + 1 : 0
        bestCombo = max(bestCombo, combo)
        let gain = progress.recordAnswer(questionID: q.id, correct: ok, combo: combo,
                                         xpPerCorrect: mode == .timeAttack ? GameRules.timeAttackXP : GameRules.correctXP)
        xpGained += gain.total
        fx.show(gain, combo: combo)
        if ok {
            correct += 1
            correctTick += 1
        } else {
            wrongTick += 1
            missed.append(q)
            if mode == .survival { lives -= 1 }
        }

        // 正解（とタイムアタックの不正解）は少し見せてから自動で次へ
        if ok || mode == .timeAttack {
            Task {
                try? await Task.sleep(for: .seconds(ok ? 0.45 : 0.9))
                if phase == .playing, selected != nil { next() }
            }
        }
    }

    private func next() {
        if mode == .survival && lives <= 0 {
            finish()
            return
        }
        selected = nil
        index += 1
        if index >= deck.count {
            deck = QuizData.all.shuffled().map { $0.shuffled() }
            index = 0
        }
    }

    private func finish() {
        guard phase == .playing else { return }
        isNewBest = progress.recordGameScore(mode: mode.rawValue, score: correct)
        if isNewBest && correct > 0 { fx.celebrate() }
        phase = .finished
    }
}
