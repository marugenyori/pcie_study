import Foundation

/// 字幕ファイル（.srt / .vtt）を文字起こしの行に変える
///
/// YouTube の自動字幕は、1つの字幕に「前の行＋新しい行」が入って流れていく形なので、
/// 直前に出した行と同じ行は飛ばして、重ならないようにする。
enum SubtitleParser {
    static func parse(_ text: String) -> [TranscriptLine] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var lines: [TranscriptLine] = []
        var recent: [String] = []

        for block in normalized.components(separatedBy: "\n\n") {
            let rows = block.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            guard let timeIndex = rows.firstIndex(where: { $0.contains("-->") }),
                  let (start, end) = times(rows[timeIndex]) else { continue }
            for row in rows[(timeIndex + 1)...] {
                let cleaned = clean(row)
                guard !cleaned.isEmpty, !recent.contains(cleaned) else { continue }
                lines.append(TranscriptLine(start: start, end: max(end, start), text: cleaned))
                recent.append(cleaned)
                if recent.count > 3 { recent.removeFirst() }
            }
        }
        return lines
    }

    /// 「00:01:02,500 --> 00:01:04,000」（.vtt は「.」区切り、時が省略されることもある）
    private static func times(_ row: String) -> (Double, Double)? {
        let parts = row.components(separatedBy: "-->")
        guard parts.count == 2,
              let start = seconds(parts[0]),
              let end = seconds(parts[1].split(separator: " ", omittingEmptySubsequences: true).first.map(String.init) ?? "")
        else { return nil }
        return (start, end)
    }

    private static func seconds(_ text: String) -> Double? {
        let fields = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".").split(separator: ":")
        guard (2...3).contains(fields.count) else { return nil }
        var total = 0.0
        for field in fields {
            guard let value = Double(field) else { return nil }
            total = total * 60 + value
        }
        return total
    }

    /// <i> などのタグや [Music] のような説明、♪ を取り除く
    private static func clean(_ row: String) -> String {
        var text = row.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "\\[[^\\]]*\\]", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "♪", with: "")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
