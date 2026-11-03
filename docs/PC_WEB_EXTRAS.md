# PC 側：ブラウザ版で、iPhone だけにあった機能を使う

iPhone アプリには、iPhone の中の機能（音声認識・Apple Intelligence・翻訳）を使うものがある。
ブラウザ版では、それを **PC の AI** で行う。料金はかからず、ネットにも送らない。

| iPhone アプリ | ブラウザ版（PC の server.py） |
|---|---|
| 音声認識で文字起こし | Whisper（faster-whisper）で文字起こし |
| Apple Intelligence（質問・動画の要約・クイズ） | Ollama（仕様書QAで使っている AI） |
| iPhone の翻訳 | ブラウザの翻訳機能。なければ Ollama で翻訳 |
| 写真・ファイルから動画を取り込む | PC の動画ファイルをサーバに送って取り込む |
| 曲を調べる（ShazamKit） | なし（iPhone で調べた結果は同期される） |

画面側は `web/extra.js`（質問する）と `web/clipextra.js`（配信で英語）。

## API

| メソッド | パス | 中身 |
|---|---|---|
| POST | `/api/llm/chat` | 本文 `{"messages": [{"role": "user", "content": "…"}], "system": "…（なくてもよい）", "format": "json（なくてもよい）"}`。答えは `/api/ask` と同じ1行1 JSON のストリーム（`{"type":"token","t":"…"}`、最後に `{"type":"done"}`、失敗は `{"type":"error","message":"…"}`） |
| POST | `/api/llm/translate` | 本文 `{"texts": ["文", …], "target": "ja" または "en"}` → `{"translations": ["訳", …]}`（同じ順番・同じ数）。"ja" は英語→日本語（動画のスクリプト）、"en" は日本語→英語（ニュースを英語で聞く） |
| POST | `/api/library/upload?filename=名前.mp4` | 本文は動画ファイルそのもの → `{"id": "up-xxxxxxxx", "title": "名前"}`。youtube_library に入れ、`/api/youtube/library` の一覧にも出す |
| POST | `/api/transcribe` | 本文 `{"id": "<youtube_library の ID>"}` → `{"job": "…"}` |
| GET | `/api/transcribe/jobs/<job>` | `{"state": "queued/running/done/error", "progress": 0〜1, "lines": [{"start": 1.2, "end": 3.4, "text": "…"}], "error": "…"}` |

## 依頼文（PC の Claude Code に、PCIe_RAG のフォルダで貼る）

```
server.py に、ブラウザ版で使う PC の AI の機能を追加してください。
仕様は marugenyori/pcie_study リポジトリの docs/PC_WEB_EXTRAS.md の「API」のとおりです。

1. /api/llm/chat：Ollama の /api/chat に、仕様書QAで使っている既定のモデルで流す（stream）。format が "json" なら Ollama にも format=json を渡す
2. /api/llm/translate：Ollama で訳す（target が "ja" なら英語→日本語、"en" なら日本語→英語）。1回にまとめて頼み、JSON の配列で受け取って、数が合わなければ1文ずつ訳し直す
3. /api/library/upload：受け取った動画を youtube_library/up-<ランダム8文字>.<拡張子> に保存。
   ブラウザと iPhone で再生できない形式（H.264/AAC の mp4 以外）なら、ffmpeg で mp4（H.264・AAC）に変換する。
   2 GB まで。/api/youtube/library の一覧と /video にも出す
4. /api/transcribe：faster-whisper で英語を文字起こし（モデルは small.en から始め、遅すぎなければ medium.en。CPU なら int8、GPU があれば使う。vad_filter を使う）。
   結果は youtube_library/<ID>.transcript.json に保存して、2回目はすぐ返す。1つずつ順番に処理する
5. requirements に faster-whisper を追加
6. できたら、サーバを起動し直して、curl で各 API を試す。10分の動画の文字起こしにかかった時間も教えて
```
