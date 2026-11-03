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

## 2026-10-03 くわしい解説

- 全234問に「くわしい解説」（しくみ・理由・ほかの知識とのつながり、平均110文字）を追加。回答後とふり返りで表示

## 2026-10-03 仕様書に質問（PCのRAG）

- 「学ぶ」タブ →「仕様書に質問（PCのRAG）」と、クイズの解説の下のボタンから、PCの PCIe_RAG（server.py）に質問できるようにした
- 通信先は同じWi-FiのPC（start_lan.bat、ポート8765）。/api/health で状態確認、/api/ask はNDJSONのストリーム
- iPhone 側は NSAllowsLocalNetworking とローカルネットワークの利用目的（Config/PCIeStudy-Info.plist、ビルド設定）を追加
- 外出先からは使えない（PCが起動していて、同じネットワークにいるときだけ）

## 2026-10-07 ニュースのウィジェット

- ウィジェット「PCIe ニュース」を追加。ロック画面（長方形・1行）とホーム画面（小・中）に置ける
- 新しい順の5件を、3時間ごとに切り替えて表示する
- ウィジェットからも読めるよう、`NewsData.swift` を `PCIeStudy/Data/` から `Shared/` に移した
- ニュースのウィジェットをタップすると、そのニュースがアプリのシートで開くようにした（URL スキーム `pciestudy://news/<id>`、`Config/PCIeStudy-Info.plist` の `CFBundleURLTypes`）
- ニュースを12件から20件に増やした（PCIe 6.0 の初の適合試験ワークショップ、PCIe 6.0 SSD の量産、CXL 4.0、CopprLink など）。分類に「製品」を追加。ウィジェットは新しい順の10件を切り替える
- 「PCIe 6.0 のインテグレーターズリスト試験が2025年に始まった」という項目は誤り（最初の 6.x ワークショップは2026年7月）だったので、2024年6月の「試験が遅れる見通し」に差し替えた

## 2026-10-09 仕様書QAで回答AIを選べるように

- 「仕様書に質問」の入力欄の上に「回答AI」を追加。PC の `GET /api/models`（`{"models": [...], "default": "..."}` または文字列の配列）から一覧を読み、`/api/ask` に `model` を付けて送る。一覧が取れないサーバでは表示しない
- 選んだモデルは保存し、各回答の下に「回答AI：モデル名」を表示
- 7B など大きいモデル向けに、待ち時間を 300 秒から 1200 秒に延長。回答を待つ間は iPhone の自動ロックを止める（画面が消えると通信が切れるため）

## 2026-10-09 PC側サーバ（PCIe_RAG）の更新

PC の Claude Code で作業した内容（PCIe_RAG はこのリポジトリには入っていない）

- server.py に GET /api/models を追加（{"models": [...], "default": "..."}、埋め込み用モデルは除外）
- /api/ask と /api/search が "model" を受け付ける（一覧にないときは既定のモデル）
- 既定の回答AIを qwen2.5:3b に変更（top_k 8→5、num_ctx 8192→4096）。元の設定は config_7b_backup.json
- 途中で止まった埋め込み計算を続きから再開する ingest_resume.bat と、qwen2.5:3b をダウンロードする pull_3b.bat を追加

## 2026-10-12 ウィジェットから今日の1問を開く

- 「今日の1問」ウィジェットと、「連続学習」ウィジェット（中サイズ、問題を表示）をタップすると、アプリで今日の1問がシートで開き、そのまま答えられるようにした（`pciestudy://daily`）

## 2026-10-12 クイズから Claude Code に頼む

- 回答後の解説の下に「この問題を Claude Code に質問する」と「問題が微妙なら作り直してもらう」を追加（`PCIeStudy/Views/Quiz/ClaudeCodeRequestView.swift`）
- 問題の内容と依頼を書いた文を作り、`https://claude.ai/code/new?q=…&repo=marugenyori/pcie_study&branch=main` で Claude Code の新しいセッションを開く（送信は自分で押す）。依頼文のコピーもできる
- 作り直しの依頼文には、CLAUDE.md のクイズのルールに従うこと、ビルド確認・マージ・TestFlight まで進めることを入れている

