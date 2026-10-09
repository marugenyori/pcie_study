import SwiftUI

/// PC の仕様書QA（RAG）に質問する画面
struct AskSpecView: View {
    var initialQuestion: String = ""

    @Environment(SpecRAGClient.self) private var client
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var status: ConnectionStatus = .checking
    @State private var streamTask: Task<Void, Never>?
    @State private var showsSettings = false
    @FocusState private var inputFocused: Bool

    struct ChatMessage: Identifiable {
        let id = UUID()
        let question: String
        var model: String?
        var answer = ""
        var sources: [SpecRAGClient.Source] = []
        var statusText: String? = "送信しています…"
        var error: String?
        var finished = false
    }

    enum ConnectionStatus: Equatable {
        case checking, ready(String), notConfigured, failed(String)
    }

    private var isStreaming: Bool { streamTask != nil }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusBanner
                    if messages.isEmpty {
                        introCard
                    }
                    ForEach(messages) { message in
                        messageView(message)
                            .id(message.id)
                    }
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: messages.last?.answer) {
                if let id = messages.last?.id {
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { inputBar }
        .screenBackground()
        .navigationTitle("仕様書に質問")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("接続の設定")
            }
        }
        .sheet(isPresented: $showsSettings, onDismiss: { Task { await checkHealth() } }) {
            SpecRAGSettingsView()
        }
        .task {
            if input.isEmpty && messages.isEmpty { input = initialQuestion }
            await checkHealth()
        }
        .onDisappear {
            streamTask?.cancel()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - 接続状態

    @ViewBuilder
    private var statusBanner: some View {
        switch status {
        case .checking:
            Label("PCのサーバに接続しています…", systemImage: "antenna.radiowaves.left.and.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .ready(let text):
            Label(text, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .notConfigured:
            bannerCard("PCのサーバのアドレスが未設定です", detail: "右上の歯車から、PCで start_lan.bat を起動したときに表示されるアドレスを入力してください。")
        case .failed(let message):
            bannerCard("PCのサーバに接続できません", detail: message)
        }
    }

    private func bannerCard(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.orange)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("設定を開く") { showsSettings = true }
                Button("もう一度試す") { Task { await checkHealth() } }
            }
            .font(.caption.bold())
            .buttonStyle(.borderless)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 14)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("PCIe 仕様書に質問できます", systemImage: "book.and.wrench")
                .font(.headline)
            Text("PCにある仕様書（Base 7.1）から関係する箇所を探し、ローカルのAIが根拠の番号付きで日本語で答えます。質問も仕様書も、自宅のネットワークの外には出ません。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("例：「Polling.Active から Polling.Configuration に進む条件は？」")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .cardStyle(cornerRadius: 16)
    }

    // MARK: - メッセージ

    private func messageView(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer(minLength: 40)
                Text(message.question)
                    .padding(12)
                    .foregroundStyle(.white)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.tint))
            }

            VStack(alignment: .leading, spacing: 10) {
                if let status = message.statusText, !message.finished {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(status).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !message.answer.isEmpty {
                    Text(markdown: message.answer)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                if let error = message.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !message.sources.isEmpty {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(message.sources) { source in
                                sourceRow(source)
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        Label("根拠にした仕様書の箇所（\(message.sources.count)件）", systemImage: "book.closed")
                            .font(.caption.bold())
                    }
                }
                if let model = message.model, !message.answer.isEmpty {
                    Label("回答AI：\(model)", systemImage: "cpu")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if message.finished && message.error == nil {
                    Text("ローカルのAIは誤ることがあります。数値やビット位置は、根拠の原文やPDFで確認してください。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(cornerRadius: 16)
        }
    }

    private func sourceRow(_ source: SpecRAGClient.Source) -> some View {
        DisclosureGroup {
            Text(source.text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .padding(.top, 4)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("[\(source.n)] \(source.label)")
                    .font(.caption.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(source.doc)・p.\(source.page)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 入力欄

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !client.models.isEmpty {
                modelPicker
            }
            inputRow
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    /// 回答に使うモデルを選ぶ（PC の Ollama に入っているもの）
    private var modelPicker: some View {
        Menu {
            Picker("回答AI", selection: Binding(
                get: { client.effectiveModel ?? "" },
                set: { client.selectModel($0) }
            )) {
                ForEach(client.models, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
        } label: {
            Label("回答AI：\(client.effectiveModel ?? "サーバの既定")", systemImage: "cpu")
                .font(.caption.bold())
        }
        .disabled(isStreaming)
    }

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("質問を入力（日本語でOK）", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .focused($inputFocused)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            if isStreaming {
                Button {
                    streamTask?.cancel()
                } label: {
                    Image(systemName: "stop.circle.fill").font(.title)
                }
                .accessibilityLabel("止める")
            } else {
                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !client.isConfigured)
                .accessibilityLabel("送信")
            }
        }
    }

    // MARK: - ロジック

    private func checkHealth() async {
        guard client.isConfigured else {
            status = .notConfigured
            return
        }
        status = .checking
        do {
            let health = try await client.health()
            if !health.ok {
                status = .failed("仕様書のインデックスが読み込まれていません。PCで ingest.bat を実行してください。\(health.error.map { "（\($0)）" } ?? "")")
            } else if !health.ollama {
                status = .failed("PCで Ollama が起動していません。スタートメニューから Ollama を起動してください。")
            } else if !health.chat_model_ready {
                status = .failed("回答用のモデル（\(health.chat_model)）がまだダウンロードされていません。")
            } else {
                status = .ready("接続OK：仕様書 \(health.chunks) 件の抜粋から検索します（\(health.dense ? "意味検索あり" : "キーワード検索のみ")）")
                await client.loadModels()
            }
        } catch {
            status = .failed("同じWi‑Fiにつながっているか、PCで start_lan.bat が動いているか確認してください。（\(error.localizedDescription)）")
        }
    }

    private func send() {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        input = ""
        inputFocused = false
        let history = messages.filter { $0.finished && $0.error == nil }.map { (q: $0.question, a: $0.answer) }
        let model = client.effectiveModel
        messages.append(ChatMessage(question: question, model: model))
        let index = messages.count - 1
        // 回答を待っている間に画面が消えると通信が切れるので、自動ロックを止めておく
        UIApplication.shared.isIdleTimerDisabled = true

        streamTask = Task {
            do {
                for try await event in client.ask(question, history: history, model: model) {
                    switch event {
                    case .status(let text): messages[index].statusText = text
                    case .sources(let sources): messages[index].sources = sources
                    case .token(let piece):
                        messages[index].statusText = nil
                        messages[index].answer += piece
                    case .done: messages[index].finished = true
                    case .failure(let message):
                        messages[index].error = message
                        messages[index].finished = true
                    }
                }
            } catch is CancellationError {
                messages[index].error = "止めました"
            } catch {
                if Task.isCancelled {
                    messages[index].error = "止めました"
                } else {
                    messages[index].error = "通信エラー：\(error.localizedDescription)"
                }
            }
            messages[index].finished = true
            streamTask = nil
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}

/// 接続先の設定
struct SpecRAGSettingsView: View {
    @Environment(SpecRAGClient.self) private var client
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var testResult: String?
    @State private var testing = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例：192.168.1.10:8765", text: $address)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task { await test() }
                    } label: {
                        if testing {
                            ProgressView()
                        } else {
                            Text("接続テスト")
                        }
                    }
                    .disabled(address.isEmpty || testing)
                    if let testResult {
                        Text(testResult)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    Text("PCのサーバのアドレス")
                } footer: {
                    Text("ポート番号を省略すると 8765 になります。")
                }

                Section("PC側の準備") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. PCで Ollama を起動する")
                        Text("2. PCIe_RAG フォルダの start_lan.bat をダブルクリック")
                        Text("3. 黒いウィンドウに出る http://192.168.x.x:8765 を上に入力")
                        Text("4. iPhone を PC と同じ Wi‑Fi につなぐ")
                    }
                    .font(.callout)
                    Text("初めてつなぐとき、iPhone に「ローカルネットワーク上のデバイスの検索」の許可が表示されたら「許可」を選んでください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("仕様書QAの接続")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        client.setServerAddress(address)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onAppear { address = client.serverAddress }
        }
    }

    private func test() async {
        testing = true
        defer { testing = false }
        let previous = client.serverAddress
        client.setServerAddress(address)
        do {
            let health = try await client.health()
            testResult = health.ok
                ? "✅ つながりました（抜粋 \(health.chunks) 件、Ollama：\(health.ollama ? "起動中" : "未起動")）"
                : "⚠️ サーバにはつながりましたが、インデックスがありません（\(health.error ?? "")）"
        } catch {
            testResult = "❌ つながりません：\(error.localizedDescription)"
            client.setServerAddress(previous)
        }
    }
}
