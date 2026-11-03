# ブラウザ版と iPhone アプリの同期

Surface（PCIe_RAG のサーバを動かしている PC）のブラウザで、アプリと同じ学習ができるようにする。
記録（クイズの成績・連続日数・フレーズ帳・動画のスクリプトなど）は、PC のサーバに置いた1つの JSON を通して、同じ Wi-Fi のときに iPhone と同期する。

## 全体の形

```
iPhone アプリ ──(同じ Wi-Fi)──┐
                              ├─ PC の server.py ── sync_state.json（記録）
Surface のブラウザ ──(localhost)─┘                  youtube_library/（PC で保存した動画と字幕）
                                                   pcie_study/web/（ブラウザ版の画面。git pull で更新）
```

- ブラウザ版の画面は、このリポジトリの `web/`。サーバが `/app/` で配る（Surface では http://localhost:8765/app/ を開く）
- 章・クイズ・英語レッスンのデータは `web/content.json`。アプリのデータ（Swift）から GitHub Actions が自動で作る（`.github/workflows/export-content.yml`）

## サーバの API（PC 側。PCIe_RAG の server.py に追加する）

| メソッド | パス | 中身 |
|---|---|---|
| GET | `/api/sync` | 保存してある記録の JSON。まだなければ `{}` |
| PUT | `/api/sync` | 記録の JSON を丸ごと保存して、そのまま返す（20 MB まで） |
| GET | `/app/...` | `web/` のファイル（ブラウザ版）。`/app/` は `web/index.html` |
| GET | `/api/youtube/library` | PC で保存した YouTube 動画の一覧 `{"videos": [{"id", "title", "hasSubtitles"}]}` |
| GET | `/api/youtube/library/<動画ID>/video` | 保存した mp4（ブラウザで再生できるよう Range 要求に対応する） |
| GET | `/api/youtube/library/<動画ID>/subtitles` | 保存した英語字幕の srt（なければ 404） |

- サーバは記録の中身を解釈しない（置いておくだけ）。混ぜ合わせ（マージ）はアプリとブラウザがする
- アプリ・ブラウザは「GET で読む → 手元の記録と混ぜる → PUT で書く」の順に動く
- `/api/youtube/download` で保存した動画は、1日で消さずに `youtube_library/<動画ID>.mp4` と `.srt` に残す（同じ動画をもう一度頼まれたら保存し直さずにすぐ done にする）

## 記録の JSON

```json
{
  "version": 1,
  "progress": {
    "completedChapters": ["intro", "layers"],
    "quizBest": {"intro": 80, "random": 60},
    "answeredTotal": 120, "correctTotal": 95, "xp": 900,
    "weak": {"value": ["tlp-3"], "updatedAt": "2026-11-03T10:00:00Z"},
    "englishDone": ["en-layers"],
    "dailyCounts": {"2026-11-03": 12},
    "goalMetDays": ["2026-11-03"],
    "bestStreak": 5,
    "dailyGoal": {"value": 5, "updatedAt": "2026-11-01T09:00:00Z"},
    "dailyAnswers": {"2026-11-03": 2},
    "gameBest": {"survival": 14}
  },
  "english": {
    "clips": {
      "<UUID>": {
        "title": "…", "addedAt": "…", "duration": 600.5, "youtubeID": "abc123 または なし",
        "lines": [{"id": "<UUID>", "start": 1.2, "end": 3.4, "text": "…", "japanese": "… または なし"}],
        "songs": [{"id": "<UUID>", "start": 0, "title": "…", "artist": "…", "artworkURL": "…", "appleMusicURL": "…", "webURL": "…"}],
        "updatedAt": "…", "deleted": false
      }
    },
    "phrases": {
      "<UUID>": {"text": "…", "memo": "…", "clipID": "<UUID>", "start": 12.3, "savedAt": "…", "updatedAt": "…", "deleted": false}
    }
  }
}
```

日時はすべて ISO 8601（UTC、秒まで）。

## 混ぜ合わせのきまり（アプリとブラウザで同じにする）

| 項目 | きまり |
|---|---|
| completedChapters・englishDone・goalMetDays | 両方を合わせる（和集合） |
| quizBest・dailyCounts・dailyAnswers・gameBest | キーごとに大きいほう |
| answeredTotal・correctTotal・xp・bestStreak | 大きいほう |
| weak・dailyGoal | updatedAt が新しいほう |
| clips・phrases | ID ごとに updatedAt が新しいほう。消したものは `deleted: true` を残して、ほかの端末にも消したことを伝える |

- 動画ファイルそのものは同期しない。iPhone で取り込んだ動画は、ブラウザではスクリプト・訳・フレーズだけ見られる
- `youtubeID` がある動画（PC で保存したもの）は、ブラウザでは PC の動画を再生でき、iPhone では「PC から動画を受け取る」で取り込める

## PC の Claude Code への依頼文

```
server.py に、ブラウザ版と iPhone アプリの同期のための機能を追加してください。
仕様は marugenyori/pcie_study リポジトリの docs/SYNC.md の「サーバの API」のとおりです。

1. GET/PUT /api/sync：PCIe_RAG フォルダの sync_state.json に保存する。書き込みは一時ファイルに書いてから置き換える（途中で壊れないように）。
   保存の前に、前の版を sync_backups/ に日時付きで残し、30 個を超えたら古いものから消す
2. /app/：pcie_study リポジトリを PCIe_RAG の隣（なければ好きな場所）に git clone し、その web/ フォルダを /app/ で配る。
   /app/ は index.html。キャッシュさせない（Cache-Control: no-cache）
3. start_lan.bat の最初で、pcie_study を git pull して最新のブラウザ版にする（失敗しても起動は続ける）
4. YouTube の保存（/api/youtube/download）は、1日で消さずに youtube_library/<動画ID>.mp4 と .srt に残す。
   同じ動画がすでにあれば、保存し直さずにすぐ done にする
5. GET /api/youtube/library と /api/youtube/library/<動画ID>/video・/subtitles を追加。video は Range 要求に対応する（ブラウザの再生位置の移動のため）
6. スタートメニューかデスクトップに「PCIe学習（ブラウザ）」のショートカット（http://localhost:8765/app/ を開く）を作る
7. できたら、サーバを起動し直して、curl で /api/sync の PUT と GET、/app/ が返ることを確かめる
```
