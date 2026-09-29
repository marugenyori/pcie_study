# GitHub Actions で iOS 版をビルドする

このリポジトリには、PCIe学習アプリ（iOS / SwiftUI）と、macOS 上でビルドする GitHub Actions の設定（`.github/workflows/ios-build.yml`）が入っています。Mac は不要です。

## 1. ファイルをリポジトリに入れる

Windows なら **GitHub Desktop** がいちばん確実です（`.github` フォルダも漏れずに入ります）。

1. GitHub Desktop で `marugenyori/claud_code` を Clone する
2. zip を解凍し、中身（`.github`、`PCIeStudy`、`PCIeStudy.xcodeproj`、`.gitignore`、この README）をクローンしたフォルダにそのままコピーする
3. GitHub Desktop で Commit to **main** → Push origin

> ブラウザの「Add file → Upload files」を使う場合、`.github` フォルダが取り込まれないことがあります。そのときは Actions タブ →「set up a workflow yourself」を開き、`ios-build.yml` の中身を貼り付けて保存してください。

## 2. ビルドを確認する（Apple のアカウントは不要）

- push すると自動でビルドが始まります。手動で動かすときは **Actions → iOS Build → Run workflow**
- 終わったら実行結果のページを開くと、**「ビルド結果」** にエラーの一覧が出ます
  - エラーがあれば、その一覧をそのまま Claude に貼ってください。修正版を用意します
  - 「✅ ビルド成功」と出れば、コンパイルは通っています
- 詳しいログは、同じページ下部の **Artifacts → build-log** からダウンロードできます

非公開リポジトリの無料枠は月 2,000 分ですが、macOS は Linux の約10倍の速さで消費します（目安で月 200 分ほど）。1回のビルドは数分〜10分程度です。

## 3. iPhone に入れる（TestFlight・任意）

有料の **Apple Developer Program** への登録が必要です。

1. **Bundle ID を登録**：developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → ＋ → App IDs。例：`com.marugenyori.pciestudy`（世界で一意の文字列）
2. **App を作成**：App Store Connect → マイApp → ＋ → 新規App。プラットフォーム iOS、上の Bundle ID を選ぶ
3. **API キーを作成**：App Store Connect → ユーザとアクセス → 統合 → App Store Connect API → キーを生成（アクセスは **Admin**。自動署名で証明書を作るため）
   - `.p8` ファイルをダウンロード（1回しかダウンロードできません）
   - **Key ID** と **Issuer ID** を控える
4. **Team ID を確認**：developer.apple.com → Account → Membership details
5. **GitHub に Secrets を登録**：リポジトリの Settings → Secrets and variables → Actions → New repository secret

   | 名前 | 値 |
   |---|---|
   | `APPLE_TEAM_ID` | Team ID（10文字） |
   | `BUNDLE_ID` | 手順1の Bundle ID |
   | `ASC_KEY_ID` | API キーの Key ID |
   | `ASC_ISSUER_ID` | Issuer ID |
   | `ASC_KEY_P8` | `.p8` ファイルの中身をすべて（`-----BEGIN PRIVATE KEY-----` から `-----END PRIVATE KEY-----` まで） |

6. **実行**：Actions → iOS Build → Run workflow →「TestFlight にアップロードする」にチェック → Run
7. **iPhone に入れる**：App Store Connect の TestFlight タブで、自分を「内部テスター」に追加 → iPhone に TestFlight アプリを入れて招待を受ける

ビルド番号は Actions の実行番号が自動で使われるので、毎回そのまま実行できます。

## 注意

- iOS 版はまだ一度もビルドしていないため、最初はコンパイルエラーが出る可能性があります
- iOS 版には、Web 版に最近追加した機能（選択肢ごとの解説、苦手リスト、マスコットなど）はまだ入っていません
- `.p8` ファイルは GitHub の Secrets 以外（リポジトリの中など）に置かないでください