## 2026-10-25 ニュースを自動で更新する

- ニュースを Swift のコードから `Shared/news.json` に移した。アプリは起動時（3時間に1回まで）とニュース一覧を開いたとき・下に引っぱったときに、GitHub の main にある最新の news.json を読み込んで App Group に保存する。ウィジェットも表示を更新するときに読み込む
- これで、news.json を main に入れればアプリを出し直さなくても反映される（リポジトリが公開なので raw.githubusercontent.com から読める）
- ニュースを4件追加（Microchip の小規模向け PCIe 6.0 スイッチ、Astera Labs の Aries 7、FMS 2026 の PCIe 6.0 ストレージ、Marvell の 260 レーン PCIe 6.0 スイッチ）
- news.json だけを変えた push ではビルドが走らないようにした（ワークフローの paths に `!Shared/news.json`）
- ニュースを週1件以上にするため、2026年7〜10月の出来事を11件追加（計35件）。出典を開いて日付と内容を確かめたものだけ。7/13・8/10・8/17・9/14 の週などは、確かめられるニュースが見つからなかった
- 週次の自動更新（Routine「PCIeニュースの週次更新」、毎週月曜 7:52 JST）は、毎週最低1件を追加するように指示を変えた
- 主要な出来事を漏らさないよう17件追加（計52件）：規格の歴史（1.0a〜6.0、7.0 の発表とドラフト 0.5 / 0.7 / 0.9）と、2025〜2026年の大きな発表（Broadcom の Gen6 製品と SC25 の 144 レーンスイッチ、Credo の Gen5 適合、Montage の Gen6 ケーブル、Marvell の CXL スイッチ、Computex の Phison X3、FMS の Microchip 160 レーンスイッチ）
- 週次の自動更新には、主要な情報源（PCI-SIG の発表、主要メーカーのニュース、主要イベント）を毎回確認し、過去3か月の主要な出来事の抜けも埋めるよう指示した
- ロック画面のニュースウィジェット（長方形・1行）は、切り替えずに一番新しいニュースを表示するようにした。3時間ごとに GitHub から読み込み直し、新しいニュースが入れば変わる。ホーム画面は今までどおり新しい順の10件を切り替える

## 2026-10-30 英語で聞く（リスニングモード）

- 「学ぶ」タブに「英語で聞く」を追加。PCIe の仕組みを英語で聞きながら、技術英語の聞き取りを練習する（`PCIeStudy/Views/English/EnglishViews.swift`、データは `PCIeStudy/Data/EnglishData.swift`）
- 読み上げは iPhone 内蔵の音声合成（`AVSpeechSynthesizer`、`PCIeStudy/Models/SpeechPlayer.swift`）。通信なし。速さ（ゆっくり・ふつう・はやめ）と発音（アメリカ・イギリス・インド・オーストラリア）を選べる。「拡張」「プレミアム」の声が入っていればそれを使う。消音スイッチがオンでも聞こえる
- レッスンは10本（層、木構造、TLP、ACK/NAK と再送、クレジット、レーンと符号化、LTSSM、コンフィグ空間、MSI、PAM4 とフリット）。それぞれ次の4ステップ
  - 聞く：英文をぼかしたまま聞く → 英文・日本語訳を表示。文をタップするとそこから再生。「1文ごとに止める」でリピーティング・シャドーイング
  - 問題：英語の質問（読み上げあり）に答える。全問答えるとレッスン完了。回答は今日の学習量・連続日数に数える（苦手リストには入れない）
  - 書き取り：1文ずつ聞いて、空欄の単語を4択で選ぶ
  - 単語：発音と「どう聞こえるか」のコツ
