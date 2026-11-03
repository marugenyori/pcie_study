// アプリの学習データ（章・クイズ・英語レッスン・用語集・コラム）を、ブラウザ版用の JSON に書き出す
//
// GitHub Actions（.github/workflows/export-content.yml）で、アプリのデータのファイルと一緒にコンパイルして動かす。
// 使い方: export <出力先の JSON>
import Foundation

func blocks(_ list: [ContentBlock]) -> [[String: Any]] {
    list.map { block in
        switch block {
        case .heading(let text): return ["type": "heading", "text": text]
        case .text(let text): return ["type": "text", "text": text]
        case .bullets(let items): return ["type": "bullets", "items": items]
        case .table(let header, let rows): return ["type": "table", "header": header, "rows": rows]
        case .note(let text): return ["type": "note", "text": text]
        case .figure(let text): return ["type": "figure", "text": text]
        }
    }
}

let chapters: [[String: Any]] = LessonData.all.map { c in
    var item: [String: Any] = [
        "id": c.id, "number": c.number, "title": c.title, "summary": c.summary,
        "level": c.level.rawValue, "blocks": blocks(c.blocks),
    ]
    if let diagram = c.diagram { item["diagram"] = diagram.rawValue }
    return item
}

let questions: [[String: Any]] = QuizData.all.map { q in
    var item: [String: Any] = [
        "id": q.id, "chapterID": q.chapterID, "question": q.question,
        "choices": q.choices, "answer": q.answer, "explanation": q.explanation,
        "choiceNotes": q.choiceNotes,
    ]
    if let spec = q.spec { item["spec"] = ["section": spec.section, "title": spec.title, "page": spec.page] }
    if let detail = q.detail { item["detail"] = detail }
    return item
}

let english: [[String: Any]] = EnglishData.all.map { l in
    [
        "id": l.id, "title": l.title, "titleJa": l.titleJa, "chapterID": l.chapterID, "level": l.level.rawValue,
        "sentences": l.sentences.map { s -> [String: Any] in
            var item: [String: Any] = ["en": s.en, "ja": s.ja, "spoken": EnglishSpeech.spoken(s.en)]
            if let key = s.key { item["key"] = key }
            return item
        },
        "words": l.words.map { ["word": $0.word, "ja": $0.ja, "tip": $0.tip] },
        "questions": l.questions.map { ["question": $0.question, "choices": $0.choices, "answer": $0.answer, "note": $0.note] },
    ]
}

let terms: [[String: Any]] = EnglishData.terms.map {
    ["written": $0.written, "reading": $0.reading, "speech": $0.speech, "tip": $0.tip]
}

let glossary: [[String: Any]] = GlossaryData.all.map {
    ["term": $0.term, "fullName": $0.fullName, "category": $0.category.rawValue, "description": $0.description]
}

let columns: [[String: Any]] = ColumnData.all.map { c in
    var item: [String: Any] = [
        "id": c.id, "title": c.title, "lead": c.lead, "minutes": c.minutes, "blocks": blocks(c.blocks),
    ]
    if let chapterID = c.chapterID { item["chapterID"] = chapterID }
    return item
}

let content: [String: Any] = [
    "chapters": chapters,
    "questions": questions,
    "english": english,
    "spokenTerms": terms,
    "glossary": glossary,
    "columns": columns,
]

let data = try JSONSerialization.data(withJSONObject: content, options: [.prettyPrinted, .sortedKeys])
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "content.json"
try data.write(to: URL(fileURLWithPath: output))
print("書き出しました: \(output)（章 \(chapters.count)、問題 \(questions.count)、英語レッスン \(english.count)）")
