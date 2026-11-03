// 「配信で英語」の、PC の力を使う機能（ブラウザ版）
//
// - PC の動画ファイルを取り込む（PC のサーバに送って youtube_library に入れる）
// - PC で文字起こし（Whisper）… iPhone の音声認識の代わり
// - 動画で Q&A（要約・クイズ・質問）… iPhone の Apple Intelligence の代わりに PC の AI（Ollama）
// PC 側の API は docs/PC_WEB_EXTRAS.md
"use strict";

/** PC の AI に聞いて、答えを少しずつ受け取る（1行に1つの JSON。/api/ask と同じ形） */
async function llmChat(messages, { system, format, onToken } = {}) {
  const res = await fetch("/api/llm/chat", {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ messages, system, format }),
  });
  if (!res.ok) throw new Error(res.status === 404 ? "PC のサーバが PC の AI に未対応です（docs/PC_WEB_EXTRAS.md の準備が必要）" : `HTTP ${res.status}`);
  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "", text = "";
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split("\n");
    buffer = lines.pop();
    for (const line of lines) {
      if (!line.trim()) continue;
      let ev;
      try { ev = JSON.parse(line); } catch (_) { continue; }
      if (ev.type === "token") { text += ev.t; if (onToken) onToken(text); }
      else if (ev.type === "error") throw new Error(ev.message);
    }
  }
  return text;
}

/** AI に渡す文字起こし（アプリの ClipContext と同じ形。長いときは先頭から） */
function clipTranscript(clip, limit = 12000) {
  let total = 0;
  const rows = [];
  for (const l of clip.lines || []) {
    const row = `[${formatTime(l.start)}] ${l.text}`;
    total += row.length + 1;
    if (total > limit) break;
    rows.push(row);
  }
  return rows.join("\n");
}
const clipSystem = (clip) => `あなたは、日本人の英語学習を手伝う先生です。
以下は、英語の配信動画を文字起こししたものです。各行の先頭は動画の時刻 [分:秒] です。
音声認識なので、聞き間違いが含まれることがあります。
文字起こしに書かれていることだけをもとに答え、書かれていないことは「動画では触れていません」と答えてください。
説明は日本語で、根拠になる英文を引用するときは、その行の時刻 [分:秒] も書いてください。

--- 文字起こし ---
${clipTranscript(clip)}`;

/** 答えの中の [1:05] を、押すとその場面から再生するボタンにする */
const withTimeButtons = (text) => md(text).replace(/\[(\d+):(\d{2})\]/g, (m, mm, ss) =>
  `<button class="btn small" data-seek="${Number(mm) * 60 + Number(ss)}">▶ ${mm}:${ss}</button>`).replace(/\n/g, "<br>");

// MARK: - 一覧：PC の動画ファイルを取り込む

window.clipsHomeExtraHTML = () => `
  <div class="card">
    <b>PC の動画ファイルを取り込む</b>
    <div class="row" style="margin-top:8px"><input type="file" id="upload" accept="video/*,audio/*"><span id="up-status" class="muted small"></span></div>
    <p class="muted small">OBS などで録画した動画を選ぶと、PC のサーバに保存して一覧に入れます。そのあと「PC で文字起こし」でスクリプトを作れます。iPhone でも「PC から動画を受け取る」で見られます。</p>
  </div>`;

window.clipsHomeExtraBind = () => {
  const input = document.getElementById("upload");
  if (!input) return;
  input.onchange = async () => {
    const file = input.files[0];
    if (!file) return;
    const status = document.getElementById("up-status");
    status.textContent = "PC に送っています…";
    try {
      const res = await fetch(`/api/library/upload?${new URLSearchParams({ filename: file.name })}`, { method: "POST", body: file });
      if (!res.ok) throw new Error(res.status === 404 ? "PC のサーバが取り込みに未対応です（docs/PC_WEB_EXTRAS.md の準備が必要）" : `HTTP ${res.status}`);
      const video = await res.json();
      const id = await addLibraryVideo({ id: video.id, title: video.title || file.name.replace(/\.[^.]+$/, ""), hasSubtitles: false });
      location.hash = `#/clip/${id}`;
    } catch (e) {
      status.textContent = `取り込めませんでした：${e.message}`;
    }
  };
};

// MARK: - 再生画面：PC で文字起こし・動画で Q&A

window.clipExtrasHTML = (id, clip) => `
  <h2>PC の AI で</h2>
  <div class="card">
    <div class="row">
      ${clip.youtubeID ? `<button class="btn" id="transcribe">${clip.lines?.length ? "PC で文字起こしをやり直す" : "PC で文字起こし"}</button>` : ""}
      ${clip.lines?.length ? `<button class="btn" data-qa="summary">要約</button><button class="btn" data-qa="quiz">クイズを作る</button>` : ""}
      <span id="tr-status" class="muted small"></span>
    </div>
    <div id="qa-out"></div>
    ${clip.lines?.length ? `<div class="row" style="margin-top:8px"><input type="text" id="qa-input" placeholder="動画について質問（例：この配信者は何の話をしている？）">
      <button class="btn primary" id="qa-send">質問</button></div><div id="qa-chat"></div>` : ""}
    <p class="muted small">PC の AI（文字起こしは Whisper、質問は Ollama）を使います。料金はかからず、ネットにも送りません。曲を調べる機能はブラウザ版にはありません（iPhone で調べると、ここにも出ます）。</p>
  </div>`;