- 「PCIe の言葉の英語での読み方」：x16 = by sixteen、GT/s、BAR、ACK/NAK、0x10 など。読み上げ時は `EnglishSpeech.spoken` で表記を読み方に変えている（x16 → by 16 など）
- 英文はアプリ用に書き下ろしたもの（仕様書の文章ではない）。数値は既存の章の内容に合わせたが、仕様書との照合はまだ
- 文を何回かタップすると読み上げなくなる不具合を修正：止めるたびに `AVSpeechSynthesizer` を作り直す（止めた直後に読ませると固まることがあるため）。声の一覧の取得は重いので、言語ごとに覚えておき、声をダウンロードしたら取り直す

## 2026-10-31 配信の録画で英語を学ぶ

- ツールタブに「英語」→「配信で英語」を追加（`PCIeStudy/Views/English/StreamEnglishHomeView.swift` など、保存は `PCIeStudy/Models/EnglishStore.swift`）
- 写真アプリ（画面収録）や「ファイル」から動画を取り込み、アプリの Application Support/EnglishClips にコピーする。一覧とフレーズ帳は UserDefaults に保存
- 文字起こしは iPhone の音声認識（Speech フレームワーク、en-US）。1回に約1分までしか扱えないので、50秒ずつ区切って認識する（`ClipTranscriber.swift`）。英語のデータが iPhone にあれば端末内で認識する
- 再生画面の右上から、スクリプト（時刻付きの全文）の共有・コピーと、文字起こしのやり直しができる
- 再生画面：文をタップでその位置から再生、1文くり返し、1文ずつ止める（シャドーイング用）、速さ 0.5/0.75/1×、英文を隠す、長押しでフレーズ帳に保存・日本語訳（iOS 17.4 以上の翻訳機能）・コピー
- Info.plist に音声認識の利用目的（`NSSpeechRecognitionUsageDescription`）を追加。Capability の追加はないので、Apple Developer 側の設定は不要

## 2026-11-03 配信で英語：文字起こしが最後の発話しか残らない不具合を修正

- 50秒の区間ごとに、最後の発話（間のあとの部分）しか文字起こしされなかった。最近の iOS では、間があくと認識結果がリセットされ、最後の結果には最後の発話しか入らないため
- 途中の結果も受け取り（`shouldReportPartialResults = true`）、発話の終わり（`speechRecognitionMetadata` 付き）ごとに単語を集めるようにした。結果が積み上がる場合に重ならないよう、集めた時刻より後の単語だけを足す
- 取り込み済みの動画は、再生画面右上のボタン →「文字起こしをやり直す」で作り直せる
- 写真からの取り込みが遅い（10分の動画で5分以上）のを修正：PhotosPicker の `preferredItemEncoding` を `.current` にして、形式の変換をせず元のファイルのまま受け取る
- 文字起こしを速くするため、iOS 26 以上では SpeechAnalyzer（`SpeechTranscriber`）で音声全体を一度に認識する。英語の認識データは初回にダウンロードする。iOS 26 より前は、今までどおり 50 秒ずつ区切る方法
- 再生画面の右上（吹き出しのボタン）で、全文の日本語訳を英文の下に表示できるようにした（iOS 18 以上の翻訳機能 `TranslationSession` でまとめて訳す、`TranscriptTranslation`）。訳は文ごとに保存し、スクリプトの共有・コピーにも入る。初回は翻訳データのダウンロードを iPhone が尋ねる

## 2026-11-03 配信で英語：動画で Q&A

- 再生画面右上のメニュー →「動画で Q&A」で、文字起こしをもとに 要約・英語の4択クイズ・質問（チャット）ができる（`PCIeStudy/Views/English/ClipQAView.swift`）
- AI は iPhone 内の Apple Intelligence（Foundation Models、iOS 26 以上）。通信も料金もかからない（従量課金の API は使わない方針のため）。Apple Intelligence に対応していない iPhone や、オフのときは理由を表示する
- AI が一度に読める量（約4000トークン）に合わせ、文字起こしは先頭から約7000文字まで渡す。長い動画はどこまで使ったかを表示する
- 答えに出てくる時刻 [分:秒] はボタンになり、タップするとその位置から再生する

