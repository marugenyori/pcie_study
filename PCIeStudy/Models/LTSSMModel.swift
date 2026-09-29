import Foundation

enum LTSSMGroup: String, CaseIterable, Identifiable {
    case detect = "Detect"
    case polling = "Polling"
    case configuration = "Configuration"
    case l0 = "L0"
    case recovery = "Recovery"
    case l0s = "L0s"
    case l1 = "L1"
    case l2 = "L2"
    case disabled = "Disabled"
    case loopback = "Loopback"
    case hotReset = "Hot Reset"

    var id: String { rawValue }
}

struct LTSSMTransition: Hashable {
    let to: String
    let condition: String
}

struct LTSSMState: Identifiable, Hashable {
    let id: String
    let group: LTSSMGroup
    let description: String
    let transitions: [LTSSMTransition]
}

/// 教育用に簡略化したLTSSM（主要な遷移のみ）
enum LTSSMModel {
    static let initial = "Detect.Quiet"

    static let states: [String: LTSSMState] = {
        let list: [LTSSMState] = [
            LTSSMState(id: "Detect.Quiet", group: .detect,
                       description: "リセット解除直後の初期状態。送信器はElectrical Idle（無信号）。速度は2.5 GT/sに戻されます。",
                       transitions: [.init(to: "Detect.Active", condition: "12ms経過、または受信レーンでElectrical Idleの終了を検出")]),
            LTSSMState(id: "Detect.Active", group: .detect,
                       description: "送信器が各レーンで相手の受信終端（負荷）の有無を電気的に検出します。検出できたレーンがリンクに使われます。",
                       transitions: [.init(to: "Polling.Active", condition: "受信終端を検出"),
                                     .init(to: "Detect.Quiet", condition: "どのレーンでも検出できない")]),
            LTSSMState(id: "Polling.Active", group: .polling,
                       description: "TS1 Ordered Setを送り続け、受信側はビットロックとシンボルロックを確立します。差動ペアの極性反転もここで補正します。",
                       transitions: [.init(to: "Polling.Configuration", condition: "TS1/TS2を8個連続で受信し、TS1を1024個以上送信済み"),
                                     .init(to: "Polling.Compliance", condition: "24ms経過しても一部レーンが応答しない（測定用の終端など）"),
                                     .init(to: "Detect.Quiet", condition: "24msタイムアウト")]),
            LTSSMState(id: "Polling.Compliance", group: .polling,
                       description: "コンプライアンステスト用のパターンを送信し続ける状態。測定器（終端のみ）が接続されたときに入ります。",
                       transitions: [.init(to: "Polling.Active", condition: "Electrical Idleの終了を検出")]),
            LTSSMState(id: "Polling.Configuration", group: .polling,
                       description: "TS2を送信し、相手も準備完了であることを確認します。",
                       transitions: [.init(to: "Configuration.Linkwidth.Start", condition: "TS2を8個連続で受信し、TS2を16個送信"),
                                     .init(to: "Detect.Quiet", condition: "48msタイムアウト")]),
            LTSSMState(id: "Configuration.Linkwidth.Start", group: .configuration,
                       description: "下流ポート（RC側）がリンク番号入りのTS1を送り、使えるレーンを確認します。",
                       transitions: [.init(to: "Configuration.Linkwidth.Accept", condition: "相手からリンク番号入りTS1を受信"),
                                     .init(to: "Disabled", condition: "上位層からLink Disableを指示された"),
                                     .init(to: "Loopback", condition: "Loopbackを指示された、またはLoopbackビット付きTS1を受信"),
                                     .init(to: "Detect.Quiet", condition: "24msタイムアウト")]),
            LTSSMState(id: "Configuration.Linkwidth.Accept", group: .configuration,
                       description: "上流ポートがリンク番号を受け入れ、リンク幅（x1, x4, x16など）が決まります。",
                       transitions: [.init(to: "Configuration.Lanenum.Wait", condition: "リンク番号の合意")]),
            LTSSMState(id: "Configuration.Lanenum.Wait", group: .configuration,
                       description: "下流ポートがレーン番号入りのTS1を送り、各レーンの番号を提案します。",
                       transitions: [.init(to: "Configuration.Lanenum.Accept", condition: "相手からレーン番号入りTS1を受信")]),
            LTSSMState(id: "Configuration.Lanenum.Accept", group: .configuration,
                       description: "レーン番号を確定します。レーン反転（逆順配線）の検出もここで行われます。",
                       transitions: [.init(to: "Configuration.Complete", condition: "レーン番号が一致")]),
            LTSSMState(id: "Configuration.Complete", group: .configuration,
                       description: "確定したリンク番号・レーン番号入りのTS2を交換し、N_FTSなどのパラメータを伝えます。",
                       transitions: [.init(to: "Configuration.Idle", condition: "TS2を8個連続で受信")]),
            LTSSMState(id: "Configuration.Idle", group: .configuration,
                       description: "アイドルデータ（論理的な0）を送り、データ送信の準備をします。ここでLinkUpが1になり、物理層がリンクアップをデータリンク層に通知します。Flit ModeではアイドルデータのかわりにIDLE Flitを送ります。",
                       transitions: [.init(to: "L0", condition: "アイドルデータを8シンボル受信し、1シンボル受信後に16シンボル送信（Flit ModeではIDLE Flitを2個連続で受信）")]),
            LTSSMState(id: "L0", group: .l0,
                       description: "通常動作状態。TLPとDLLPを送受信します。初回は2.5 GT/sですが、両者が高速な世代に対応していればRecoveryで速度を上げます。",
                       transitions: [.init(to: "Recovery.RcvrLock", condition: "速度変更の要求／受信エラー／TS1を受信／Retrain Link"),
                                     .init(to: "L0s", condition: "送信側のアイドルが続きASPMで移行"),
                                     .init(to: "L1", condition: "PM_Enter_L1などのDLLPハンドシェイク"),
                                     .init(to: "L2", condition: "PME_Turn_Off → PM_Enter_L23 ハンドシェイク後、主電源オフ")]),
            LTSSMState(id: "Recovery.RcvrLock", group: .recovery,
                       description: "TS1を送り、受信側でビットロック（Gen3以降はブロックアラインメント）を取り直します。",
                       transitions: [.init(to: "Recovery.RcvrCfg", condition: "TS1/TS2を8個連続で受信"),
                                     .init(to: "Recovery.Equalization", condition: "Gen3以上へ初めて変更した直後（イコライゼーションが必要）"),
                                     .init(to: "Recovery.Speed", condition: "新しい速度でロックできない（元の速度に戻す）"),
                                     .init(to: "Detect.Quiet", condition: "24msタイムアウト")]),
            LTSSMState(id: "Recovery.Equalization", group: .recovery,
                       description: "Gen3以降の速度で、Phase 0〜3の手順により送信プリセットとFFE係数を両端で調整し、最適な信号品質を探します。",
                       transitions: [.init(to: "Recovery.RcvrLock", condition: "イコライゼーション完了")]),
            LTSSMState(id: "Recovery.RcvrCfg", group: .recovery,
                       description: "TS2を交換して設定を確認します。TS2に速度変更要求（speed_change）が立っていればRecovery.Speedへ進みます。",
                       transitions: [.init(to: "Recovery.Speed", condition: "両者が速度変更に合意（speed_changeビット）"),
                                     .init(to: "Recovery.Idle", condition: "TS2を8個連続で受信（速度変更なし）"),
                                     .init(to: "Configuration.Linkwidth.Start", condition: "リンク幅やレーン番号の変更が必要")]),
            LTSSMState(id: "Recovery.Speed", group: .recovery,
                       description: "送信器をElectrical Idleにして、転送速度を切り替えます。",
                       transitions: [.init(to: "Recovery.RcvrLock", condition: "新しい速度に切り替え完了")]),
            LTSSMState(id: "Recovery.Idle", group: .recovery,
                       description: "アイドルデータを送り、L0に戻る準備をします。ここからHot Reset・Disabled・Loopbackへ分岐することもあります。",
                       transitions: [.init(to: "L0", condition: "アイドルデータを8シンボル受信し、16シンボル送信"),
                                     .init(to: "Hot Reset", condition: "ソフトウェアがSecondary Bus Resetを要求"),
                                     .init(to: "Disabled", condition: "ソフトウェアがLink Disableを設定"),
                                     .init(to: "Loopback", condition: "Loopbackビット付きTS1を送受信")]),
            LTSSMState(id: "L0s", group: .l0s,
                       description: "送信方向ごとに独立した低電力状態。EIOSを送ってElectrical Idleに入ります。復帰が非常に速いのが特徴です。Non-Flit Modeだけの状態で、Flit Modeでは使えません。",
                       transitions: [.init(to: "L0", condition: "FTSを送り、受信側がSKP（8b/10b）またはSDS（128b/130b）を受け取って復帰"),
                                     .init(to: "Recovery.RcvrLock", condition: "受信側がN_FTSのタイムアウトまでに同期できなかった")]),
            LTSSMState(id: "L1", group: .l1,
                       description: "両方向とも停止する低電力状態。ASPMまたはデバイスのD3hot移行で入ります。L1.1/L1.2のサブステートでさらに省電力化できます。",
                       transitions: [.init(to: "Recovery.RcvrLock", condition: "どちらかが送信を再開（Electrical Idle終了）")]),
            LTSSMState(id: "L2", group: .l2,
                       description: "主電源がオフで、補助電源（Vaux）のみの状態。WAKE#やBeaconで起床します。",
                       transitions: [.init(to: "Detect.Quiet", condition: "電源再投入（ウェイクアップ）")]),
            LTSSMState(id: "Disabled", group: .disabled,
                       description: "ソフトウェアによってリンクが無効化された状態。Electrical Idleのままです。",
                       transitions: [.init(to: "Detect.Quiet", condition: "Link Disableが解除される")]),
            LTSSMState(id: "Loopback", group: .loopback,
                       description: "受信したデータをそのまま送り返すテスト用の状態。ビットエラー率の測定などに使います。",
                       transitions: [.init(to: "Detect.Quiet", condition: "ループバック終了（EIOS受信）")]),
            LTSSMState(id: "Hot Reset", group: .hotReset,
                       description: "リンク経由で下流デバイスをリセットします（TS1のHot Resetビット）。",
                       transitions: [.init(to: "Detect.Quiet", condition: "2ms経過")]),
        ]
        return Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }()

    /// Gen1でリンクアップ後、Gen3以上へ速度を上げるまでの典型的な流れ
    static let linkUpScenario: [String] = [
        "Detect.Quiet", "Detect.Active",
        "Polling.Active", "Polling.Configuration",
        "Configuration.Linkwidth.Start", "Configuration.Linkwidth.Accept",
        "Configuration.Lanenum.Wait", "Configuration.Lanenum.Accept",
        "Configuration.Complete", "Configuration.Idle",
        "L0",
        "Recovery.RcvrLock", "Recovery.RcvrCfg", "Recovery.Speed",
        "Recovery.RcvrLock", "Recovery.Equalization",
        "Recovery.RcvrLock", "Recovery.RcvrCfg", "Recovery.Idle",
        "L0",
    ]

    static func scenarioNote(step: Int) -> String? {
        switch step {
        case 10: return "2.5 GT/s（Gen1）でリンクアップ！ここから速度を上げます"
        case 13: return "両者がGen3以上に対応しているので速度を切り替えます"
        case 15: return "新しい速度でイコライゼーションを実施"
        case 19: return "目標速度でL0に到達。リンクアップ完了"
        default: return nil
        }
    }
}
