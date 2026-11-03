import SwiftUI

// MARK: - スライドの部品

/// 図の箱。on のときはテーマ色で強調し、それ以外は薄くする
private struct SlideBox: View {
    let text: String
    var detail: String? = nil
    let on: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        VStack(spacing: 2) {
            Text(text)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(shape.fill(on ? AnyShapeStyle(.tint.opacity(0.22)) : AnyShapeStyle(Color(.tertiarySystemFill))))
        .overlay(shape.strokeBorder(on ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.clear), lineWidth: 2))
        .opacity(on ? 1 : 0.5)
    }
}

/// 矢印（SF Symbols）と、その横の短い説明
private struct SlideArrow: View {
    let symbol: String
    var label: String? = nil
    let on: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            if let label { Text(label).font(.caption2.weight(.semibold)) }
        }
        .font(.body.weight(.bold))
        .foregroundStyle(on ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.secondary.opacity(0.4)))
    }
}

/// 図の下に出す、ひとことの説明
private struct SlideNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(.tint.opacity(0.12)))
    }
}

// MARK: - レッスンごとの図

/// レッスンの index 番目の文に合わせた図
struct EnglishSlide: View {
    let lessonID: String
    let index: Int

    var body: some View {
        VStack(spacing: 12) {
            switch lessonID {
            case "en-layers": LayersSlide(index: index)
            case "en-topology": TopologySlide(index: index)
            case "en-tlp": TLPSlide(index: index)
            case "en-replay": ReplaySlide(index: index)
            case "en-credits": CreditsSlide(index: index)
            case "en-lanes": LanesSlide(index: index)
            case "en-ltssm": LTSSMSlide(index: index)
            case "en-config": ConfigSlide(index: index)
            case "en-msi": MSISlide(index: index)
            case "en-gen6": Gen6Slide(index: index)
            default:
                if let slide = SimpleSlides.slide(lessonID: lessonID, index: index) {
                    SimpleSlideView(slide: slide)
                } else {
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .animation(.easeInOut(duration: 0.3), value: index)
    }
}

/// 3つの層（送る側と受ける側）
private struct LayersSlide: View {
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            side("送る側", arrow: "arrow.down", receiving: false)
            VStack {
                Spacer()
                SlideArrow(symbol: "arrow.right", label: "レーン", on: index == 4 || index == 0)
                Spacer()
            }
            .frame(width: 56)
            side("受ける側", arrow: "arrow.up", receiving: true)
        }
        .frame(height: 210)
        switch index {
        case 1: SlideNote(text: "読み書きの依頼 → TLP（パケット）")
        case 2: SlideNote(text: "Seq番号 ＋ TLP ＋ LCRC")
        case 3: SlideNote(text: "壊れていたら自動で送り直す")
        case 4: SlideNote(text: "電気信号にしてレーンで送る")
        case 5: SlideNote(text: "受ける側は下から上へ")
        default: SlideNote(text: "PCIe は3つの層でできている")
        }
    }

    private func side(_ title: String, arrow: String, receiving: Bool) -> some View {
        let all = index == 0
        let rx = index == 5 && receiving
        return VStack(spacing: 6) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            SlideBox(text: "Transaction", detail: "TLP を作る", on: all || rx || (index == 1 && !receiving))
            SlideArrow(symbol: arrow, on: all || rx)
            SlideBox(text: "Data Link", detail: index == 3 ? "↻ 再送" : "Seq / LCRC",
                     on: all || rx || ((index == 2 || index == 3) && !receiving))
            SlideArrow(symbol: arrow, on: all || rx)
            SlideBox(text: "Physical", detail: "電気信号", on: all || rx || (index == 4 && !receiving))
        }
    }
}

/// PCIe の木構造
private struct TopologySlide: View {
    let index: Int

