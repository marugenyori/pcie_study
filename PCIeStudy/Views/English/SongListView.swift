import SwiftUI

/// 動画の中で流れていた曲の一覧
struct SongListView: View {
    let clipID: UUID
    /// 時刻をタップしたときに、動画をその位置から再生する
    let onSeek: (Double) -> Void

    @Environment(EnglishStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var progress = 0.0
    @State private var errorMessage: String?

    private var clip: EnglishClip? { store.clip(id: clipID) }

    var body: some View {
        NavigationStack {
            List {
                if let songs = clip?.songs, !isWorking {
                    if songs.isEmpty {
                        Text("曲は見つかりませんでした。話し声が大きい場面や、Shazam に登録されていない曲はわからないことがあります。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(songs) { song in
                        songRow(song)
                    }
                } else {
                    Section {
                        if isWorking {
                            ProgressView(value: progress) {
                                Text("曲を調べています… \(Int(progress * 100))%").font(.caption)
                            }
                        } else {
                            Text("動画の音声を Shazam で照合して、流れている曲の名前を調べます。20秒ごとに調べるので、10分の動画で1分ほどかかります。")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }

                Section {
                    Button {
                        Task { await find() }
                    } label: {
                        Text(clip?.songs == nil ? "曲を調べる" : "もう一度調べる").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppButtonStyle(clip?.songs == nil ? .primary : .secondary))
                    .disabled(isWorking)
                    .listRowBackground(Color.clear)
                }
            }
            .screenBackground()
            .navigationTitle("流れている曲")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func songRow(_ song: SongMatch) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                AsyncImage(url: song.artworkURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 56, height: 56)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title).font(.body.weight(.semibold))
                    Text(song.artist).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    onSeek(song.start)
                    dismiss()
                } label: {
                    Label(TimeText.format(song.start), systemImage: "play.fill")
                }
                .buttonStyle(AppButtonStyle(.secondary))
                .controlSize(.small)
            }
            HStack(spacing: 16) {
                if let url = song.appleMusicURL ?? song.webURL {
                    Link(destination: url) {
                        Label("Apple Music", systemImage: "music.note")
                    }
                }
                if let url = lyricsSearchURL(song) {
                    Link(destination: url) {
                        Label("歌詞を検索", systemImage: "magnifyingglass")
                    }
                }
            }
            .font(.subheadline)
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    /// ShazamKit は歌詞を返さないので、曲名とアーティストで Web 検索する
    private func lyricsSearchURL(_ song: SongMatch) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: "\(song.title) \(song.artist) lyrics")]
        return components?.url
    }

    private func find() async {
        guard let clip else { return }
        isWorking = true
        progress = 0
        errorMessage = nil
        defer { isWorking = false }
        do {
            let songs = try await SongFinder.findSongs(fileURL: EnglishStore.fileURL(for: clip)) { value in
                progress = value
            }
            store.setSongs(songs, for: clip.id)
        } catch {
            errorMessage = "曲を調べられませんでした：\(error.localizedDescription)"
        }
    }
}
