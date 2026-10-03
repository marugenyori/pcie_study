# iPhone から新しい iOS アプリを作る手順

Mac も PC も使わず、iPhone だけで「作る → ビルド → TestFlight で自分の iPhone に入れる」までを行う手順です。
このリポジトリ（`claud_code`）で実際にうまくいった方法をもとにしています。

## 全体の流れ

```
iPhone の Claude（Code）でコードを書く
  → GitHub に push
  → GitHub Actions（macOS）がビルドして TestFlight にアップロード
  → iPhone の TestFlight アプリでインストール
```

## 0. 準備（最初の1回だけ）

- iPhone に **Claude** アプリと **TestFlight** アプリを入れる（GitHub アプリもあると便利）
- Claude アプリで Code を開き、GitHub と連携する。Claude が読み書きできるリポジトリに `claud_code` と新しいリポジトリを含める
- App Store Connect API キーの **`.p8` ファイル**を、iPhone の「ファイル」アプリ（iCloud Drive）に保存しておく。新しいリポジトリの Secrets に貼るときに使う
  - `.p8` は1回しかダウンロードできません。なくした場合は、App Store Connect で新しいキーを作ってください

## 1. GitHub に新しいリポジトリを作る

GitHub アプリまたは Safari で github.com を開き、**New repository** から作成します。
- 名前：アプリ名（例：`habit-timer`）
- **Private** を選ぶ

## 2. Apple 側でアプリを登録する（Safari で操作）

1. developer.apple.com → Identifiers → ＋ → App IDs → App
   - Bundle ID：`com.marugenyori.（アプリ名）`（例：`com.marugenyori.habittimer`）
2. ウィジェットや App Group を使う場合だけ、次の3つも行う
   - Identifiers → ＋ → App Groups → `group.（Bundle ID）` を作る
   - 最初の TestFlight 実行のあと、自動で `（Bundle ID）.widget` の App ID ができる
   - 両方の App ID で App Groups の **Edit → グループにチェック → Save → Confirm**（Confirm まで押さないと保存されない）
3. appstoreconnect.apple.com → アプリ → ＋ → 新規App → 上の Bundle ID を選ぶ

## 3. 新しいリポジトリに Secrets を登録する

リポジトリの Settings → Secrets and variables → **Actions** → New repository secret。Variables ではなく Secrets に登録します。

| 名前 | 値 |
|---|---|
| `APPLE_TEAM_ID` | developer.apple.com 右上に表示される10文字の Team ID（`claud_code` と同じ） |
| `BUNDLE_ID` | 手順2の Bundle ID |
| `ASC_KEY_ID` | `claud_code` と同じ API キーの Key ID |
| `ASC_ISSUER_ID` | `claud_code` と同じ Issuer ID |
| `ASC_KEY_P8` | `.p8` ファイルの中身（`-----BEGIN PRIVATE KEY-----` から `-----END PRIVATE KEY-----` まで全部） |

API キーは、同じ Apple アカウントのアプリならすべてで使い回せます。

## 4. Claude に頼む

Claude（Code）で新しいリポジトリを開き、次のように頼みます。

> `marugenyori/claud_code` の `CLAUDE.md` と `docs/NEW_APP_GUIDE.md` を読んで、同じ仕組み（GitHub Actions でビルドして TestFlight に配信）で新しい iOS アプリを作ってください。
> アプリの内容：（ここに作りたいもの）
> Bundle ID は `com.marugenyori.〇〇` で、Secrets は登録済みです。

### Claude が用意するもの（チェックリスト）

- [ ] `アプリ名/` フォルダに SwiftUI のソース（`@main` の App、画面）と `Assets.xcassets`（AppIcon 1024px、AccentColor）
- [ ] `アプリ名.xcodeproj/project.pbxproj`：`claud_code` と同じ**フォルダ同期方式**（`PBXFileSystemSynchronizedRootGroup`）で作る。iOS 17、`GENERATE_INFOPLIST_FILE = YES`、`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`
- [ ] Bundle ID はビルド設定 `APP_BUNDLE_ID` から作る（`PRODUCT_BUNDLE_IDENTIFIER = "$(APP_BUNDLE_ID)"`）
- [ ] `アプリ名.xcodeproj/xcshareddata/xcschemes/アプリ名.xcscheme`（共有スキーム。これがないと CI でスキームが見つからない）
- [ ] `.github/workflows/ios-build.yml`：`claud_code` のものをコピーし、`PCIeStudy` をアプリ名に置き換える（`paths`、`-project`、`-scheme`、`-archivePath`）
- [ ] `.gitignore`（`build/`、`*.p8` など）
- [ ] `CLAUDE.md`：そのアプリ用の作業メモ（このファイルを参考に）

## 5. ビルドと配信

1. push すると、署名なしのビルドが自動で走る。エラーが出たら、実行結果ページの「ビルド結果」をそのまま Claude に伝える
2. ビルドが通ったら、Actions → iOS Build → Run workflow →「TestFlight にアップロードする」にチェック → Run
3. App Store Connect → そのアプリ → TestFlight → 内部テストのグループを作って自分を追加
4. iPhone の TestFlight アプリからインストール

## よくあるつまずき

| 症状 | 原因と対処 |
|---|---|
| `insufficient indentation of line in multi-line string literal` | `"""` の中の行が、閉じる `"""` より左に出ている |
| `overlapping accesses to 'self.xxx'` | 書き換え中の配列のクロージャから `self` を読んでいる。関数を `static` にする |
| `doesn't match the entitlements file's value for ... application-groups` | App ID に App Group が割り当てられていない（手順2-2）。両方の App ID で Save → Confirm |
| `次の Secrets が未設定です` | Secrets の名前の綴り違い、または Variables に登録している |
| TestFlight にビルドが出てこない | App Store Connect の処理待ち（10〜30分）。メールが届くまで待つ |
| ウィジェットのビルドで Bundle ID が重複 | `PRODUCT_BUNDLE_IDENTIFIER` をコマンドラインで上書きしている。`APP_BUNDLE_ID` を使う |

## 費用の目安

- Apple Developer Program：年額 12,980円（すべてのアプリで共通）
- GitHub Actions：非公開リポジトリは月 2,000分まで無料。macOS は10倍で数えるので、実質 月200分（1回のビルドはおよそ1〜3分、TestFlight 込みで3〜5分）
