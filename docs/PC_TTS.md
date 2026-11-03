# PC 側：AI の音声合成（Kokoro）で英文を読む

「英語で聞く」などの読み上げを、iPhone やブラウザの声より自然にするため、PC の server.py（PCIe_RAG）で
**Kokoro**（無料で公開されている AI の音声合成。英語がとても自然で、ふつうの PC の CPU でも動く）を動かし、音声を返す。

- iPhone アプリ：PC と同じ Wi‑Fi のときは PC の声で読み、つながらないときは iPhone の声で読む（`PCIeStudy/Models/SpeechPlayer.swift`）
- ブラウザ版：PC の声があれば最初からそれを選ぶ（`web/app.js` の `speech`）
- 料金はかからず、英文はネットに送らない

## API

| メソッド | パス | 中身 |
|---|---|---|
| GET | `/api/tts/voices` | 使える声 `{"voices": [{"id": "af_heart", "label": "Heart（アメリカ・女性）", "accent": "us"}, …], "default": "af_heart"}` |
| GET | `/api/tts?text=…&voice=af_heart&speed=1.0` | 英文を読んだ音声（WAV、`audio/wav`） |

- 声：アプリは アメリカ = `af_heart`、イギリス = `bf_emma` を使う。少なくともこの2つは返す（ほかに `am_michael`、`bm_george` なども一覧に入れてよい）
- speed：0.5〜2.0（アプリは 0.8 / 1.0 / 1.15）
- text は 600 文字まで（超えたら 400）
- 同じ voice・speed・text の音声は `tts_cache/` に保存して、2回目からはすぐ返す（レッスンの英文は毎回同じ）

## 依頼文（PC の Claude Code に、PCIe_RAG のフォルダで貼る）

```
server.py に、英文を AI の音声合成で読み上げた音声を返す API を追加してください。
仕様は marugenyori/pcie_study リポジトリの docs/PC_TTS.md の「API」のとおりです。

- 音声合成は Kokoro（pip の kokoro パッケージ、KPipeline。af_/am_ の声は lang_code "a"、bf_/bm_ の声は "b"）。サンプリング周波数 24000 Hz の WAV で返す
- 必要なもの：pip install kokoro soundfile、Windows では espeak-ng（知らない単語の読みに使う）。入っていなければ入れる
- モデルはサーバの起動時に裏で読み込んでおき、読み込み中に頼まれたら 503 を返す
- 音声を作る処理は一度に1つずつ（ロックする）。作った音声は tts_cache/<ハッシュ>.wav に保存し、同じ頼みはそれを返す
- GPU があれば使い、なければ CPU で動かす
- できたら、サーバを起動し直して、PowerShell から
  curl "http://localhost:8765/api/tts?text=The%20Data%20Link%20Layer%20replays%20the%20TLP.&voice=af_heart&speed=1.0" -o test.wav
  を実行し、test.wav を再生して自然に聞こえることを確かめる。1文を作るのにかかった秒数も教えて
```