    var body: some View {
        VStack(spacing: 6) {
            SlideBox(text: "CPU ・ メモリ", on: index == 0 || index == 1)
            SlideArrow(symbol: "arrow.down", on: index == 0 || index == 1)
            SlideBox(text: "Root Complex", detail: "木の根", on: index == 0 || index == 1)
            SlideArrow(symbol: "arrow.down", label: index == 4 ? "リンク（2つのポートをつなぐ）" : nil,
                       on: index == 0 || index == 4)
            SlideBox(text: "Switch", detail: index == 3 ? "上り1つ ・ 下り複数" : nil, on: index == 0 || index == 3)
            HStack(spacing: 30) {
                SlideArrow(symbol: "arrow.down.left", on: index == 0 || index == 3 || index == 5)
                SlideArrow(symbol: "arrow.down.right", on: index == 0 || index == 3 || index == 5)
            }
            HStack(spacing: 10) {
                SlideBox(text: "Endpoint", detail: "SSD", on: index == 0 || index == 2)
                SlideBox(text: "Endpoint", detail: "ネットワークカード", on: index == 0 || index == 2)
            }
        }
        switch index {
        case 1: SlideNote(text: "Root Complex が CPU とメモリをつなぐ")
        case 2: SlideNote(text: "SSD などの機器 ＝ Endpoint")
        case 3: SlideNote(text: "Switch で機器を増やせる")
        case 4: SlideNote(text: "1本のリンク ＝ 両端に1つずつのポート")
        case 5: SlideNote(text: "PCI と違い、線を共有しない（1対1）")
        default: SlideNote(text: "PCIe は木の形")
        }
    }
}

/// TLP のなかみと、リクエスト・完了
private struct TLPSlide: View {
    let index: Int

    var body: some View {
        HStack(spacing: 4) {
            SlideBox(text: "Header", detail: index == 1 ? "3〜4 DW" : (index == 5 ? "Requester ID ・ Tag" : nil),
                     on: [0, 1, 5].contains(index))
            SlideBox(text: "Data", detail: "なくてもよい", on: index == 0 || index == 3)
            SlideBox(text: "ECRC", detail: "なくてもよい", on: index == 0)
        }
        HStack(spacing: 8) {
            SlideBox(text: "Requester", detail: "依頼する側", on: index >= 2)
            VStack(spacing: 6) {
                SlideArrow(symbol: "arrow.right", label: index == 2 ? "Memory Write" : "Memory Read", on: index >= 2)
                switch index {
                case 3, 5: SlideArrow(symbol: "arrow.left", label: "Completion", on: true)
                case 4: SlideArrow(symbol: "clock.badge.exclamationmark", label: "返事が来ない", on: true)
                default: SlideArrow(symbol: "arrow.left", label: "返事なし", on: index == 2)
                }
            }
            .frame(minWidth: 120)
            SlideBox(text: "Completer", detail: "答える側", on: index >= 2)
        }
        switch index {
        case 1: SlideNote(text: "1 DW（ダブルワード）＝ 4 バイト")
        case 2: SlideNote(text: "書き込みは posted：返事を待たない")
        case 3: SlideNote(text: "読み出しは non-posted：データ付きの Completion が返る")
        case 4: SlideNote(text: "答えがなければ Completion Timeout")
        case 5: SlideNote(text: "Requester ID と Tag で、どの依頼の答えか分かる")
        default: SlideNote(text: "ヘッダ ＋ データ ＋ ECRC")
        }
    }
}

/// ACK / NAK と再送
private struct ReplaySlide: View {
    let index: Int

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(spacing: 6) {
                Text("送る側").font(.caption2).foregroundStyle(.secondary)
                Text("再送バッファ").font(.caption2.weight(.semibold))
                HStack(spacing: 4) {
                    ForEach(1...3, id: \.self) { n in
                        SlideBox(text: "\(n)", on: !(index == 1 && n == 1))
                            .opacity(index == 1 && n == 1 ? 0.2 : 1)
                    }
                }
            }
            VStack(spacing: 8) {
                SlideArrow(symbol: "arrow.right", label: index == 2 || index == 3 ? "もう一度送る" : "TLP",
                           on: [0, 2, 3].contains(index))
                switch index {
                case 1: SlideArrow(symbol: "arrow.left", label: "ACK", on: true)
                case 2: SlideArrow(symbol: "arrow.left", label: "NAK", on: true)
                case 3: SlideArrow(symbol: "timer", label: "時間切れ", on: true)
                default: SlideArrow(symbol: "arrow.left", label: "ACK / NAK", on: false)
                }
            }
            .frame(minWidth: 110)
            SlideBox(text: "受ける側", detail: index == 2 ? "壊れた TLP" : "TLP を確認", on: [1, 2].contains(index))
        }
        if index >= 4 {
            HStack(spacing: 6) {
                ForEach(0..<4) { n in
                    SlideBox(text: "\(n)", on: true)
                }
                SlideArrow(symbol: "arrow.right", on: index == 5)
                SlideBox(text: "Recovery", detail: "再トレーニング", on: index == 5)
            }
        }
        switch index {
        case 1: SlideNote(text: "ACK が来たらバッファから消す")
        case 2: SlideNote(text: "NAK が来たら、バッファに残っている TLP を再送")
        case 3: SlideNote(text: "返事がないと REPLAY_TIMER が切れて再送")
        case 4: SlideNote(text: "REPLAY_NUM：続けて再送した回数")
        case 5: SlideNote(text: "回数があふれたら、信号を疑ってリンクを立ち上げ直す")
        default: SlideNote(text: "送ったものは、確認が取れるまで取っておく")
        }
    }
}

