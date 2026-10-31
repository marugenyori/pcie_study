import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 写真アプリから受け取った動画（受け取った時点でアプリのフォルダにコピーする）
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let destination = EnglishStore.newFileURL(pathExtension: received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedMovie(url: destination)
        }
    }
}

/// 配信の録画で英語を学ぶ：動画の一覧と取り込み
struct EnglishHomeView: View {
    @Environment(EnglishStore.self) private var store
    @State private var pickedItem: PhotosPickerItem?
    @State private var showsFileImporter = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var renaming: EnglishClip?
    @State private var newTitle = ""

    var body: some View {
        List {
            Section {
                PhotosPicker(selection: $pickedItem, matching: .videos) {
                    Label("写真から動画を取り込む", systemImage: "photo.on.rectangle")
                }
                Button {
                    showsFileImporter = true
                } label: {
                    Label("ファイルから取り込む", systemImage: "folder")
                }
                if isImporting {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("取り込み中…").foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("iPhone の画面収録や、PC で録画して iCloud Drive・OneDrive などに入れた動画を使えます。録画は自分の学習用だけにし、共有やアップロードはしないでください。")
            }

            Section("動画") {
                if store.clips.isEmpty {
                    Text("まだ動画がありません")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.clips) { clip in
                    NavigationLink {
                        ClipPlayerView(clip: clip)
                    } label: {
                        ClipRow(clip: clip)
                    }
                    .contextMenu {
                        Button {
                            newTitle = clip.title
                            renaming = clip
                        } label: {
                            Label("名前を変える", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            store.delete(clip.id)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
                .onDelete { offsets in
                    for id in offsets.map({ store.clips[$0].id }) {
                        store.delete(id)
                    }
                }
            }

            Section {
                NavigationLink {
                    PhraseBookView()
                } label: {
                    ToolRow(symbol: "text.book.closed", title: "フレーズ帳",
                            detail: "保存したフレーズ \(store.phrases.count) 件")
                }
            }
        }
        .screenBackground()
        .navigationTitle("配信で英語")
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task { await importFromPhotos(item) }
        }
        .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.movie, .audio]) { result in
            Task { await importFromFiles(result) }
        }
        .alert("取り込めませんでした", isPresented: Binding(get: { importError != nil },
                                                    set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .alert("名前を変える", isPresented: Binding(get: { renaming != nil },
                                                 set: { if !$0 { renaming = nil } })) {
            TextField("名前", text: $newTitle)
            Button("変更") {
                if let renaming { store.rename(renaming.id, to: newTitle) }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func importFromPhotos(_ item: PhotosPickerItem) async {
        isImporting = true
        defer { isImporting = false }
        do {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                importError = "動画を読み込めませんでした。"
                return
            }
            _ = await store.addClip(copiedFile: movie.url)
        } catch {
            importError = error.localizedDescription
        }
    }

    private func importFromFiles(_ result: Result<URL, Error>) async {
        isImporting = true
        defer { isImporting = false }
        do {
            let source = try result.get()
            let accessing = source.startAccessingSecurityScopedResource()
            defer { if accessing { source.stopAccessingSecurityScopedResource() } }
            let destination = EnglishStore.newFileURL(pathExtension: source.pathExtension)
            try FileManager.default.copyItem(at: source, to: destination)
            _ = await store.addClip(copiedFile: destination, title: source.deletingPathExtension().lastPathComponent)
        } catch {
            importError = error.localizedDescription
        }
    }
}

private struct ClipRow: View {
    let clip: EnglishClip

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: clip.lines == nil ? "film" : "captions.bubble")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(clip.title).font(.body.weight(.medium)).lineLimit(1)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var detail: String {
        let length = TimeText.format(clip.duration)
        if let lines = clip.lines {
            return "\(length)・\(lines.count) 文"
        }
        return "\(length)・まだ文字起こししていません"
    }
}

enum TimeText {
    /// 秒を「1:05」の形にする
    static func format(_ seconds: Double) -> String {
        let total = Int(max(seconds, 0).rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
