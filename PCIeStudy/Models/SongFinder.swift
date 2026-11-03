import AVFoundation
import Foundation
import ShazamKit

/// 動画の中で流れている曲を ShazamKit で調べる
///
/// 20秒ごとに12秒ずつ切り出して照合し、同じ曲が続くときは最初の時刻だけ残す。
/// 使うには、Apple Developer の App ID（アプリ本体）で ShazamKit を有効にしておく必要がある。
enum SongFinder {
    private static let step = 20.0
    private static let window = 12.0

    enum Failure: LocalizedError {
        case noAudio

        var errorDescription: String? {
            switch self {
            case .noAudio: return "この動画には音声が入っていません。"
            }
        }
    }

    static func findSongs(fileURL: URL, progress: @escaping @MainActor (Double) -> Void) async throws -> [SongMatch] {
        let asset = AVURLAsset(url: fileURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else { throw Failure.noAudio }
        let duration = try await asset.load(.duration).seconds

        let session = SHSession()
        var songs: [SongMatch] = []
        var lastError: Error?
        var start = 0.0
        while start < duration - 3 {
            try Task.checkCancellation()
            let length = min(window, duration - start)
            do {
                let signature = try await signature(of: audioTrack, start: start, length: length)
                switch await session.result(from: signature) {
                case .match(let match):
                    if let item = match.mediaItems.first, let title = item.title {
                        let artist = item.artist ?? ""
                        // 前と同じ曲なら、続きとみなして足さない
                        if songs.last?.title != title || songs.last?.artist != artist {
                            songs.append(SongMatch(start: start, title: title, artist: artist,
                                                   artworkURL: item.artworkURL,
                                                   appleMusicURL: item.appleMusicURL,
                                                   webURL: item.webURL))
                        }
                    }
                case .noMatch:
                    break
                case .error(let error, _):
                    lastError = error
                @unknown default:
                    break
                }
            } catch {
                lastError = error
            }
            start += step
            await progress(min(start / max(duration, 1), 1))
        }

        // 1曲も見つからず、照合そのものが失敗していたときはエラーにする（ShazamKit が未設定など）
        if songs.isEmpty, let lastError {
            throw lastError
        }
        return songs
    }

    /// 音声トラックの一部だけを取り出して、照合用の署名を作る
    private static func signature(of track: AVAssetTrack, start: Double, length: Double) async throws -> SHSignature {
        let composition = AVMutableComposition()
        guard let audio = composition.addMutableTrack(withMediaType: .audio,
                                                      preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Failure.noAudio
        }
        let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                duration: CMTime(seconds: length, preferredTimescale: 600))
        try audio.insertTimeRange(range, of: track, at: .zero)
        return try await SHSignatureGenerator.signature(from: composition)
    }
}