/// クレジットによるフロー制御
private struct CreditsSlide: View {
    let index: Int

    var body: some View {
        HStack(spacing: 8) {
            SlideBox(text: "送る側", on: [0, 4].contains(index))
            VStack(spacing: 6) {
                SlideArrow(symbol: "arrow.right", label: "TLP", on: index == 0)
                SlideArrow(symbol: "arrow.left", label: index == 4 ? "UpdateFC" : "空き＝クレジット",
                           on: [1, 4].contains(index))
            }
            .frame(minWidth: 120)
            SlideBox(text: "受ける側", detail: "バッファ", on: [0, 1, 4].contains(index))
        }
        switch index {
        case 2:
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    Text("")
                    Text("Posted").font(.caption2)
                    Text("Non-Posted").font(.caption2)
                    Text("Completion").font(.caption2)
                }
                ForEach(["Header", "Data"], id: \.self) { kind in
                    GridRow {
                        Text(kind).font(.caption2)
                        ForEach(0..<3) { _ in SlideBox(text: "□", on: true) }
                    }
                }
            }
        case 3:
            HStack(spacing: 4) {
                SlideBox(text: "1 クレジット", on: true)
                Text("=").font(.headline)
                SlideBox(text: "16 バイト", on: true)
                Text("=").font(.headline)
                SlideBox(text: "4 DW", on: true)
            }
        case 5:
            HStack(spacing: 4) {
                SlideBox(text: "初期化で 0", on: true)
                SlideArrow(symbol: "arrow.right", on: true)
                SlideBox(text: "∞", detail: "無限", on: true)
            }
        default:
            EmptyView()
        }
        switch index {
        case 1: SlideNote(text: "受ける側が空きをクレジットで知らせる")
        case 2: SlideNote(text: "ヘッダとデータ × 3種類で別々に数える")
        case 3: SlideNote(text: "データのクレジットは 16 バイト単位")
        case 4: SlideNote(text: "空いたら UpdateFC でクレジットを返す")
        case 5: SlideNote(text: "最初に 0 を知らせる ＝ 無限")
        default: SlideNote(text: "受け取れる分しか送らない")
        }
    }
}

/// レーンと符号化
private struct LanesSlide: View {
    let index: Int

    var body: some View {
        switch index {
        case 1, 2:
            HStack(alignment: .bottom, spacing: 6) {
                ForEach([1, 2, 4, 8, 16], id: \.self) { width in
                    VStack(spacing: 2) {
                        ForEach(0..<min(width, 8), id: \.self) { _ in
                            Capsule().fill(.tint.opacity(width == 16 && index == 2 ? 0.9 : 0.45)).frame(height: 4)
                        }
                        Text("x\(width)").font(.caption2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
        case 3, 4:
            VStack(alignment: .leading, spacing: 8) {
                bar(label: "8b/10b", useful: 0.8, note: "20% が無駄", on: index == 3)
                bar(label: "128b/130b", useful: 128.0 / 130.0, note: "約 1.5%", on: index == 4)
            }
        case 5:
            HStack(spacing: 8) {
                SlideBox(text: "データ", detail: "0 1 1 0 1 …", on: true)
                SlideArrow(symbol: "arrow.right", on: true)
                SlideBox(text: "クロックを取り出す", detail: "専用のクロック線なし", on: true)
            }
        default:
            HStack(spacing: 8) {
                SlideBox(text: "デバイス A", on: true)
                VStack(spacing: 6) {
                    SlideArrow(symbol: "arrow.right", label: "送信用ペア", on: true)
                    SlideArrow(symbol: "arrow.left", label: "受信用ペア", on: true)
                }
                .frame(minWidth: 110)
                SlideBox(text: "デバイス B", on: true)
            }
        }
        switch index {
        case 1: SlideNote(text: "リンクの幅は x1〜x16")
        case 2: SlideNote(text: "x16 ＝「by sixteen」と読む")
        case 3: SlideNote(text: "第1・第2世代は 8b/10b")
        case 4: SlideNote(text: "8 GT/s からは 128b/130b")
        case 5: SlideNote(text: "クロックはデータの流れから取り出す")
        default: SlideNote(text: "1レーン ＝ 送信と受信の差動ペア2組")
        }
    }

    private func bar(label: String, useful: Double, note: String, on: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(label)（\(note)）").font(.caption2.weight(.semibold))
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(.tint.opacity(on ? 0.8 : 0.3)).frame(width: geo.size.width * useful)
                    Rectangle().fill(Color.red.opacity(on ? 0.6 : 0.2))
                }
            }
            .frame(height: 14)
            .clipShape(Capsule())
        }
    }
}

/// LTSSM の状態の流れ
private struct LTSSMSlide: View {
    let index: Int

