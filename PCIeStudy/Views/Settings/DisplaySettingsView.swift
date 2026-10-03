import SwiftUI

/// 文字の大きさ・テーマ色・外観の設定
struct DisplaySettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section {
                    preview
                } header: {
                    Text("プレビュー")
                }

                Section {
                    Picker("文字の大きさ", selection: $settings.textSize) {
                        ForEach(AppSettings.TextSize.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("文字の大きさ")
                } footer: {
                    Text("「iPhoneの設定に合わせる」は、設定アプリ →「画面表示と明るさ」→「テキストサイズを変更」に従います。")
                }

                Section("テーマの色") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 12)], spacing: 12) {
                        ForEach(AppSettings.Theme.allCases) { theme in
                            Button {
                                settings.theme = theme
                            } label: {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(theme.color)
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            if settings.theme == theme {
                                                Image(systemName: "checkmark")
                                                    .font(.headline.bold())
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .overlay(Circle().stroke(Color.primary.opacity(settings.theme == theme ? 0.5 : 0), lineWidth: 2).padding(-4))
                                    Text(theme.label)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(theme.label)
                            .accessibilityAddTraits(settings.theme == theme ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("外観") {
                    Picker("外観", selection: $settings.appearance) {
                        ForEach(AppSettings.Appearance.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    Toggle("解説の行間を広くする", isOn: $settings.wideLineSpacing)
                } footer: {
                    Text("章の解説とコラムの文章が読みやすくなります。")
                }
            }
            .navigationTitle("表示設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
        // シートの中でもすぐに反映されるようにする
        .applyAppSettings(settings)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TLP（トランザクション層パケット）")
                .font(.headline)
            Text("PCIe のデータは **TLP** というパケットで運ばれます。ヘッダには種類やアドレスが入っています。")
                .lineSpacing(settings.lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("ボタンの色")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("クイズを始める") {}
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

/// 各タブのツールバーに置く「表示設定」ボタン
struct DisplaySettingsButton: View {
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "textformat.size")
        }
        .accessibilityLabel("表示設定")
        .sheet(isPresented: $isPresented) {
            DisplaySettingsView()
        }
    }
}
