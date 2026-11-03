import SwiftUI
import UIKit

/// South Park 公式 YouTube チャンネルの新着動画。PC に保存を頼んで、字幕付きで取り込める
struct SouthParkListView: View {
    @Environment(EnglishStore.self) private var store
    @Environment(SpecRAGClient.self) private var pc

    @State private var videos: [YouTubeVideo] = []
    @State private var isLoading = false
    @State private var loadError: String?
    /// PC に保存を頼んでいる動画の ID → 進み具合と説明
    @State private var fetching: [String: (Double, String)] = [:]
    @State private var fetchError: String?
    /// 取り込みが終わった動画の ID
    @State private var imported: Set<String> = []

    var body: some View {
        List {
            Section {
                ForEach(videos) { video in
                    row(video)
                }
                if videos.isEmpty && isLoading {
                    ProgressView("読み込み中…")
                }
                if let loadError {
                    Text(loadError).foregroundStyle(.red)
                }
            } footer: {
                Text("公式チャンネルの新着動画です（PC につながるときは PC の yt-dlp で30本、つながらないときは YouTube の RSS で15本）。「PC で保存して取り込む」は、PC と同じ Wi-Fi のときに使えます。保存した動画は自分の学習用だけに使ってください。")
            }
        }
        .screenBackground()
        .navigationTitle("South Park 公式")
        .refreshable { await load() }
        .task { if videos.isEmpty { await load() } }
        .alert("取り込めませんでした", isPresented: Binding(get: { fetchError != nil },
                                                    set: { if !$0 { fetchError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(fetchError ?? "")
        }
    }

    private func row(_ video: YouTubeVideo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                AsyncImage(url: video.thumbnailURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(.tertiarySystemFill)
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title).font(.subheadline.weight(.semibold)).lineLimit(3)
                    if let published = video.published {
                        Text(published, format: .dateTime.year().month().day())
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if let (value, label) = fetching[video.id] {
                ProgressView(value: value) {
                    Text(label).font(.caption)
                }
            } else if imported.contains(video.id) {
                Label("取り込みました（配信で英語の一覧にあります）", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                HStack(spacing: 10) {
                    Button {
                        Task { await fetch(video) }
                    } label: {
                        Label("PC で保存して取り込む", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(AppButtonStyle(.primary))
                    .controlSize(.small)

                    Menu {
                        Link(destination: video.watchURL) {
                            Label("YouTube で見る", systemImage: "play.rectangle")
                        }
                        Button {
                            UIPasteboard.general.string = video.watchURL.absoluteString
                        } label: {
                            Label("リンクをコピー", systemImage: "link")
                        }
                        ShareLink(item: video.watchURL)
                    } label: {
                        Image(systemName: "ellipsis.circle").font(.title3)
                    }
                    .accessibilityLabel("ほかの操作")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            videos = try await YouTubeFeed.latestVideos(handle: YouTubeFeed.southParkHandle,
                                                        fallbackChannelID: YouTubeFeed.southParkFallbackID,
                                                        pcBase: pc.baseURL)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func fetch(_ video: YouTubeVideo) async {
        fetching[video.id] = (0, "PC に依頼中…")
        defer { fetching[video.id] = nil }
        do {
            let result = try await PCVideoFetcher.fetch(video.watchURL, base: pc.baseURL) { value, label in
                fetching[video.id] = (value, label)
            }
            let lines = result.subtitles.map(SubtitleParser.parse)
            _ = await store.addClip(copiedFile: result.videoFile, title: result.title,
                                    lines: (lines?.isEmpty ?? true) ? nil : lines)
            imported.insert(video.id)
        } catch {
            fetchError = error.localizedDescription
        }
    }
}
