import SwiftUI

struct LTSSMDiagramView: View {
    @State private var current = LTSSMModel.initial
    @State private var history: [String] = [LTSSMModel.initial]
    @State private var scenarioStep: Int? = nil
    @State private var isPlaying = false
    @State private var playTask: Task<Void, Never>? = nil

    private var state: LTSSMState { LTSSMModel.states[current]! }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                groupMap
                stateCard
                if let step = scenarioStep, let note = LTSSMModel.scenarioNote(step: step) {
                    Label(note, systemImage: "info.circle.fill")
                        .font(.callout.bold())
                        .foregroundStyle(.blue)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
                scenarioControls
                transitionsList
                historyView
            }
            .padding()
            .animation(.easeInOut(duration: 0.25), value: current)
        }
        .screenBackground()
        .navigationTitle("LTSSM")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { playTask?.cancel() }
    }

    // MARK: - 上位状態のマップ

    private var groupMap: some View {
        let columns = [GridItem(.adaptive(minimum: 92), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(LTSSMGroup.allCases) { group in
                Text(group.rawValue)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(group == state.group ? color(group) : color(group).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(group == state.group ? .white : .primary)
            }
        }
    }

    private func color(_ group: LTSSMGroup) -> Color {
        switch group {
        case .detect: return .gray
        case .polling: return .blue
        case .configuration: return .indigo
        case .l0: return .green
        case .recovery: return .orange
        case .l0s, .l1, .l2: return .teal
        case .disabled, .loopback, .hotReset: return .red
        }
    }

    // MARK: - 現在の状態

    private var stateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("現在の状態").font(.caption).foregroundStyle(.secondary)
            Text(current)
                .font(.title2.bold().monospaced())
                .foregroundStyle(color(state.group))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(state.description)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color(state.group).opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        .id(current)
    }

    // MARK: - シナリオ再生

    private var scenarioControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("リンクアップを再生").font(.headline)
            Text("Gen1でリンクアップしてから、Recoveryを経てGen3以上に速度を上げるまでの典型的な流れです。")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button {
                    isPlaying ? stopPlaying() : play()
                } label: {
                    Label(isPlaying ? "停止" : "自動再生", systemImage: isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(AppButtonStyle(.primary))

                Button {
                    stepScenario()
                } label: {
                    Label("1ステップ", systemImage: "forward.frame")
                }
                .buttonStyle(AppButtonStyle(.secondary))
                .disabled(isPlaying)

                Spacer()

                Button("リセット") { reset() }
                    .buttonStyle(AppButtonStyle(.secondary))
            }
            if let step = scenarioStep {
                ProgressView(value: Double(step), total: Double(LTSSMModel.linkUpScenario.count - 1))
            }
        }
    }

    private func play() {
        if scenarioStep == nil || scenarioStep == LTSSMModel.linkUpScenario.count - 1 {
            reset()
            scenarioStep = 0
        }
        isPlaying = true
        playTask = Task { @MainActor in
            while isPlaying, let step = scenarioStep, step < LTSSMModel.linkUpScenario.count - 1 {
                try? await Task.sleep(for: .milliseconds(1100))
                guard !Task.isCancelled, isPlaying else { break }
                stepScenario()
            }
            isPlaying = false
        }
    }

    private func stopPlaying() {
        isPlaying = false
        playTask?.cancel()
    }

    private func stepScenario() {
        let path = LTSSMModel.linkUpScenario
        guard let step = scenarioStep else {
            reset()
            scenarioStep = 0
            return
        }
        guard step + 1 < path.count else { return }
        scenarioStep = step + 1
        moveTo(path[step + 1])
    }

    private func reset() {
        current = LTSSMModel.initial
        history = [LTSSMModel.initial]
        scenarioStep = nil
    }

    private func moveTo(_ id: String) {
        current = id
        history.append(id)
    }

    // MARK: - 手動遷移

    private var transitionsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("手動で遷移する").font(.headline)
            Text("条件を選んで次の状態へ進めます。")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(state.transitions, id: \.self) { t in
                Button {
                    stopPlaying()
                    scenarioStep = nil
                    moveTo(t.to)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(color(LTSSMModel.states[t.to]?.group ?? .detect))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.to).font(.subheadline.monospaced().bold())
                            Text(t.condition)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .cardStyle(cornerRadius: 10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("遷移の履歴").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(history.enumerated()), id: \.offset) { i, id in
                        if i > 0 {
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(id)
                            .font(.caption2.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(color(LTSSMModel.states[id]?.group ?? .detect).opacity(0.15),
                                        in: Capsule())
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { LTSSMDiagramView() }
}
