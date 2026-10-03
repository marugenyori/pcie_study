# 開発の履歴

これまでに何をして、何が起きたかの記録です。新しい作業を始めるときの参考にしてください。

## 2026-09-29 GitHub の接続とリポジトリの準備

- Windows PC に GitHub CLI（`gh`）が入っていたので、`gh auth login`（ブラウザ方式）でログインした
- 最初に手作りのトークン（権限が広すぎる classic PAT）を使っていたため、ブラウザ方式で作り直した
- `marugenyori/claud_code`（非公開・空）を clone した
- Windows では、深い階層のファイルでパスが長すぎるエラーが出た → このリポジトリだけ `git config core.longpaths true` で解決

## 2026-09-29 iOS 版のビルド（GitHub Actions）

- 別の場所で作った iOS 版一式（zip）を展開して push した
- macOS ランナー（`macos-26`、Xcode 26）で、署名なしのシミュレータ向けビルドを確認した
- コンパイルエラーを2つ直した
  1. 複数行文字列で、図の1行が閉じる `"""` より左に出ていた
  2. `replayBuffer.removeAll { !isAfter($0, seq) }` の排他アクセスエラー → `isAfter` を `static` に変更
- 3回目でビルド成功

## 2026-10-03 TestFlight での配信

- Apple Developer Program（個人、年額 12,980円）に登録した
- Bundle ID `com.marugenyori.study` を登録し、App Store Connect にアプリ「marugenyo,study」を作った
- App Store Connect API キー（Admin）を作り、5つの Secrets を GitHub に登録した
- 「TestFlight にアップロードする」で実行 → 初回から成功
- 内部テスターに自分を追加し、iPhone の TestFlight アプリからインストールした

## 2026-10-03 クイズの強化

- 結果画面に追加：間違えた問題の解き直し、新しい問題で挑戦、章の解説へ戻る、次の章のクイズへ、章ごとの成績、1問ずつのふり返り、自己ベスト
- 苦手リスト（間違えた問題がたまり、正解すると外れる）
- 問題を各章6問ずつ追加（144問 → 234問）

## 2026-10-03 毎日続ける機能・ウィジェット・読みもの

- 「今日」タブ：連続日数、1日の目標、直近4週間、今日の1問、実績バッジ、リマインダー設定
- ローカル通知：毎日決めた時刻に、その日の1問を通知（目標達成日は送らない）
- ウィジェット：連続学習（ホーム画面・ロック画面）、今日の1問
- コラム9本、PCIe ニュース12件（出典付き）。用語集は「学ぶ」タブに移動
- App Group を使うため、Bundle ID を `APP_BUNDLE_ID` で渡す方式に変更

### はまった点：App Group の署名エラー

- 症状：`Provisioning profile ... doesn't match the entitlements file's value for the com.apple.security.application-groups entitlement`
- 原因：App Group `group.com.marugenyori.study` を作っただけで、App ID への割り当てが保存されていなかった（プロファイルのグループが空だった）
- 解決：Identifiers で `com.marugenyori.study` と `com.marugenyori.study.widget` の両方を開き、App Groups の Edit でグループにチェック → Save → Confirm

## 2026-10-03 仕様書との照合

- PCIe Base Specification 7.1 の PDF（PC 内）からテキストを取り出し、クイズ・解説・用語集を照合した
- 修正：PCIe 7.0 の仕様書の日付（2025年6月5日）、根拠のなかった FEC 遅延の問題の差し替え、Polling.Compliance と ACK/NAK（Flit Mode）の説明

## 2026-10-03 表示設定（見やすさ）

- 各タブ右上の「Aa」から表示設定を開けるようにした（プレビュー付き）
- 文字の大きさ（小さめ〜最大、または iPhone の設定に合わせる）、テーマの色7種、外観（自動・ライト・ダーク）、解説の行間
- テーマ色は `.tint` で全体に反映。`Color.accentColor` を直接使うと設定に追従しないので、`.tint` を使う

## 2026-10-03 ポップなスタイル

- 「スタイル」設定（ポップ／シンプル）と背景の色（ホワイト／クリーム／テーマ色）を追加。既定はポップ＋ライム色＋丸ゴシック
- ポップ：明るい背景、縁取りのカード、下に厚みのある立体ボタン、正解・不正解で緑・赤になる選択肢。ダークモードは濃い紺色

## 2026-10-03 「わからない」・選択肢ごとの解説・仕様書の参照

- クイズと「今日の1問」に「わからない（答えを見る）」を追加。苦手リストに入る
- 全234問に、不正解の選択肢がなぜ違うかの解説を追加
- 全問に、仕様書（Base 7.1）の関連する章・ページを表示。章番号とページは仕様書の目次と自動で照合済み
- 回答後の「次の問題へ」を画面下に固定

## 2026-10-03 ゲーム要素

- XP とレベル（称号付き）、コンボボーナス、レベルアップ演出（紙吹雪）
- デイリークエスト3つ（10問解く／5問連続正解／苦手を1問克服、各 +30 XP）
- ゲームモード：サバイバル（ライフ3つ）。自己ベストを記録（タイムアタックも作ったが、不要とのことで削除）
- 正解・不正解でバイブ（触覚フィードバック）。実績を4つ追加
- ルールの数値は `PCIeStudy/Models/GameRules.swift` にまとめてある

### はまった点：証明書の上限

- 症状：`Choose a certificate to revoke. Your account has reached the maximum number of certificates.`（TestFlight を10回ほど実行したところで発生）
- 原因：GitHub Actions のマシンは毎回まっさらなので、自動署名のたびに開発用証明書「Created via API」が新しく作られていた
- 解決：アーカイブの前に、App Store Connect API で「Created via API」の開発用証明書だけを削除するステップを追加（初回は10件を削除）