## 2026-11-03 配信で英語：流れている曲を調べる

- 再生画面右上のメニュー（文字起こし前はカードのボタン）→「流れている曲を調べる」で、ShazamKit で曲名・アーティスト・ジャケットを表示（`PCIeStudy/Models/SongFinder.swift`、`PCIeStudy/Views/English/SongListView.swift`）
- 20秒ごとに10秒ずつ切り出して照合し（ShazamKit は12秒を超える音声を受け付けない）、同じ曲が続くときは最初の時刻だけ残す。時刻をタップでその場面から再生、Apple Music で開く、Spotify は曲名とアーティストで検索した画面を開く（ShazamKit は Spotify の ID を返さない）、歌詞は Web 検索
- ShazamKit は App Service なので、Apple Developer の Identifiers で、アプリ本体の App ID（Study、`com.marugenyori.study`）の「App Services」タブで ShazamKit を有効にした（ウィジェットは不要）。App Store Connect API の capabilityType には ShazamKit がないため、API（`enable-capability.yml`）では設定できない

## 2026-11-03 配信で英語：South Park 公式の動画と字幕ファイル

- 「配信で英語」に「South Park 公式」を追加。YouTube の公開 RSS フィードで公式チャンネルの新着15本を表示する（`YouTubeFeed.swift`、`SouthParkListView.swift`）。チャンネル ID は @southpark のページから読み取り、読めなければ `UC7R27sAWc_DqOldtI1JcYhQ` を使う（クラウドからは YouTube に接続できず、ID は実機で未確認）
- 「PC で保存して取り込む」：アプリが PC の server.py に URL を送り、PC の yt-dlp が動画と英語字幕を保存して、アプリが受け取る（`PCVideoFetcher.swift`）。アプリの中では YouTube から直接保存しない。PC 側は `docs/PC_YOUTUBE_SERVER.md` の依頼文で、PC の Claude Code に追加してもらう
- 字幕ファイル（.srt / .vtt）を文字起こしの代わりに使えるようにした（`SubtitleParser.swift`）。「ファイルから取り込む」で動画と同じ名前の字幕を一緒に選ぶか、再生画面のメニュー →「字幕ファイルを読み込む」。YouTube の自動字幕で同じ行が重なる分は飛ばす
- 実機で「com.apple.ShazamCore エラー102」になったため、署名の作り方を変えた：`SHSignatureGenerator.signature(from: AVAsset)` をやめ、AVAssetReader で 44.1kHz・モノラルの PCM に変えて `SHSignatureGenerator.append` に渡す。エラー表示は「署名の作成」と「照合」のどちらで失敗したかと、エラーのドメイン・番号を出す
- 実機で South Park の一覧が出なかった（YouTube の公開 RSS フィードがエラーを返す）。PC の server.py に yt-dlp で一覧を返す `GET /api/youtube/channel` を足してもらい、アプリは PC を優先、だめなら RSS を使うようにした。失敗したときは PC と RSS それぞれの理由を表示する

## 2026-11-03 英語で聞く：スライド

- レッスンの最初のステップに「スライド」を追加。読み上げに合わせて、いま話している文の内容を図で見せる（`PCIeStudy/Views/English/EnglishSlides.swift`、`SlideStepView`）
- 図はレッスンごとに1枚（3つの層、木構造、TLP とリクエスト、再送バッファ、クレジット、レーンと符号化、LTSSM、コンフィグ空間、MSI、PAM4 とフリット）で、文ごとに関係する部分を強調し、ひとことの説明を出す
- 読み上げが次の文に進むとスライドもめくれる。左右のスワイプ・ボタンでも切り替えられ、再生中に切り替えるとそこから読み直す
- 図の数値は、レッスンの英文にある数値だけを使った（仕様書との照合は英文と同じく未確認）

