// PCIe学習 ブラウザ版（Surface の PC のサーバが /app/ で配る）
//
// 章・クイズ・英語レッスンは content.json（アプリのデータから GitHub Actions が作る）、
// 記録はサーバの /api/sync を通して iPhone アプリと同期する（docs/SYNC.md）。
"use strict";

const app = document.getElementById("app");
let content = null;
/** 同期する記録（docs/SYNC.md の形） */
let doc = { version: 1, progress: {}, english: { clips: {}, phrases: {} } };
let serverAvailable = false;

// MARK: - 小さな道具

const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
/** アプリの文章にある **太字** と `コード` だけを HTML にする（ほかはそのまま文字として出す） */
const md = (s) => esc(s).replace(/\*\*(.+?)\*\*/g, "<b>$1</b>").replace(/`([^`]+)`/g, "<code>$1</code>");
const now = () => new Date().toISOString();
const todayKey = (d = new Date()) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
const uuid = () => (crypto.randomUUID ? crypto.randomUUID() : "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
  const r = (Math.random() * 16) | 0;
  return (c === "x" ? r : (r & 3) | 8).toString(16);
})).toUpperCase();
const formatTime = (sec) => {
  const t = Math.max(0, Math.floor(sec || 0));
  return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, "0")}`;
};
const shuffle = (array) => {
  const a = array.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
};
const setSyncStatus = (text) => { document.getElementById("sync-status").textContent = text; };

// MARK: - 同期（アプリの ProgressStore.merge / EnglishStore.merge と同じきまり）

const union = (a = [], b = []) => [...new Set([...a, ...b])].sort();
const maxMap = (a = {}, b = {}) => {
  const out = { ...a };
  for (const [k, v] of Object.entries(b)) out[k] = Math.max(out[k] ?? -Infinity, v);
  return out;
};
const newer = (a, b) => {
  if (!a) return b;
  if (!b) return a;
  return new Date(b.updatedAt) > new Date(a.updatedAt) ? b : a;
};
const byNewest = (a = {}, b = {}) => {
  const out = { ...a };
  for (const [id, item] of Object.entries(b)) out[id] = newer(out[id], item);
  return out;
};

function mergeDocs(local, remote) {
  const l = local.progress || {};
  const r = remote.progress || {};
  const keepFirst = (a = {}, b = {}) => ({ ...b, ...a });
  return {
    version: 1,
    progress: {
      completedChapters: union(l.completedChapters, r.completedChapters),
      quizBest: maxMap(l.quizBest, r.quizBest),
      answeredTotal: Math.max(l.answeredTotal || 0, r.answeredTotal || 0),
      correctTotal: Math.max(l.correctTotal || 0, r.correctTotal || 0),
      xp: Math.max(l.xp || 0, r.xp || 0),
      weak: newer(l.weak, r.weak) || { value: [], updatedAt: new Date(0).toISOString() },
      englishDone: union(l.englishDone, r.englishDone),
      dailyCounts: maxMap(l.dailyCounts, r.dailyCounts),
      goalMetDays: union(l.goalMetDays, r.goalMetDays),
      bestStreak: Math.max(l.bestStreak || 0, r.bestStreak || 0),
      dailyGoal: newer(l.dailyGoal, r.dailyGoal) || { value: 5, updatedAt: new Date(0).toISOString() },
      dailyAnswers: keepFirst(l.dailyAnswers, r.dailyAnswers),
      gameBest: maxMap(l.gameBest, r.gameBest),
    },
    english: {
      clips: byNewest(local.english?.clips, remote.english?.clips),
      phrases: byNewest(local.english?.phrases, remote.english?.phrases),
    },
  };
}

