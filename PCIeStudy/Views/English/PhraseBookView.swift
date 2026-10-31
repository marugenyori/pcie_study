import SwiftUI

/// 動画から保存したフレーズの一覧
struct PhraseBookView: View {
    @Environment(EnglishStore.self) private var store
    @State private var editing: SavedPhrase?
    @State private var memo = ""

    var body: some View {
        List {
            if store.phrases.isEmpty {
                Text("動画の英文を長押しして「フレーズ帳に保存」を選ぶと、ここにたまります。")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.phrases) { phrase in
                VStack(alignment: .leading, spacing: 6) {
                    Text(phrase.text).font(.body.weight(.medium))
                    if !phrase.memo.isEmpty {
                        Text(phrase.memo).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let clipID = phrase.clipID, let clip = store.clip(id: clipID) {
                        NavigationLink {
                            ClipPlayerView(clip: clip, startAt: phrase.start)
                        } label: {
                            Label("\(clip.title)（\(TimeText.format(phrase.start))）", systemImage: "play.circle")
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .leading) {
                    Button {
                        memo = phrase.memo
                        editing = phrase
                    } label: {
                        Label("メモ", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
            .onDelete { offsets in
                for id in offsets.map({ store.phrases[$0].id }) {
                    store.deletePhrase(id)
                }
            }
        }
        .screenBackground()
        .navigationTitle("フレーズ帳")
        .alert("意味・メモ", isPresented: Binding(get: { editing != nil },
                                              set: { if !$0 { editing = nil } })) {
            TextField("メモ", text: $memo)
            Button("保存") {
                if let editing { store.updateMemo(editing.id, memo: memo) }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }
}