## 2026-11-03 質問する：仕様書・Apple AI・Claude Code

- 「仕様書に質問」を「質問する」にして、相手を選べるようにした（入力欄の上の切り替え）
  - 仕様書（PC）：今までどおり PC の RAG
  - Apple AI：iPhone 内の Apple Intelligence（iOS 26 以上、`AppleAIConversation.swift`）。会話を覚えて続けて聞ける。PC なし・外出先でも使える
  - Claude Code：質問を入れた Claude Code の新しいセッションを開く（`ClaudeCodeRequestView.sessionURL`、送信は自分で押す）
- 答えの下の「ほかにも聞く」で、同じ質問をほかの相手にも聞いて見比べられる

## 2026-11-03 ブラウザ版との同期（アプリ側）

- PC のサーバの GET/PUT /api/sync を通して、ブラウザ版と記録を同期する（`SyncClient.swift`、形は `SyncDocument.swift` と `docs/SYNC.md`）
- アプリを開いたときと閉じたとき、仕様書QAの接続設定の「今すぐ同期」で同期する。PC につながらないときは何もしない
- 同期するもの：章の読了・クイズの最高点・回答数・XP・苦手リスト・英語レッスンの完了・日ごとの学習量・連続日数・目標、配信で英語の動画（ファイル以外）・フレーズ帳
- 消した動画・フレーズは「消した」という印を残して、ほかの端末からも消す。苦手リストと1日の目標は更新日時を持ち、新しいほうを使う
- ブラウザ版で取り込んだ動画は、iPhone ではスクリプトだけ入る。PC で保存した YouTube の動画（`youtubeID` あり）は「PC から動画を受け取る」で取り込める
- 注意：「記録をリセット」しても、次の同期で PC の記録が戻ってくる（合わせる・大きいほうを使うきまりのため）
- 章・クイズ・英語レッスンのデータは、ブラウザ版用に `web/content.json` へ書き出す（`scripts/export/main.swift`、`.github/workflows/export-content.yml`）

## 2026-11-03 ブラウザ版（Surface）

- `web/`（index.html・style.css・app.js、ビルド不要）。PC の server.py が `/app/` で配り、Surface では http://localhost:8765/app/ を開く
- 学ぶ（章）・クイズ（ランダム10問・苦手・全問・章ごと）・英語で聞く（ブラウザの音声合成。Edge の Natural の声）・配信で英語（PC で保存した動画の再生、スクリプト、1文くり返し・1文ずつ止める・速さ、フレーズ保存、ブラウザの翻訳機能があれば日本語訳）・フレーズ帳
- 記録は `/api/sync` で iPhone と同期（混ぜ方は iPhone と同じ。docs/SYNC.md）。ページに戻ってきたときにも読み直す
- 英語で聞くのスライド、仕様書への質問、曲を調べる、文字起こしは、まだブラウザ版にない（文字起こし・曲・訳は iPhone で作ると同期される）
- 動作確認：クラウドで仮のサーバ（/api/sync と youtube_library だけ）と仮の content.json を作り、Chromium で全画面を開いて、クイズ・読了・フレーズ保存・PC の動画の取り込みが記録に入ることを確かめた

## 2026-11-03 配信で英語：消音モードで音が出ない

- 再生画面の AVPlayer は、音声の設定（AVAudioSession）が初期のままだと、消音モード（サイレントスイッチ）のときに無音になる。再生画面を開いたときに `.playback`・`.moviePlayback` にした（英語で聞くの読み上げは前から `.playback`）
- 動画に音声トラックがないとき（PC での保存で映像だけになったときなど）は、再生画面に「音声が入っていません」と出す

## 2026-11-03 PC の AI の声（Kokoro）で読み上げる