    var body: some View {
        VStack(spacing: 6) {
            SlideBox(text: "Detect", detail: "相手がいるか確かめる", on: index == 0 || index == 1)
            SlideArrow(symbol: "arrow.down", on: index <= 2)
            SlideBox(text: "Polling", detail: "ビットと記号を合わせる", on: index == 0 || index == 2)
            SlideArrow(symbol: "arrow.down", on: index == 0 || index == 3)
            SlideBox(text: "Configuration", detail: "幅とレーン番号を決める", on: index == 0 || index == 3)
            SlideArrow(symbol: "arrow.down", on: index == 0 || index == 4)
            HStack(spacing: 8) {
                SlideBox(text: "L0", detail: "ふだんの状態", on: [0, 4, 5].contains(index))
                SlideArrow(symbol: "arrow.left.arrow.right", on: index == 5)
                SlideBox(text: "Recovery", detail: "立て直す・速度を変える", on: index == 5)
            }
        }
        switch index {
        case 1: SlideNote(text: "Detect：つながっているか")
        case 2: SlideNote(text: "Polling：トレーニング用の信号をやりとり")
        case 3: SlideNote(text: "Configuration：何レーンで使うか決める")
        case 4: SlideNote(text: "L0：TLP と DLLP が流れる")
        case 5: SlideNote(text: "問題や速度変更は Recovery を通って L0 へ戻る")
        default: SlideNote(text: "LTSSM ＝ リンクを立ち上げる状態マシン")
        }
    }
}

/// コンフィグ空間
private struct ConfigSlide: View {
    let index: Int

    var body: some View {
        VStack(spacing: 4) {
            SlideBox(text: "0〜255 バイト", detail: "PCI と同じ部分（Vendor ID ・ BAR など）", on: [0, 1, 2, 3, 4].contains(index))
            SlideBox(text: "256 バイト〜4 KB", detail: "PCIe で広がった部分", on: index == 0)
        }
        switch index {
        case 2:
            HStack(spacing: 4) {
                ForEach(["Bus", "Device", "Function"], id: \.self) { SlideBox(text: $0, on: true) }
                SlideArrow(symbol: "arrow.right", on: true)
                SlideBox(text: "Vendor ID", detail: "読めたら機器あり", on: true)
            }
        case 3, 4:
            HStack(spacing: 4) {
                SlideBox(text: "BAR", on: true)
                if index == 4 {
                    SlideArrow(symbol: "arrow.right", label: "全部 1 を書く", on: true)
                    SlideBox(text: "読み戻す", detail: "下の 0 の数で大きさが分かる", on: true)
                } else {
                    SlideArrow(symbol: "arrow.right", on: true)
                    SlideBox(text: "必要なメモリの大きさ", on: true)
                }
            }
        case 5:
            HStack(spacing: 4) {
                SlideBox(text: "CPU", on: true)
                SlideArrow(symbol: "arrow.right", label: "ふつうのメモリ読み書き", on: true)
                SlideBox(text: "ECAM", detail: "コンフィグ空間", on: true)
            }
        default:
            EmptyView()
        }
        switch index {
        case 1: SlideNote(text: "最初の 256 バイトは PCI と互換")
        case 2: SlideNote(text: "番号ごとに Vendor ID を読む ＝ 列挙")
        case 3: SlideNote(text: "BAR：必要なメモリの大きさを示す")
        case 4: SlideNote(text: "全部 1 を書いて読み戻すと大きさが分かる")
        case 5: SlideNote(text: "ECAM ならメモリの読み書きでアクセスできる")
        default: SlideNote(text: "機能ごとに 4 KB のコンフィグ空間")
        }
    }
}

/// MSI / MSI-X
private struct MSISlide: View {
    let index: Int

