# このリポジトリについて（Claude 向けの作業メモ）

PCIe を学ぶ iOS アプリ「PCIe学習」（SwiftUI）と、それを Mac なしでビルド・配信する GitHub Actions の設定が入っています。
持ち主は Mac を持っておらず、Windows PC と iPhone から作業します。ビルドの確認も配信も、すべて GitHub Actions（macOS ランナー）で行います。

## 返答のしかた

- **日本語**で、専門用語には短い説明を添える
- 持ち主が自分で操作する手順（Apple Developer、App Store Connect、GitHub の Secrets など）は、画面の項目名どおりに番号付きで書く
- パスワード・API キー・`.p8` の中身は、チャットに貼ってもらわない。GitHub や Apple の画面に直接入力してもらう

## 構成

| パス | 内容 |
|---|---|
| `PCIeStudy/` | アプリ本体（App / Views / Models / Data） |
| `Shared/` | アプリとウィジェットの両方で使うコード（章・クイズのデータ、連続日数 `StudyStats`、今日の1問 `DailyPick`） |
| `PCIeStudyWidget/` | ウィジェット拡張（連続学習・今日の1問） |
| `Config/` | entitlements（App Group）とウィジェットの Info.plist |
| `PCIeStudy.xcodeproj/` | Xcode プロジェクト（フォルダ同期方式。上の3フォルダにファイルを置くだけでビルド対象になる） |
| `.github/workflows/ios-build.yml` | ビルド確認と TestFlight 配信 |
| `docs/` | 開発の履歴（`DEVELOPMENT_LOG.md`）と、新しいアプリを作る手順（`NEW_APP_GUIDE.md`） |

- iOS 17 以上、Swift 5 モード、外部ライブラリなし
- 保存は `UserDefaults`。連続日数など、ウィジェットと共有する値は App Group（`group.` + Bundle ID）に保存する

## ビルドと配信

- `main` に push すると、署名なしのシミュレータ向けビルドが自動で走る（エラーは実行結果ページの「ビルド結果」にまとまる）
- TestFlight へ出すとき：Actions → iOS Build → Run workflow →「TestFlight にアップロードする」にチェック
  - `gh` が使えるなら `gh workflow run ios-build.yml -f testflight=true`
- ビルド番号は Actions の実行番号が自動で入る
- 必要な Secrets（登録済み）：`APPLE_TEAM_ID`、`BUNDLE_ID`、`ASC_KEY_ID`、`ASC_ISSUER_ID`、`ASC_KEY_P8`
- Bundle ID はビルド設定 `APP_BUNDLE_ID` で渡す（ウィジェットは `$(APP_BUNDLE_ID).widget`）。`PRODUCT_BUNDLE_IDENTIFIER` をコマンドラインで上書きすると、ウィジェットまで同じ ID になって壊れるので使わない

## コードを変えるときの注意（実際にはまった点）

- **複数行文字列（`"""`）**：中の行が、閉じる `"""` より左に出るとコンパイルエラーになる。図（ASCII アート）を書くときは特に注意
- **排他アクセスエラー**：`array.removeAll { self.method($0) }` のように、書き換え中の配列のクロージャから `self` を読むとエラーになる。`self` を使わない関数は `static` にする
- **新しい機能（Capability）を足すとき**：App Group、Push 通知、iCloud などを entitlements に追加したら、Apple Developer の Identifiers で、アプリ本体とウィジェットの**両方の App ID** に同じ設定をしてもらう必要がある。自動署名だけでは割り当てまではされない。署名で失敗すると、ワークフローの「署名プロファイルの確認」ステップにプロファイルの中身が表示される
- **証明書の上限**：CI は毎回まっさらなマシンで自動署名するため、開発用証明書（Created via API）が毎回増える。上限に達すると `Your account has reached the maximum number of certificates` で失敗する。ワークフローの「CI が作った古い開発用証明書を整理」ステップ（`.github/scripts/cleanup_dev_certs.py`）で、アーカイブ前に自動で消している
- 新しいターゲット（拡張）を足すときは `project.pbxproj` を手で編集する。既存のウィジェットターゲット（ID の末尾 `016`）の書き方をまねる

## 内容の正確さ

- 技術的な内容は PCIe Base Specification 7.1 と照らし合わせて確認済み（2026年10月）。仕様書の PDF は持ち主の Windows PC にだけあり、リポジトリには入れない（PCI-SIG の著作物のため）
- iPhone からの作業では仕様書を見られない。数値やビット位置を追加・変更したときは「仕様書で未確認」と伝え、PC で照合するよう案内する
- ニュース（`PCIeStudy/Data/NewsData.swift`）はアプリに同梱している。更新するときは Web で調べ直し、出典 URL を付けて `updated` の日付も変える

## 見た目の決まり（`PCIeStudy/Views/Common/AppStyle.swift`）

- 画面の一番外側の List / Form / ScrollView には `.screenBackground()` を付ける（`.navigationTitle` の直前）
- カードは `.cardStyle(cornerRadius:)`、ボタンは `.buttonStyle(AppButtonStyle(.primary / .secondary))`、クイズの選択肢は `.choiceTile(状態)` を使う
- 色は `Color.accentColor` ではなく `.tint` を使う（テーマ色の設定に追従させるため）
- 文字サイズは固定値（`.system(size:)`）を避け、`.body` や `.caption` などを使う

## クイズを追加・変更するとき

- 問題は `Shared/QuizData.swift`（と `QuizData+Extra.swift`）、選択肢ごとの解説と仕様書の参照先は `Shared/QuizNotes*.swift`、くわしい解説は `Shared/QuizDetails*.swift` に書く（3つとも全問そろえる）
- `QuizNotes` の `choices` は問題の選択肢と同じ順番・同じ数にし、**正解の位置だけ空文字**にする（アプリ側で「正解です」と表示する）
- 仕様書の参照先は Base 7.1 の章番号・タイトル・ページ。iPhone からは確認できないので、追加したときは「PC で照合が必要」と伝える