- 読み上げを、PC の server.py の音声合成（Kokoro、`GET /api/tts`・`/api/tts/voices`、docs/PC_TTS.md）で行えるようにした。PC 側は依頼文で PC の Claude Code に追加してもらう
- iPhone（`SpeechPlayer.swift`）：「英語で聞く」の設定「PC の AI の声を使う」（初期はオン）。PC と同じ Wi‑Fi のときは PC の声、つながらないとき・PC にない発音（インド・オーストラリア）は iPhone の声。PC の声が使えなかったら残りの文は iPhone の声で読み、1分間は PC を試さない。次の文の音声は、今の文を読んでいるあいだに作っておく
- ブラウザ版：PC の声があれば声の一覧の先頭に出して初期にする。使えなければブラウザの声に切り替える
- 動作確認：仮のサーバ（短い無音の WAV を返す）で、ブラウザ版のレッスンが PC の声で1文ずつ最後まで進むことを確かめた

## 2026-11-03 ブラウザ版をアプリと同じ機能にする

- 今日（連続日数の4週間の表・1日の目標・今日の1問・デイリークエスト・レベルの称号・今日のコラム・ニュース・実績）、学ぶ（コラム・用語集・ニュース）、クイズ（レベル別・サバイバル・解説の下から Claude Code に質問・作り直しの依頼）、図解5つ、ツール4つ、英語で聞く（スライド・書き取り）、質問する（仕様書・PC の AI・Claude Code）、表示の設定（テーマ色・文字の大きさ・外観）を追加（`web/extra.js`・`web/visual.js`）
- 図解・ツールの数値は、アプリと同じデータを content.json に書き出して使う（TLP ヘッダ・Fmt/Type の読み方・LTSSM・世代ごとの速度・トポロジの例・ゲームのきまり）。トポロジの例は `PCIeStudy/Data/TopologyData.swift` に移した
- iPhone だけの機能は PC の AI で代わりにする（`web/clipextra.js`、PC 側は docs/PC_WEB_EXTRAS.md）：文字起こし（Whisper）、動画で Q&A・質問（Ollama）、翻訳（ブラウザの翻訳機能がすぐ使えなければ Ollama）、PC の動画ファイルの取り込み
- ブラウザ版にないもの：曲を調べる（ShazamKit は iPhone だけ。iPhone で調べた結果は同期される）、ウィジェット、通知
- 書き出しのワークフローは、動かしたブランチに content.json を入れるようにした（ブランチで試せる）
- 動作確認：仮のサーバで全画面を開いてエラーがないこと、帯域（Gen5 x16 = 63.02 GB/s）・ECAM・BAR の計算、ACK/NAK の動き、取り込み→文字起こし→要約・クイズ・質問・翻訳の流れを Chromium で確かめた

## 2026-11-03 英語で聞くを充実させる

- レッスンを 10 → 34 本に（`EnglishData+More.swift`）。残りの章（PCIe とは・世代・電源・順序・エラー・QoS・SR-IOV・イコライゼーション・MPS）と、PCIe 7.0 の新機能（128 GT/s の信号・EQ の順番・送受信のイコライザ・プリコーディング・半フリットの TLP 数・レジスタ・6.x の機能）、6.x・仮想化・割り込みの残り（フリット・L0p・CXL・IOMMU/ATS/ACS・ARI・MSI-X・ウェイク）。英文は各章の内容（仕様書と照合済み）から書き下ろしたが、英文そのものの照合はまだ。一覧は章の順
- 追加のレッスンのスライドは、箱と矢印の並びのデータ（`PCIeStudy/Data/EnglishSlideData.swift`）にして、iPhone とブラウザ版（content.json の englishSlides）で同じものを出す
- 読み上げの書き換えに略語を追加（SR-IOV・ASPM・AER・L0s・D3cold・CXL.io・PASID など。長いものを先に置き換える）
- レッスンに「質問」ステップを追加。iPhone は Apple Intelligence にレッスンの英文を渡して答えさせ、Claude Code・仕様書にも聞ける。ブラウザ版は PC の AI
- スピーカーのボタンを、丸い 44pt 以上のボタンにした（`SpeakerIcon`）。ブラウザ版も 46px の丸
- 戻りやすく：同じタブをもう一度押すとそのタブのいちばん上に戻る（`ContentView` の tabSelection、`AppTab.swift` の goToTabRoot）。レッスンの右上の「移動」から、ステップ・前後のレッスン・すべてのレッスン・英語で聞くの一覧・学ぶのトップ・今日へ。画面の下に前後のレッスンのボタン。ブラウザ版は画面左下に「戻る」「今日」、レッスンの下に前後・一覧・ほかのレッスンへ
- PCIe ニュースを英語で聞く（`NewsEnglishView.swift`）：ニュースの「英語で聞く」から。news.json に titleEn・summaryEn があればそれを、なければ iPhone の翻訳（iOS 18 以上）で日本語から英語にして保存。1文ずつ読み上げる。ブラウザ版はブラウザの翻訳機能か PC の AI