window.clipExtrasBind = (id, clip, video) => {
  const seekButtons = (root) => root.querySelectorAll("[data-seek]").forEach((b) => {
    b.onclick = () => { if (video) { video.currentTime = Number(b.dataset.seek); video.play(); } };
  });

  const transcribe = document.getElementById("transcribe");
  if (transcribe) {
    transcribe.onclick = async () => {
      const status = document.getElementById("tr-status");
      transcribe.disabled = true;
      status.textContent = "PC で文字起こし中…";
      try {
        const res = await fetch("/api/transcribe", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ id: clip.youtubeID }) });
        if (!res.ok) throw new Error(res.status === 404 ? "PC のサーバが文字起こしに未対応です（docs/PC_WEB_EXTRAS.md の準備が必要）" : `HTTP ${res.status}`);
        const { job } = await res.json();
        for (;;) {
          await new Promise((r) => setTimeout(r, 2000));
          const st = await (await fetch(`/api/transcribe/jobs/${job}`)).json();
          if (st.state === "error") throw new Error(st.error || "文字起こしに失敗しました");
          if (st.state === "done") {
            clip.lines = st.lines.map((l) => ({ id: uuid(), start: l.start, end: l.end, text: l.text.trim() }));
            clip.updatedAt = now();
            save();
            clipPlayer(id);
            return;
          }
          status.textContent = `PC で文字起こし中… ${Math.round((st.progress || 0) * 100)}%`;
        }
      } catch (e) {
        status.textContent = e.message;
        transcribe.disabled = false;
      }
    };
  }

  const out = document.getElementById("qa-out");
  document.querySelectorAll("[data-qa]").forEach((b) => {
    b.onclick = async () => {
      b.disabled = true;
      out.innerHTML = `<p class="muted small">PC の AI が考えています…</p>`;
      try {
        if (b.dataset.qa === "summary") {
          await llmChat([{ role: "user", content: "この動画の内容を、日本語で3〜5行に要約してください。そのあとに「覚えたい表現」として、動画に出てくる英語の表現を3つ選び、それぞれ英文・意味・時刻 [分:秒] を書いてください。" }],
            { system: clipSystem(clip), onToken: (t) => { out.innerHTML = `<div class="note">${withTimeButtons(t)}</div>`; seekButtons(out); } });
        } else {
          const text = await llmChat([{ role: "user", content: `この動画の内容について、聞き取れたかを確かめる英語の4択クイズを4問作ってください。
次の JSON だけを返してください：{"questions":[{"question":"英語の質問","choices":["A","B","C","D"],"answer":0,"explanation":"日本語の解説と根拠の時刻 [分:秒]"}]}` }],
            { system: clipSystem(clip), format: "json" });
          const json = JSON.parse(text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1));
          const qs = (json.questions || []).filter((q) => Array.isArray(q.choices) && q.choices[q.answer] !== undefined);
          if (!qs.length) throw new Error("うまく問題を作れませんでした。もう一度試してください。");
          out.innerHTML = qs.map((q, qi) => `<div class="card" data-q="${qi}"><b>Q${qi + 1}. ${esc(q.question)}</b>
            ${q.choices.map((c, ci) => `<button class="choice" data-c="${ci}">${esc(c)}</button>`).join("")}<div class="after"></div></div>`).join("");
          out.querySelectorAll("[data-q]").forEach((card) => {
            const q = qs[Number(card.dataset.q)];
            card.querySelectorAll(".choice").forEach((c) => {
              c.onclick = () => {
                const chosen = Number(c.dataset.c);
                card.querySelectorAll(".choice").forEach((x) => {
                  const ci = Number(x.dataset.c);
                  x.disabled = true;
                  x.classList.add(ci === q.answer ? "correct" : ci === chosen ? "wrong" : "dimmed");
                });
                card.querySelector(".after").innerHTML = `<p class="small">${withTimeButtons(q.explanation || "")}</p>`;
                seekButtons(card);
              };
            });
          });
        }
      } catch (e) {
        out.innerHTML = `<p class="small" style="color:var(--bad)">${esc(e.message)}</p>`;
      }
      b.disabled = false;
    };
  });

  const send = document.getElementById("qa-send");
  if (send) {
    const history = [];
    const chat = document.getElementById("qa-chat");
    const ask = async () => {
      const input = document.getElementById("qa-input");
      const question = input.value.trim();
      if (!question) return;
      input.value = "";
      history.push({ role: "user", content: question });
      const box = document.createElement("div");
      box.innerHTML = `<div class="bubble user">${esc(question)}</div><div class="note">…</div>`;
      chat.appendChild(box);
      const answer = box.querySelector(".note");
      try {
        const text = await llmChat(history, { system: clipSystem(clip), onToken: (t) => { answer.innerHTML = withTimeButtons(t); } });
        history.push({ role: "assistant", content: text });
        seekButtons(answer);
      } catch (e) {
        history.pop();
        answer.innerHTML = `<span style="color:var(--bad)">${esc(e.message)}</span>`;
      }
    };
    send.onclick = ask;
    document.getElementById("qa-input").onkeydown = (e) => { if (e.key === "Enter") ask(); };
  }
};