async function pull() {
  try {
    const res = await fetch("/api/sync", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const text = await res.text();
    const remote = text ? JSON.parse(text) : {};
    doc = mergeDocs(doc, remote);
    serverAvailable = true;
    setSyncStatus("iPhone と同期済み");
  } catch (e) {
    serverAvailable = false;
    setSyncStatus("同期できません（PC のサーバが同期に未対応か、止まっています）");
  }
}

let saveTimer = null;
/** 記録を変えたら呼ぶ。少し待ってから、PC の最新と混ぜて書き込む */
function save() {
  try { localStorage.setItem("pcieStudyDoc", JSON.stringify(doc)); } catch (_) { /* 保存できなくても続ける */ }
  clearTimeout(saveTimer);
  saveTimer = setTimeout(async () => {
    await pull();
    if (!serverAvailable) return;
    try {
      const res = await fetch("/api/sync", { method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify(doc) });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setSyncStatus(`同期しました（${new Date().toLocaleTimeString("ja-JP", { hour: "2-digit", minute: "2-digit" })}）`);
    } catch (e) {
      setSyncStatus("PC に書き込めませんでした");
    }
  }, 800);
}

// MARK: - 記録をつける（アプリの ProgressStore と同じ数え方）

const P = () => doc.progress;

function streak() {
  const met = new Set(P().goalMetDays || []);
  const day = new Date();
  if (!met.has(todayKey(day))) day.setDate(day.getDate() - 1);
  let count = 0;
  while (met.has(todayKey(day))) {
    count++;
    day.setDate(day.getDate() - 1);
  }
  return count;
}

const dailyGoal = () => P().dailyGoal?.value || 5;
const todayCount = () => (P().dailyCounts || {})[todayKey()] || 0;

/** 1問答えた（今日の学習量・連続日数に数える） */
function countAnswer() {
  const p = P();
  const key = todayKey();
  p.dailyCounts = p.dailyCounts || {};
  p.dailyCounts[key] = (p.dailyCounts[key] || 0) + 1;
  if (p.dailyCounts[key] >= dailyGoal() && !(p.goalMetDays || []).includes(key)) {
    p.goalMetDays = union(p.goalMetDays, [key]);
    p.bestStreak = Math.max(p.bestStreak || 0, streak());
  }
}

function recordQuizAnswer(questionID, correct, combo) {
  const p = P();
  p.answeredTotal = (p.answeredTotal || 0) + 1;
  const weak = new Set(p.weak?.value || []);
  const wasWeak = weak.has(questionID);
  if (correct) {
    p.correctTotal = (p.correctTotal || 0) + 1;
    weak.delete(questionID);
    p.xp = (p.xp || 0) + 10 + (combo >= 2 ? Math.min(10, (combo - 1) * 2) : 0);
  } else {
    weak.add(questionID);
  }
  if (wasWeak !== weak.has(questionID)) p.weak = { value: [...weak].sort(), updatedAt: now() };
  countAnswer();
  save();
}

const level = (xp) => {
  let lv = 1;
  while (25 * (lv + 1) * lv <= xp) lv++;
  return lv;
};

// MARK: - 画面の切り替え

const routes = [
  [/^#?\/?$/, home],
  [/^#\/chapters$/, chapters],
  [/^#\/chapter\/(.+)$/, chapter],
  [/^#\/quiz$/, quizMenu],
  [/^#\/quiz\/(.+)$/, quizSession],
  [/^#\/english$/, englishHome],
  [/^#\/english\/(.+)$/, englishLesson],
  [/^#\/clips$/, clipsHome],
  [/^#\/clip\/(.+)$/, clipPlayer],
  [/^#\/phrases$/, phraseBook],
];

let cleanup = null;
function render() {
  if (cleanup) { cleanup(); cleanup = null; }
  speech.stop();
  const hash = location.hash || "#/";
  document.querySelectorAll(".topbar nav a").forEach((a) => {
    a.classList.toggle("active", hash.startsWith(a.getAttribute("href")));
  });
  for (const [pattern, view] of routes) {
    const m = hash.match(pattern);
    if (m) {
      window.scrollTo(0, 0);
      view(...m.slice(1).map(decodeURIComponent));
      return;
    }
  }
  app.innerHTML = `<p>ページが見つかりません。<a href="#/">ホームへ</a></p>`;
}

// MARK: - ホーム

function home() {
  const p = P();
  const xp = p.xp || 0;
  const lv = level(xp);
  const done = (p.completedChapters || []).length;
  app.innerHTML = `
    <h1>今日の学習</h1>
    <div class="grid">
      <div class="card"><div class="muted small">連続日数</div><div class="stat">${streak()} 日</div>
        <div class="muted small">最高 ${p.bestStreak || 0} 日</div></div>
      <div class="card"><div class="muted small">今日の問題数</div><div class="stat">${todayCount()} / ${dailyGoal()}</div>
        <div class="progress"><div style="width:${Math.min(100, (todayCount() / dailyGoal()) * 100)}%"></div></div></div>
      <div class="card"><div class="muted small">レベル</div><div class="stat">Lv ${lv}</div>
        <div class="muted small">${xp} XP ・ 正答率 ${p.answeredTotal ? Math.round((p.correctTotal / p.answeredTotal) * 100) : 0}%</div></div>
      <div class="card"><div class="muted small">読んだ章</div><div class="stat">${done} / ${content.chapters.length}</div></div>
    </div>
    <h2>続ける</h2>
    <div class="grid">
      <a class="card" href="#/quiz/random10"><b>ランダム10問</b><div class="muted small">全範囲から</div></a>
      <a class="card" href="#/quiz/weak"><b>苦手を復習</b><div class="muted small">${(p.weak?.value || []).length} 問</div></a>
      <a class="card" href="#/english"><b>英語で聞く</b><div class="muted small">PCIe を英語で</div></a>
      <a class="card" href="#/clips"><b>配信で英語</b><div class="muted small">動画のスクリプトで練習</div></a>
    </div>
    <p class="muted small">記録は PC のサーバを通して iPhone アプリと同期します。iPhone 側はアプリを開いたとき・閉じたときに同期します。</p>`;
}

// MARK: - 章

function renderBlocks(blocks) {
  return blocks.map((b) => {
    switch (b.type) {
      case "heading": return `<h2>${esc(b.text)}</h2>`;
      case "text": return `<p>${md(b.text)}</p>`;
      case "bullets": return `<ul>${b.items.map((i) => `<li>${md(i)}</li>`).join("")}</ul>`;
      case "note": return `<div class="note">${md(b.text)}</div>`;
      case "figure": return `<pre class="figure">${esc(b.text)}</pre>`;
      case "table": return `<table><tr>${b.header.map((h) => `<th>${esc(h)}</th>`).join("")}</tr>${
        b.rows.map((r) => `<tr>${r.map((c) => `<td>${md(c)}</td>`).join("")}</tr>`).join("")}</table>`;
      default: return "";
    }
  }).join("");
}

function chapters() {
  const done = new Set(P().completedChapters || []);
  const levels = ["入門", "中級", "上級"];
  app.innerHTML = `<h1>学ぶ</h1>` + levels.map((lv) => `
    <h2>${lv}</h2>
    <div class="card list">${content.chapters.filter((c) => c.level === lv).map((c) => `
      <a class="item" href="#/chapter/${esc(c.id)}">
        ${done.has(c.id) ? "✅" : "▫️"} <b>${c.number}. ${esc(c.title)}</b>
        <div class="muted small">${esc(c.summary)}</div>
      </a>`).join("")}
    </div>`).join("");
}

function chapter(id) {
  const c = content.chapters.find((x) => x.id === id);
  if (!c) return (app.innerHTML = "<p>章が見つかりません</p>");
  const done = (P().completedChapters || []).includes(id);
  const count = content.questions.filter((q) => q.chapterID === id).length;
  const index = content.chapters.indexOf(c);
  const next = content.chapters[index + 1];
  app.innerHTML = `
    <p><span class="badge">${esc(c.level)}</span> <span class="muted small">第${c.number}章</span></p>
    <h1>${esc(c.title)}</h1>
    <p class="muted">${esc(c.summary)}</p>
    <div class="card">${renderBlocks(c.blocks)}</div>
    <div class="row">
      <button class="btn ${done ? "" : "primary"}" id="done" ${done ? "disabled" : ""}>${done ? "読了済み" : "読了にする"}</button>
      ${count ? `<a class="btn" href="#/quiz/${esc(id)}">この章のクイズ（${count}問）</a>` : ""}
      <span class="spacer"></span>
      ${next ? `<a class="btn" href="#/chapter/${esc(next.id)}">次の章へ →</a>` : ""}
    </div>`;
  document.getElementById("done").onclick = () => {
    P().completedChapters = union(P().completedChapters, [id]);
    save();
    chapter(id);
  };
}

// MARK: - クイズ

function quizMenu() {
  const best = P().quizBest || {};
  const weakCount = (P().weak?.value || []).length;
  app.innerHTML = `
    <h1>クイズ</h1>
    <div class="grid">
      <a class="card" href="#/quiz/random10"><b>ランダム10問</b><div class="muted small">最高 ${best.random10 ?? "-"}%</div></a>
      <a class="card" href="#/quiz/weak"><b>苦手を復習</b><div class="muted small">${weakCount} 問</div></a>
      <a class="card" href="#/quiz/all"><b>全問チャレンジ</b><div class="muted small">${content.questions.length} 問</div></a>
    </div>
    <h2>章ごと</h2>
    <div class="card list">${content.chapters.map((c) => {
      const n = content.questions.filter((q) => q.chapterID === c.id).length;
      return n ? `<a class="item" href="#/quiz/${esc(c.id)}">${c.number}. ${esc(c.title)}
        <span class="muted small">（${n}問・最高 ${best[c.id] ?? "-"}%）</span></a>` : "";
    }).join("")}</div>`;
}

function quizSession(key) {
  let questions;
  if (key === "random10") questions = shuffle(content.questions).slice(0, 10);
  else if (key === "all") questions = shuffle(content.questions);
  else if (key === "weak") {
    const weak = new Set(P().weak?.value || []);
    questions = shuffle(content.questions.filter((q) => weak.has(q.id)));
  } else questions = content.questions.filter((q) => q.chapterID === key);
  if (!questions.length) {
    app.innerHTML = `<h1>クイズ</h1><p>問題がありません。${key === "weak" ? "苦手な問題はありません 🎉" : ""}</p><a class="btn" href="#/quiz">戻る</a>`;
    return;
  }
  let index = 0, correctCount = 0, combo = 0;

  const show = () => {
    const q = questions[index];
    app.innerHTML = `
      <p class="muted small">${index + 1} / ${questions.length}　正解 ${correctCount}</p>
      <div class="card"><b>${esc(q.question)}</b></div>
      <div id="choices">${q.choices.map((c, i) => `<button class="choice" data-i="${i}">${esc(c)}</button>`).join("")}</div>
      <div id="after"></div>`;
    app.querySelectorAll(".choice").forEach((button) => {
      button.onclick = () => answer(q, Number(button.dataset.i));
    });
  };

  const answer = (q, chosen) => {
    const correct = chosen === q.answer;
    combo = correct ? combo + 1 : 0;
    if (correct) correctCount++;
    recordQuizAnswer(q.id, correct, combo);
    app.querySelectorAll(".choice").forEach((button) => {
      const i = Number(button.dataset.i);
      button.disabled = true;
      button.classList.add(i === q.answer ? "correct" : i === chosen ? "wrong" : "dimmed");
      const note = q.choiceNotes?.[i];
      if (note) button.insertAdjacentHTML("beforeend", `<div class="muted small">${md(note)}</div>`);
    });
    const spec = q.spec ? `<div class="muted small">仕様書：§${esc(q.spec.section)} ${esc(q.spec.title)}（p.${q.spec.page}）</div>` : "";
    const last = index === questions.length - 1;
    document.getElementById("after").innerHTML = `
      <div class="card">
        <b>${correct ? "⭕ 正解" : "❌ 不正解"}</b>
        <p>${md(q.explanation)}</p>
        ${q.detail ? `<details><summary>くわしい解説</summary><p>${md(q.detail)}</p></details>` : ""}
        ${spec}
      </div>
      <button class="btn primary" id="next">${last ? "結果を見る" : "次の問題 →"}</button>`;
    document.getElementById("next").onclick = () => {
      if (last) finish();
      else { index++; show(); }
    };
  };

  const finish = () => {
    const percent = Math.round((correctCount / questions.length) * 100);
    const p = P();
    p.quizBest = maxMap(p.quizBest, { [key]: percent });
    if (correctCount === questions.length && questions.length >= 5) p.xp = (p.xp || 0) + 20;
    save();
    app.innerHTML = `
      <h1>結果</h1>
      <div class="card"><div class="stat">${correctCount} / ${questions.length}（${percent}%）</div>
        <div class="muted small">最高 ${p.quizBest[key]}%</div></div>
      <div class="row"><a class="btn primary" href="#/quiz/${esc(key)}" onclick="setTimeout(render)">もう一度</a>
        <a class="btn" href="#/quiz">クイズの一覧へ</a></div>`;
  };
  show();
}

// MARK: - 英語で聞く
//
// PC のサーバに AI の音声合成（Kokoro、docs/PC_TTS.md）があればその声で、なければブラウザの音声合成で読む。

const speech = {
  rate: Number(localStorage.getItem("speechRate") || 1),
  voiceName: localStorage.getItem("speechVoice") || "",
  /** PC の声の一覧（GET /api/tts/voices）。使えないときは空 */
  pcVoices: [],
  audio: null,
  token: 0,
  async loadPCVoices() {
    try {
      const res = await fetch("/api/tts/voices");
      if (res.ok) this.pcVoices = (await res.json()).voices || [];
    } catch (_) { this.pcVoices = []; }
  },
  browserVoices() {
    return speechSynthesis.getVoices().filter((v) => v.lang.startsWith("en"));
  },
  /** 選べる声：PC の声（"pc:af_heart" の形）とブラウザの声 */
  choices() {
    return [
      ...this.pcVoices.map((v) => ({ value: `pc:${v.id}`, label: `PC の AI の声：${v.label || v.id}` })),
      ...this.browserVoices().map((v) => ({ value: v.name, label: `ブラウザ：${v.name}` })),
    ];
  },
  current() {
    const values = this.choices().map((c) => c.value);
    if (values.includes(this.voiceName)) return this.voiceName;
    if (this.pcVoices.length) return `pc:${this.pcVoices[0].id}`;
    const list = this.browserVoices();
    const best = list.find((v) => /natural/i.test(v.name) && v.lang === "en-US") || list.find((v) => v.lang === "en-US") || list[0];
    return best ? best.name : "";
  },
  stop() {
    this.token++;
    speechSynthesis.cancel();
    if (this.audio) { this.audio.pause(); this.audio = null; }
  },
  /** texts を順に読む。onIndex(i) で今の文（終わったら -1）、pause なら1文ごとに間を空ける */
  play(texts, start, onIndex, pause = false) {
    this.stop();
    const voice = this.current();
    if (voice.startsWith("pc:")) this.playPC(texts, start, onIndex, pause, voice.slice(3));
    else this.playBrowser(texts, start, onIndex, pause, voice);
  },
  async playPC(texts, start, onIndex, pause, voice) {
    const token = this.token;
    const url = (text) => `/api/tts?${new URLSearchParams({ text, voice, speed: String(this.rate) })}`;
    // 次の文の音声は、今の文を読んでいるあいだに作っておく
    let next = new Audio(url(texts[start]));
    for (let i = start; i < texts.length; i++) {
      if (token !== this.token) return;
      const audio = next;
      next = i + 1 < texts.length ? new Audio(url(texts[i + 1])) : null;
      if (next) next.preload = "auto";
      this.audio = audio;
      onIndex(i);
      try {
        await new Promise((resolve, reject) => {
          audio.onended = resolve;
          audio.onerror = () => reject(new Error("PC の声を読み込めませんでした"));
          audio.play().catch(reject);
        });
      } catch (e) {
        if (token !== this.token) return;
        // PC の声が使えないときは、残りをブラウザの声で読む
        this.pcVoices = [];
        this.playBrowser(texts, i, onIndex, pause, this.current());
        return;
      }
      if (token !== this.token) return;
      if (i < texts.length - 1) await new Promise((r) => setTimeout(r, pause ? 1200 + texts[i].length * 60 : 250));
    }
    if (token === this.token) onIndex(-1);
  },
  playBrowser(texts, start, onIndex, pause, voiceName) {
    speechSynthesis.cancel();
    const voice = this.browserVoices().find((v) => v.name === voiceName);
    texts.slice(start).forEach((text, offset) => {
      const u = new SpeechSynthesisUtterance(text);
      if (voice) u.voice = voice;
      u.lang = voice?.lang || "en-US";
      u.rate = this.rate;
      u.onstart = () => onIndex(start + offset);
      u.onend = () => {
        if (start + offset === texts.length - 1) onIndex(-1);
        else if (pause) {
          speechSynthesis.pause();
          setTimeout(() => speechSynthesis.resume(), 1200 + text.length * 60);
        }
      };
      speechSynthesis.speak(u);
    });
  },
};
speechSynthesis.onvoiceschanged = () => {};

function englishHome() {
  const done = new Set(P().englishDone || []);
  const voices = speech.choices();
  const selected = speech.current();
  app.innerHTML = `
    <h1>英語で聞く</h1>
    <div class="card">
      <div class="row">
        <label>速さ <select id="rate">${[[0.8, "ゆっくり"], [1, "ふつう"], [1.2, "はやめ"]].map(([v, l]) =>
          `<option value="${v}" ${speech.rate === v ? "selected" : ""}>${l}</option>`).join("")}</select></label>
        <label>声 <select id="voice">${voices.map((v) =>
          `<option value="${esc(v.value)}" ${selected === v.value ? "selected" : ""}>${esc(v.label)}</option>`).join("")}</select></label>
        <button class="btn small" id="sample">試しに聞く</button>
      </div>
      <p class="muted small">${speech.pcVoices.length
        ? "PC の AI の声（Kokoro）が使えます。いちばん自然です。"
        : "PC の AI の声（docs/PC_TTS.md）を準備すると、もっと自然な声で読めます。今はブラウザの声で読みます（Edge なら Natural の声が自然です）。"}</p>
    </div>
    <h2>レッスン（${done.size} / ${content.english.length}）</h2>
    <div class="card list">${content.english.map((l) => `
      <a class="item" href="#/english/${esc(l.id)}">${done.has(l.id) ? "✅" : "▫️"}
        <b>${esc(l.title)}</b> <span class="muted small">${esc(l.titleJa)}・${esc(l.level)}</span></a>`).join("")}</div>
    <h2>PCIe の言葉の英語での読み方</h2>
    <div class="card list">${content.spokenTerms.map((t, i) => `
      <div class="item"><button class="btn small" data-term="${i}">▶</button>
        <b>${esc(t.written)}</b> … ${esc(t.reading)}<div class="muted small">${esc(t.tip)}</div></div>`).join("")}</div>`;
  document.getElementById("rate").onchange = (e) => { speech.rate = Number(e.target.value); localStorage.setItem("speechRate", speech.rate); };
  document.getElementById("voice").onchange = (e) => { speech.voiceName = e.target.value; localStorage.setItem("speechVoice", speech.voiceName); };
  document.getElementById("sample").onclick = () => speech.play(["The Data Link Layer replays the TLP when it receives a NAK."], 0, () => {});
  app.querySelectorAll("[data-term]").forEach((b) => {
    b.onclick = () => speech.play([content.spokenTerms[Number(b.dataset.term)].speech], 0, () => {});
  });
  if (!speech.browserVoices().length) speechSynthesis.onvoiceschanged = () => { if (location.hash === "#/english") englishHome(); };
}

function englishLesson(id) {
  const lesson = content.english.find((l) => l.id === id);
  if (!lesson) return (app.innerHTML = "<p>レッスンが見つかりません</p>");
  let tab = "listen", showEn = false, showJa = false, pause = false;
  const texts = lesson.sentences.map((s) => s.spoken || s.en);

  const draw = () => {
    app.innerHTML = `
      <p><span class="badge">${esc(lesson.level)}</span> <span class="muted small">${esc(lesson.titleJa)}</span></p>
      <h1>${esc(lesson.title)}</h1>
      <div class="row">${[["listen", "聞く"], ["questions", "問題"], ["words", "単語"]].map(([k, l]) =>
        `<button class="btn ${tab === k ? "primary" : ""}" data-tab="${k}">${l}</button>`).join("")}</div>
      <div id="body"></div>`;
    app.querySelectorAll("[data-tab]").forEach((b) => { b.onclick = () => { speech.stop(); tab = b.dataset.tab; draw(); }; });
    ({ listen, questions, words })[tab]();
  };

  const listen = () => {
    const body = document.getElementById("body");
    body.innerHTML = `
      <div class="card row">
        <button class="btn primary" id="play">▶ 最初から聞く</button>
        <button class="btn" id="stop">■ 止める</button>
        <label><input type="checkbox" id="en" ${showEn ? "checked" : ""}> 英文</label>
        <label><input type="checkbox" id="ja" ${showJa ? "checked" : ""}> 日本語訳</label>
        <label><input type="checkbox" id="pause" ${pause ? "checked" : ""}> 1文ごとに止める</label>
      </div>
      ${lesson.sentences.map((s, i) => `
        <div class="line" data-i="${i}"><span class="time">▶</span><div>
          <div class="${showEn ? "" : "hidden-text"}">${esc(s.en)}</div>
          ${showJa ? `<div class="ja">${esc(s.ja)}</div>` : ""}</div></div>`).join("")}`;
    const highlight = (i) => body.querySelectorAll(".line").forEach((el) => el.classList.toggle("current", Number(el.dataset.i) === i));
    document.getElementById("play").onclick = () => speech.play(texts, 0, highlight, pause);
    document.getElementById("stop").onclick = () => { speech.stop(); highlight(-1); };
    document.getElementById("en").onchange = (e) => { showEn = e.target.checked; listen(); };
    document.getElementById("ja").onchange = (e) => { showJa = e.target.checked; listen(); };
    document.getElementById("pause").onchange = (e) => { pause = e.target.checked; };
    body.querySelectorAll(".line").forEach((el) => { el.onclick = () => speech.play(texts, Number(el.dataset.i), highlight, pause); });
  };

  const questions = () => {
    const body = document.getElementById("body");
    const answered = {};
    body.innerHTML = lesson.questions.map((q, qi) => `
      <div class="card" data-q="${qi}">
        <div class="row"><b>Q${qi + 1}. ${esc(q.question)}</b><button class="btn small" data-say="${qi}">▶</button></div>
        ${q.choices.map((c, ci) => `<button class="choice" data-c="${ci}">${esc(c)}</button>`).join("")}
        <div class="after"></div>
      </div>`).join("");
    body.querySelectorAll("[data-say]").forEach((b) => { b.onclick = () => speech.play([lesson.questions[Number(b.dataset.say)].question], 0, () => {}); });
    body.querySelectorAll("[data-q]").forEach((card) => {
      const qi = Number(card.dataset.q);
      const q = lesson.questions[qi];
      card.querySelectorAll(".choice").forEach((b) => {
        b.onclick = () => {
          if (answered[qi] !== undefined) return;
          const chosen = Number(b.dataset.c);
          answered[qi] = chosen;
          card.querySelectorAll(".choice").forEach((x) => {
            const ci = Number(x.dataset.c);
            x.classList.add(ci === q.answer ? "correct" : ci === chosen ? "wrong" : "dimmed");
          });
          card.querySelector(".after").innerHTML = `<p class="small">${esc(q.note)}</p>`;
          countAnswer();
          if (Object.keys(answered).length === lesson.questions.length) {
            P().englishDone = union(P().englishDone, [lesson.id]);
          }
          save();
        };
      });
    });
  };

  const words = () => {
    document.getElementById("body").innerHTML = `<div class="card list">${lesson.words.map((w, i) => `
      <div class="item"><button class="btn small" data-w="${i}">▶</button> <b>${esc(w.word)}</b> … ${esc(w.ja)}
        <div class="muted small">${esc(w.tip)}</div></div>`).join("")}</div>`;
    app.querySelectorAll("[data-w]").forEach((b) => { b.onclick = () => speech.play([lesson.words[Number(b.dataset.w)].word], 0, () => {}); });
  };

  draw();
}

// MARK: - 配信で英語

const clips = () => Object.entries(doc.english.clips || {})
  .filter(([, c]) => !c.deleted)
  .map(([id, c]) => ({ id, ...c }))
  .sort((a, b) => new Date(b.addedAt) - new Date(a.addedAt));

/** 字幕（.srt / .vtt）を文に分ける（アプリの SubtitleParser と同じ） */
function parseSubtitles(text) {
  const toSec = (t) => t.trim().replace(",", ".").split(":").reduce((acc, v) => acc * 60 + Number(v), 0);
  const lines = [];
  const recent = [];
  for (const block of text.replace(/\r/g, "").split("\n\n")) {
    const rows = block.split("\n").filter(Boolean);
    const ti = rows.findIndex((r) => r.includes("-->"));
    if (ti < 0) continue;
    const [a, b] = rows[ti].split("-->");
    const start = toSec(a), end = toSec(b.trim().split(" ")[0]);
    for (const row of rows.slice(ti + 1)) {
      const t = row.replace(/<[^>]+>/g, "").replace(/\[[^\]]*\]/g, "").replace(/♪/g, "")
        .replace(/&amp;/g, "&").replace(/&#39;/g, "'").replace(/&quot;/g, '"').trim();
      if (!t || recent.includes(t)) continue;
      lines.push({ id: uuid(), start, end: Math.max(end, start), text: t });
      recent.push(t);
      if (recent.length > 3) recent.shift();
    }
  }
  return lines;
}

/** PC の youtube_library にある動画を、記録に加える（字幕があればスクリプトにする） */
async function addLibraryVideo(video) {
  let lines = null;
  if (video.hasSubtitles !== false) {
    const res = await fetch(`/api/youtube/library/${encodeURIComponent(video.id)}/subtitles`);
    if (res.ok) lines = parseSubtitles(await res.text());
  }
  const id = uuid();
  doc.english.clips[id] = {
    title: video.title || "YouTube の動画", addedAt: now(), duration: 0, youtubeID: video.id,
    lines: lines && lines.length ? lines : null, songs: null, updatedAt: now(), deleted: false,
  };
  save();
  return id;
}

/** PC に YouTube の保存を頼み、終わったら記録に加える */
async function downloadViaPC(url, title, onProgress) {
  const res = await fetch("/api/youtube/download", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ url }) });
  if (!res.ok) throw new Error(await res.text() || `HTTP ${res.status}`);
  const { job } = await res.json();
  for (;;) {
    await new Promise((r) => setTimeout(r, 2000));
    const status = await (await fetch(`/api/youtube/jobs/${job}`)).json();
    if (status.state === "error") throw new Error(status.error || "保存に失敗しました");
    if (status.state === "done") {
      const id = new URL(url).searchParams.get("v") || url.split("/").pop();
      return addLibraryVideo({ id, title: status.title || title });
    }
    onProgress(status.progress || 0);
  }
}

async function clipsHome() {
  const list = clips();
  app.innerHTML = `
    <h1>配信で英語</h1>
    <div class="card">
      <b>YouTube の動画を PC で保存して取り込む</b>
      <div class="row" style="margin-top:8px"><input type="text" id="url" placeholder="https://www.youtube.com/watch?v=…">
        <button class="btn primary" id="dl">保存</button></div>
      <div id="dl-status" class="muted small"></div>
      <p class="muted small">保存した動画は自分の学習用だけに使ってください。iPhone の「配信で英語」にもスクリプトが同期され、iPhone では「PC から動画を受け取る」で動画も見られます。</p>
    </div>
    <h2>動画（${list.length}）</h2>
    <div class="card list">${list.length ? list.map((c) => `
      <a class="item" href="#/clip/${esc(c.id)}"><b>${esc(c.title)}</b>
        <div class="muted small">${c.lines ? `${c.lines.length} 文` : "まだ文字起こししていません（iPhone で文字起こしすると同期されます）"}
        ・${c.youtubeID ? "PC で再生できます" : "動画は iPhone にあります（スクリプトのみ）"}</div></a>`).join("")
      : `<div class="item muted">まだ動画がありません</div>`}</div>
    <h2>PC に保存してある動画</h2><div id="library" class="card list"><div class="item muted">読み込み中…</div></div>
    <h2>South Park 公式の新着</h2><div id="southpark" class="card list"><div class="item muted">読み込み中…</div></div>`;

  document.getElementById("dl").onclick = async () => {
    const url = document.getElementById("url").value.trim();
    const status = document.getElementById("dl-status");
    if (!/^https:\/\/(www\.)?(youtube\.com|youtu\.be)\//.test(url)) { status.textContent = "YouTube の URL を入れてください"; return; }
    status.textContent = "PC で保存中…";
    try {
      const id = await downloadViaPC(url, "", (p) => { status.textContent = `PC で保存中… ${Math.round(p * 100)}%`; });
      location.hash = `#/clip/${id}`;
    } catch (e) { status.textContent = `保存できませんでした：${e.message}`; }
  };

  const known = new Set(list.map((c) => c.youtubeID).filter(Boolean));
  try {
    const res = await fetch("/api/youtube/library");
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const videos = (await res.json()).videos.filter((v) => !known.has(v.id));
    document.getElementById("library").innerHTML = videos.length ? videos.map((v, i) => `
      <div class="item row"><span>${esc(v.title || v.id)}</span><span class="spacer"></span>
        <button class="btn small" data-lib="${i}">取り込む</button></div>`).join("")
      : `<div class="item muted">取り込んでいない動画はありません</div>`;
    document.querySelectorAll("[data-lib]").forEach((b) => {
      b.onclick = async () => { b.disabled = true; location.hash = `#/clip/${await addLibraryVideo(videos[Number(b.dataset.lib)])}`; };
    });
  } catch (e) {
    document.getElementById("library").innerHTML = `<div class="item muted">PC の保存一覧を読めませんでした（${esc(e.message)}）</div>`;
  }
  try {
    const res = await fetch("/api/youtube/channel?handle=southpark&limit=30");
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const videos = (await res.json()).videos;
    document.getElementById("southpark").innerHTML = videos.map((v, i) => `
      <div class="item row"><img src="${esc(v.thumbnail || `https://i.ytimg.com/vi/${v.id}/mqdefault.jpg`)}" alt="" width="120" style="border-radius:8px">
        <span>${esc(v.title)}</span><span class="spacer"></span>
        ${known.has(v.id) ? `<span class="muted small">取り込み済み</span>` : `<button class="btn small" data-sp="${i}">PC で保存して取り込む</button>`}</div>`).join("");
    document.querySelectorAll("[data-sp]").forEach((b) => {
      b.onclick = async () => {
        const v = videos[Number(b.dataset.sp)];
        b.disabled = true;
        try {
          const id = await downloadViaPC(`https://www.youtube.com/watch?v=${v.id}`, v.title, (p) => { b.textContent = `保存中… ${Math.round(p * 100)}%`; });
          location.hash = `#/clip/${id}`;
        } catch (e) { b.textContent = "失敗しました"; alert(e.message); }
      };
    });
  } catch (e) {
    document.getElementById("southpark").innerHTML = `<div class="item muted">一覧を読めませんでした（${esc(e.message)}）</div>`;
  }
}

/** ブラウザに翻訳機能（Translator API）があれば、まだ訳していない文を日本語に訳す */
async function translateLines(clipID) {
  if (!("Translator" in self)) throw new Error("このブラウザには翻訳機能がありません。iPhone で訳すと同期されます。");
  const translator = await self.Translator.create({ sourceLanguage: "en", targetLanguage: "ja" });
  const clip = doc.english.clips[clipID];
  for (const line of clip.lines || []) {
    if (!line.japanese) line.japanese = await translator.translate(line.text);
  }
  clip.updatedAt = now();
  save();
}

function clipPlayer(id) {
  const clip = doc.english.clips[id];
  if (!clip || clip.deleted) return (app.innerHTML = "<p>動画が見つかりません</p>");
  const lines = clip.lines || [];
  let mode = "normal", loopLine = null, hideText = false, showJa = lines.some((l) => l.japanese);
  const hasVideo = Boolean(clip.youtubeID);

  app.innerHTML = `
    <h1>${esc(clip.title)}</h1>
    <div class="player">
      ${hasVideo ? `<video id="video" src="/api/youtube/library/${encodeURIComponent(clip.youtubeID)}/video" controls preload="metadata"></video>`
        : `<div class="card muted">この動画は iPhone にあります。スクリプト・訳・フレーズを使えます。</div>`}
      <div class="row" style="margin-top:8px">
        ${hasVideo ? `<button class="btn small" id="back5">⟲ 5秒</button>
        <label>速さ <select id="rate"><option value="0.5">0.5×</option><option value="0.75">0.75×</option><option value="1" selected>1×</option></select></label>
        <label>練習 <select id="mode"><option value="normal">通常</option><option value="repeat">1文くり返し</option><option value="stop">1文ずつ止める</option></select></label>` : ""}
        <label><input type="checkbox" id="hide"> 英文を隠す</label>
        <label><input type="checkbox" id="ja" ${showJa ? "checked" : ""}> 日本語訳</label>
        <span class="spacer"></span>
        <button class="btn small" id="translate">日本語に訳す</button>
        <button class="btn small" id="copy">スクリプトをコピー</button>
      </div>
    </div>
    <div id="lines"></div>
    ${clip.songs?.length ? `<h2>流れていた曲</h2><div class="card list">${clip.songs.map((s) => `
      <div class="item"><b>${esc(s.title)}</b> ・ ${esc(s.artist)} <span class="muted small">${formatTime(s.start)}</span>
        ${s.appleMusicURL ? ` <a href="${esc(s.appleMusicURL)}" target="_blank">Apple Music</a>` : ""}
        <a href="https://open.spotify.com/search/${encodeURIComponent(`${s.title} ${s.artist}`)}" target="_blank">Spotify</a></div>`).join("")}</div>` : ""}
    ${!lines.length ? `<div class="card muted">まだスクリプトがありません。iPhone で文字起こしすると、ここにも出ます。</div>` : ""}`;

  const video = document.getElementById("video");
  const linesBox = document.getElementById("lines");
  const drawLines = () => {
    linesBox.innerHTML = lines.map((l, i) => `
      <div class="line" data-i="${i}"><span class="time">${formatTime(l.start)}</span>
        <div style="flex:1"><div class="${hideText ? "hidden-text" : ""}">${esc(l.text)}</div>
          ${showJa && l.japanese ? `<div class="ja">${esc(l.japanese)}</div>` : ""}</div>
        <button class="btn small" data-save="${i}" title="フレーズ帳に保存">＋</button></div>`).join("");
    linesBox.querySelectorAll(".line").forEach((el) => {
      el.onclick = (e) => {
        if (e.target.dataset.save !== undefined) return;
        const line = lines[Number(el.dataset.i)];
        if (mode === "repeat") loopLine = line;
        if (video) { video.currentTime = line.start; video.play(); }
      };
    });
    linesBox.querySelectorAll("[data-save]").forEach((b) => {
      b.onclick = () => {
        const line = lines[Number(b.dataset.save)];
        const text = prompt("フレーズ（覚えたい部分だけ残してもOK）", line.text);
        if (!text) return;
        const memo = prompt("意味・メモ", line.japanese || "") || "";
        doc.english.phrases[uuid()] = { text, memo, clipID: id, start: line.start, savedAt: now(), updatedAt: now(), deleted: false };
        save();
        b.textContent = "✓";
      };
    });
  };
  drawLines();

  if (video) {
    let previous = 0;
    const current = (t) => lines.findLastIndex((l) => l.start <= t + 0.05 && t < l.end + 0.4);
    video.ontimeupdate = () => {
      const t = video.currentTime;
      const i = current(t);
      linesBox.querySelectorAll(".line").forEach((el) => el.classList.toggle("current", Number(el.dataset.i) === i));
      if (mode === "repeat" && loopLine && t >= loopLine.end) video.currentTime = loopLine.start;
      if (mode === "stop" && !video.paused && lines.some((l) => previous < l.end && l.end <= t)) video.pause();
      previous = t;
    };
    document.getElementById("back5").onclick = () => { video.currentTime = Math.max(0, video.currentTime - 5); };
    document.getElementById("rate").onchange = (e) => { video.playbackRate = Number(e.target.value); };
    document.getElementById("mode").onchange = (e) => {
      mode = e.target.value;
      loopLine = mode === "repeat" ? lines[Math.max(0, current(video.currentTime))] : null;
    };
  }
  document.getElementById("hide").onchange = (e) => { hideText = e.target.checked; drawLines(); };
  document.getElementById("ja").onchange = (e) => { showJa = e.target.checked; drawLines(); };
  document.getElementById("copy").onclick = async () => {
    const text = `${clip.title}\n\n` + lines.map((l) => `[${formatTime(l.start)}] ${l.text}${showJa && l.japanese ? `\n　${l.japanese}` : ""}`).join("\n");
    await navigator.clipboard.writeText(text);
    document.getElementById("copy").textContent = "コピーしました";
  };
  document.getElementById("translate").onclick = async (e) => {
    e.target.disabled = true;
    e.target.textContent = "訳しています…";
    try { await translateLines(id); clipPlayer(id); } catch (err) { alert(err.message); e.target.disabled = false; e.target.textContent = "日本語に訳す"; }
  };
  cleanup = () => { if (video) video.pause(); };
}

// MARK: - フレーズ帳

function phraseBook() {
  const phrases = Object.entries(doc.english.phrases || {})
    .filter(([, p]) => !p.deleted)
    .map(([id, p]) => ({ id, ...p }))
    .sort((a, b) => new Date(b.savedAt) - new Date(a.savedAt));
  app.innerHTML = `
    <h1>フレーズ帳（${phrases.length}）</h1>
    <div class="card list">${phrases.length ? phrases.map((p) => {
      const clip = p.clipID && doc.english.clips[p.clipID];
      return `<div class="item">
        <div class="row"><b style="flex:1">${esc(p.text)}</b>
          <button class="btn small" data-say="${esc(p.id)}">▶</button>
          <button class="btn small" data-memo="${esc(p.id)}">メモ</button>
          <button class="btn small" data-del="${esc(p.id)}">削除</button></div>
        ${p.memo ? `<div class="muted">${esc(p.memo)}</div>` : ""}
        ${clip && !clip.deleted ? `<a class="small" href="#/clip/${esc(p.clipID)}">${esc(clip.title)}（${formatTime(p.start)}）</a>` : ""}
      </div>`;
    }).join("") : `<div class="item muted">動画のスクリプトの「＋」で保存すると、ここにたまります。</div>`}</div>`;
  app.querySelectorAll("[data-say]").forEach((b) => { b.onclick = () => speech.play([doc.english.phrases[b.dataset.say].text], 0, () => {}); });
  app.querySelectorAll("[data-memo]").forEach((b) => {
    b.onclick = () => {
      const p = doc.english.phrases[b.dataset.memo];
      const memo = prompt("意味・メモ", p.memo || "");
      if (memo === null) return;
      p.memo = memo;
      p.updatedAt = now();
      save();
      phraseBook();
    };
  });
  app.querySelectorAll("[data-del]").forEach((b) => {
    b.onclick = () => {
      if (!confirm("このフレーズを消しますか？（iPhone からも消えます）")) return;
      doc.english.phrases[b.dataset.del] = { updatedAt: now(), deleted: true };
      save();
      phraseBook();
    };
  });
}

// MARK: - 起動

async function start() {
  try {
    const saved = localStorage.getItem("pcieStudyDoc");
    if (saved) doc = mergeDocs(doc, JSON.parse(saved));
  } catch (_) { /* 読めなくても続ける */ }
  try {
    content = await (await fetch("content.json", { cache: "no-cache" })).json();
  } catch (e) {
    app.innerHTML = `<div class="card">学習データ（content.json）を読み込めませんでした。PC で pcie_study を git pull してください。</div>`;
    return;
  }
  await Promise.all([pull(), speech.loadPCVoices()]);
  window.addEventListener("hashchange", render);
  // iPhone で学習した分を取り込むため、ページに戻ってきたときにも読み直す
  document.addEventListener("visibilitychange", async () => {
    if (document.visibilityState === "visible") { await pull(); if (!/clip\//.test(location.hash)) render(); }
  });
  render();
}

start();
