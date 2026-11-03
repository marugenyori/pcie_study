# PC 側：YouTube の動画を保存してアプリに渡す（PCIe_RAG の server.py に追加）

アプリの「配信で英語 → South Park 公式」の「PC で保存して取り込む」は、PC の server.py（仕様書QAサーバ）に YouTube の URL を送り、
PC 上の yt-dlp で動画と英語字幕を保存してもらってから受け取る。PCIe_RAG はこのリポジトリに入っていないので、
**PC の Claude Code で、下の「依頼文」を PCIe_RAG のフォルダで実行して**追加する。

保存した動画は自分の学習用だけに使う（YouTube の利用規約では公式機能以外での保存は禁止されている）。

## API（アプリ側：`PCIeStudy/Models/PCVideoFetcher.swift`）

| メソッド | パス | 中身 |
|---|---|---|
| POST | `/api/youtube/download` | 本文 `{"url": "https://www.youtube.com/watch?v=..."}` → `{"job": "<ID>"}`。すぐ返し、保存は裏で進める |
| GET | `/api/youtube/jobs/<ID>` | `{"state": "queued" / "downloading" / "done" / "error", "progress": 0〜1, "title": "動画の題名", "error": "失敗の理由"}` |
| GET | `/api/youtube/jobs/<ID>/video` | 保存した mp4 |
| GET | `/api/youtube/jobs/<ID>/subtitles` | 英語字幕の srt。ないときは 404 |
| GET | `/api/youtube/channel?handle=southpark&limit=30` | チャンネルの新着動画の一覧 `{"videos": [{"id": "動画ID", "title": "題名", "published": "yyyy-MM-dd または null", "thumbnail": "URL または null"}]}`（新しい順） |

- アプリは 2 秒ごとに状態を読み、`done` になったら video と subtitles を受け取る
- URL は `youtube.com` / `youtu.be` のものだけ受け付ける（ほかは 400）

## 依頼文（PC の Claude Code に貼る）

```
server.py に、iPhone アプリ（marugenyori/pcie_study の PCIeStudy/Models/PCVideoFetcher.swift）から使う
YouTube 保存の API を追加してください。仕様は pcie_study リポジトリの docs/PC_YOUTUBE_SERVER.md のとおりです。

- 既存の server.py と同じ書き方（使っているフレームワーク）に合わせる
- 保存は yt-dlp の Python API（import yt_dlp）で、別スレッドで行う。progress_hooks で進み具合を更新する
- 形式：format "bv*[ext=mp4][height<=720]+ba[ext=m4a]/b[ext=mp4]"、merge_output_format "mp4"
- 字幕：writesubtitles と writeautomaticsub を True、subtitleslangs ["en", "en-US", "en-GB"]、
  postprocessors に FFmpegSubtitlesConvertor（format "srt"）。公式の英語字幕があればそちらを優先する
- 保存先は PCIe_RAG のフォルダの下の youtube_downloads/<job ID>/。終わった job は 1 日たったら消す
- URL は youtube.com / youtu.be だけ受け付ける
- requirements に yt-dlp を追加。ffmpeg が入っていないときは、分かりやすいエラーを返す
- 起動用の bat があれば、yt-dlp を最新にする（pip install -U yt-dlp）手順も足す
- できたら、PowerShell から curl で POST と GET を試して、動画と srt が受け取れることを確かめる
```

## 追加の依頼文：チャンネルの動画一覧（2026-11-03 追加）

YouTube の公開 RSS フィードがエラーを返して、アプリで一覧が出なかったため、PC の yt-dlp で一覧を作る API を足す。

```
server.py に、YouTube チャンネルの新着動画の一覧を返す API を追加してください。
仕様は pcie_study リポジトリの docs/PC_YOUTUBE_SERVER.md の `/api/youtube/channel` の行のとおりです。

- GET /api/youtube/channel?handle=southpark&limit=30
- yt-dlp の Python API で https://www.youtube.com/@<handle>/videos を extract_flat="in_playlist"、playlistend=limit で読む（動画はダウンロードしない）
- 返す形：{"videos": [{"id", "title", "published", "thumbnail"}]}。published は分かるときだけ yyyy-MM-dd（なければ null）、
  thumbnail は一番大きいサムネイルの URL（なければ null）
- handle は英数字・._- だけ受け付ける。limit は 1〜50
- 同じ handle の結果は 30 分覚えておき、その間はすぐ返す（毎回 YouTube に取りに行かない）
- できたら、サーバを起動し直して、PowerShell から curl で southpark の一覧が返ることを確かめる
```
