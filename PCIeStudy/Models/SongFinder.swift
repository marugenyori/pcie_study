import AVFoundation
import Foundation
import ShazamKit

/// 動画の中で流れている曲を ShazamKit で調べる
///
/// 20秒ごとに10秒ずつ切り出して照合し、同じ曲が続くときは最初の時刻だけ残す。
/// ShazamKit は 12 秒より長い音声を受け付けないので、10 秒にしている。
/// 音声は AVAssetReader で 44.1kHz・モノラルの PCM に変えてから署名（照合用の指紋）を作る。
/// 使うには、Apple Developer の App ID（アプリ本体）で ShazamKit を有効にしておく必要がある。
enum SongFinder {
    private static let step = 20.0
    private static let window = 10.0
    private static let sampleRate = 44_100.0

    enum Failure: LocalizedError {
        case noAudio
        case signature(Error)
        case match(Error)

        var errorDescription: String? {
            switch self {
            case .noAudio:
                return "この動画には音声が入っていません。"
            case .signature(let error):
                return "音声から照合用のデータを作れませんでした（\(describe(error))）"
            case .match(let error):
                return "Shazam での照合に失敗しました（\(describe(error))）。Apple Developer で ShazamKit を有効にした直後は、しばらく時間をおいてから試してください。"
            }
        }

        private func describe(_ error: Error) -> String {
            let ns = error as NSError
            return "\(ns.domain) \(ns.code)"
        }
    }

    static func findSongs(fileURL: URL, progress: @escaping @MainActor (Double) -> Void) async throws -> [SongMatch] {
        let asset = AVURLAsset(url: fileURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else { throw Failure.noAudio }
        let duration = try await asset.load(.duration).seconds

        let session = SHSession()
        var songs: [SongMatch] = []
        var firstError: Failure?
        var start = 0.0
        while start < duration - 3 {
            try Task.checkCancellation()
            let length = min(window, duration - start)
            do {
                let signature = try signature(of: asset, track: audioTrack, start: start, length: length)
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
                    firstError = firstError ?? .match(error)
                @unknown default:
                    break
                }
            } catch {
                firstError = firstError ?? .signature(error)
            }
            start += step
            await progress(min(start / max(duration, 1), 1))
        }

        // 1曲も見つからず、照合そのものが失敗していたときはエラーにする（ShazamKit が未設定など）
        if songs.isEmpty, let firstError {
            throw firstError
        }
        return songs
    }

    /// 音声トラックの一部を 44.1kHz・モノラルの PCM で読み出して、照合用の署名を作る
    private static func signature(of asset: AVAsset, track: AVAssetTrack, start: Double, length: Double) throws -> SHSignature {
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                       duration: CMTime(seconds: length, preferredTimescale: 600))
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ])
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? Failure.noAudio }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            throw Failure.noAudio
        }
        let generator = SHSignatureGenerator()
        while let sampleBuffer = output.copyNextSampleBuffer() {
            let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
            guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { continue }
            buffer.frameLength = frames
            let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, at: 0, frameCount: Int32(frames),
                                                                      into: buffer.mutableAudioBufferList)
            guard status == noErr else { continue }
            try generator.append(buffer, at: nil)
        }
        if reader.status == .failed { throw reader.error ?? Failure.noAudio }
        return generator.signature()
    }
}