    var body: some View {
        switch index {
        case 0, 1:
            HStack(spacing: 8) {
                SlideBox(text: "デバイス", on: true)
                SlideArrow(symbol: index == 0 ? "bolt.fill" : "envelope.fill",
                           label: index == 0 ? "専用の線（INTx）" : "メッセージで代わりに送る", on: true)
                SlideBox(text: "CPU", on: true)
            }
        case 2, 3:
            HStack(spacing: 8) {
                SlideBox(text: "デバイス", on: true)
                VStack(spacing: 4) {
                    if index == 3 {
                        SlideArrow(symbol: "arrow.right", label: "データの書き込み", on: false)
                    }
                    SlideArrow(symbol: "arrow.right", label: "特別なアドレスへの書き込み", on: true)
                }
                SlideBox(text: "CPU", detail: "割り込み", on: true)
            }
        default:
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(0..<4) { n in SlideBox(text: "ベクタ \(n)", detail: "キュー \(n)", on: true) }
                }
                HStack(spacing: 4) {
                    ForEach(0..<4) { n in SlideBox(text: "コア \(n)", on: index == 5) }
                }
            }
        }
        switch index {
        case 1: SlideNote(text: "PCIe には割り込みの線がない")
        case 2: SlideNote(text: "MSI：メモリへの書き込みで割り込む")
        case 3: SlideNote(text: "ただの書き込みなので、前に書いたデータを追い越さない")
        case 4: SlideNote(text: "MSI-X：最大 2048 個のベクタ")
        case 5: SlideNote(text: "コアごとに自分のキューを処理できる")
        default: SlideNote(text: "昔の PCI は専用の線で割り込み")
        }
    }
}

/// PCIe 6.0：PAM4・FEC・フリット
private struct Gen6Slide: View {
    let index: Int

    var body: some View {
        switch index {
        case 1, 2:
            HStack(alignment: .bottom, spacing: 16) {
                levels(count: 2, label: "NRZ：2段階 ＝ 1ビット")
                levels(count: 4, label: "PAM4：4段階 ＝ 2ビット")
            }
            .frame(height: 120)
        case 3, 5:
            HStack(spacing: 4) {
                SlideBox(text: "受信", on: true)
                SlideArrow(symbol: "arrow.right", on: true)
                SlideBox(text: "FEC", detail: "ほとんど直す", on: true)
                SlideArrow(symbol: "arrow.right", on: index == 5)
                SlideBox(text: "CRC", detail: "直せない分は再送", on: index == 5)
            }
        case 4:
            HStack(spacing: 2) {
                SlideBox(text: "TLP ・ DLLP", on: true)
                SlideBox(text: "CRC", on: true)
                SlideBox(text: "FEC", on: true)
            }
        default:
            HStack(spacing: 4) {
                SlideBox(text: "PCIe 5.0", detail: "32 GT/s", on: false)
                SlideArrow(symbol: "arrow.right", label: "2倍", on: true)
                SlideBox(text: "PCIe 6.0", detail: "64 GT/s", on: true)
            }
        }
        switch index {
        case 1: SlideNote(text: "速くする代わりに、1回で2ビット送る")
        case 2: SlideNote(text: "段階の差が小さいので、ノイズに弱い")
        case 3: SlideNote(text: "軽い FEC（前方誤り訂正）を追加")
        case 4: SlideNote(text: "決まった大きさのフリット（256 バイト）で送る")
        case 5: SlideNote(text: "FEC で直せないものは CRC で見つけて再送")
        default: SlideNote(text: "PCIe 6.0 は 64 GT/s")
        }
    }

    private func levels(count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            VStack(spacing: index == 2 && count == 4 ? 4 : 10) {
                ForEach(0..<count, id: \.self) { _ in
                    Capsule().fill(.tint.opacity(count == 4 ? 0.8 : 0.4)).frame(height: 4)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            Text(label).font(.caption2.weight(.semibold)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 箱と矢印を並べるだけのスライド（追加のレッスン用。中身は PCIeStudy/Data/EnglishSlideData.swift）

private struct SimpleSlideView: View {
    let slide: SimpleSlide

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(slide.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        switch cell {
                        case let .box(text, detail, on): SlideBox(text: text, detail: detail, on: on)
                        case let .arrow(symbol, label, on): SlideArrow(symbol: symbol, label: label, on: on)
                        }
                    }
                }
            }
        }
        SlideNote(text: slide.note)
    }
}