## 2026-11-03 PC の声を iPhone に保存する

- PC の AI の声（Kokoro）で作った音声を、iPhone の Application Support/PCVoice に保存する（`VoiceCache.swift`）。声・速さ・読み上げる文の組ごとに1ファイル
- 「英語で聞く」の音声の設定に「PC の声をダウンロード（家の外でも使う）」：まだ完了していないレッスンの英文・単語・問題と読み方の一覧を、今の発音・速さで PC に作ってもらって保存する（`VoiceDownloader`。完了したレッスンは入れない）。止める・削除・容量の表示つき
- ふだん PC の声で聞いた音声も自動で保存する。読む文がすべて保存してあれば、PC につながらなくても PC の声で読む
- 小さく保存するため `format=m4a` を頼む（PC が対応していなければ WAV のまま。PC 側の追加の依頼文は docs/PC_TTS.md）

## 2026-11-03 ニュースの自動更新を早く

- アプリを開いたとき・ニュース一覧を開いたときの読み込みを、3時間に1回まで → 10分に1回までにした（下に引っぱると今までどおりすぐ読み込む）
- アプリを閉じているあいだも、iPhone のバックグラウンド更新（BGAppRefreshTask、`pciestudy.news-refresh`）でニュースを読み込み、ウィジェットにも反映する。実行の時刻は iPhone が使い方に合わせて決める（最短でも2時間おき）。Info.plist に BGTaskSchedulerPermittedIdentifiers と UIBackgroundModes（fetch）を追加
- 週次のニュース更新の Routine は、リポジトリを付けた専用のセッション（「PCIeニュースの週次更新（リポジトリ付き）」）で動くように作り直した。前の Routine は push の権限がなく、追加したニュースが毎回失われていた（無効にした）

## 2026-11-03 ブラウザ版の見た目を作り直す

- 広い画面は左にメニュー（今日・学ぶ・英語・そのほかに分けて、アイコンつき）、狭い画面は下にタブ（今日・章・クイズ・英語で聞く・質問）と開け閉めできるメニュー
- 上の帯に「戻る」と今いる場所の名前。浮いていた「戻る」「今日」のボタンはやめた
- カード・ボタン・選択肢を、アプリの「ポップ」と同じ縁取りと厚みのある見た目にした。クイズの選択肢に A・B・C・D の印
- 4週間の記録を小さな四角に。メニューの下に同期の状態（緑＝同期済み、橙＝できない）
- 色と文字をアプリの初期設定に合わせた：ライム（#58cc02）・白い背景（ダークはアプリのポップのダーク #131f24）・丸い文字（M PLUS Rounded 1c、読めないときは端末の丸ゴシック）。メニューの項目ごとに色のついた四角のアイコン。今日のいちばん上に、ライムの帯で大きな連続日数と目標。設定の初期のテーマ色もライムに
