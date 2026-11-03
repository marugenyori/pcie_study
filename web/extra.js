// ブラウザ版の追加の画面（今日・読みもの・クイズのゲーム・質問・設定）
//
// app.js のあとに読み込む。app.js の routes・doc・content・save などを使う。
"use strict";

// MARK: - 日付から決まる「今日の〜」（アプリの DailyPick と同じ計算）

function dailyIndex(count, salt, date = new Date()) {
  if (!count) return 0;
  const start = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const days = Math.trunc(start.getTime() / 1000 / 86400);
  return ((days * salt) % count + count) % count;
}
const dailyQuestion = () => content.questions[dailyIndex(content.questions.length, 7919)];
const columnOfDay = () => content.columns[dailyIndex(content.columns.length, 3)];
const levelTitle = (lv) => content.game.levelTitles[Math.min(lv, content.game.levelTitles.length) - 1];

// MARK: - デイリークエスト（日ごとにこのブラウザで数える。10問は同期した学習量で数える）

function questState() {
  let state = {};
  try { state = JSON.parse(localStorage.getItem("quests") || "{}"); } catch (_) { /* 初期値 */ }
  if (state.day !== todayKey()) state = { day: todayKey(), bestCombo: 0, weakCleared: 0, done: [] };
  return state;
}
const saveQuests = (state) => { try { localStorage.setItem("quests", JSON.stringify(state)); } catch (_) { /* 続ける */ } };
function questProgress(quest, state = questState()) {
  if (quest.id === "answer10") return todayCount();
  if (quest.id === "combo5") return state.bestCombo;
  return state.weakCleared;
}

window.onQuizAnswer = ({ correct, combo, wasWeak }) => {
  const state = questState();
  state.bestCombo = Math.max(state.bestCombo, combo);
  if (correct && wasWeak) state.weakCleared++;
  for (const quest of content.game.quests) {
    if (!state.done.includes(quest.id) && questProgress(quest, state) >= quest.goal) {
      state.done.push(quest.id);
      P().xp = (P().xp || 0) + content.game.questXP;
      toast(`クエスト達成：${quest.title}（+${content.game.questXP} XP）`);
    }
  }
  saveQuests(state);
};

function toast(text) {
  const el = document.createElement("div");
  el.className = "toast";
  el.textContent = text;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 2600);
}

// MARK: - 実績（アプリの Achievement と同じ条件）

function achievements() {
  const p = P();
  const answered = p.answeredTotal || 0;
  const best = p.bestStreak || 0;
  const lv = level(p.xp || 0);
  const chapters = (p.completedChapters || []).filter((id) => content.chapters.some((c) => c.id === id)).length;
  return [
    ["はじめの一歩", "1問解く", answered >= 1],
    ["三日坊主卒業", "3日連続で目標達成", best >= 3],
    ["1週間連続", "7日連続で目標達成", best >= 7],
    ["習慣マスター", "30日連続で目標達成", best >= 30],
    ["100問突破", "通算100問解く", answered >= 100],
    ["500問突破", "通算500問解く", answered >= 500],
    ["パーフェクト", "クイズで全問正解", Object.values(p.quizBest || {}).includes(100)],
    ["全章読破", `${content.chapters.length}章すべて読了`, chapters === content.chapters.length],
    ["リンクトレーナー", "レベル5になる", lv >= 5],
    ["パケットマスター", "レベル10になる", lv >= 10],
    ["不死身", "サバイバルで15問正解", ((p.gameBest || {}).survival || 0) >= 15],
  ];
}

// MARK: - ニュース（GitHub の main にある news.json。アプリと同じ）

let newsCache = null;
async function loadNews() {
  if (newsCache) return newsCache;
  const res = await fetch("https://raw.githubusercontent.com/marugenyori/pcie_study/main/Shared/news.json", { cache: "no-cache" });
  newsCache = (await res.json()).items.sort((a, b) => b.date.localeCompare(a.date));
  return newsCache;
}
const newsTags = { spec: "仕様", roadmap: "ロードマップ", compliance: "コンプライアンス", event: "イベント", ecn: "ECN", industry: "業界", product: "製品" };
const newsRow = (n) => `<div class="item"><span class="badge">${esc(newsTags[n.tag] || n.tag)}</span>
  <span class="muted small">${esc(n.date)}</span><div><b>${esc(n.title)}</b></div>
  <div class="small">${esc(n.summary)}</div>
  <div class="muted small">出典：${n.url ? `<a href="${esc(n.url)}" target="_blank" rel="noopener">${esc(n.source)}</a>` : esc(n.source)}</div></div>`;

// MARK: - 今日

function todayHome() {
  const p = P();
  const xp = p.xp || 0;
  const lv = level(xp);
  const start = 25 * lv * (lv - 1), end = 25 * (lv + 1) * lv;
  const q = dailyQuestion();
  const answered = (p.dailyAnswers || {})[todayKey()];
  const state = questState();
  const column = columnOfDay();
  const weeks = [];
  for (let i = 27; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const key = todayKey(d);
    const n = (p.dailyCounts || {})[key] || 0;
    const met = (p.goalMetDays || []).includes(key);
    weeks.push(`<span class="day ${met ? "met" : n ? "some" : ""}" title="${key}：${n}問"></span>`);
  }
  const list = achievements();
  app.innerHTML = `
    <h1>今日</h1>
    <div class="grid">
      <div class="card"><div class="muted small">連続日数</div><div class="stat">🔥 ${streak()} 日</div>
        <div class="muted small">最長記録 ${p.bestStreak || 0} 日</div></div>
      <div class="card"><div class="muted small">今日の問題数</div><div class="stat">${todayCount()} / ${dailyGoal()}</div>
        <div class="progress"><div style="width:${Math.min(100, (todayCount() / dailyGoal()) * 100)}%"></div></div>
        <label class="small">1日の目標 <select id="goal">${[3, 5, 10, 20].map((g) =>
          `<option ${g === dailyGoal() ? "selected" : ""}>${g}</option>`).join("")}</select> 問</label></div>
      <div class="card"><div class="muted small">レベル</div><div class="stat">Lv ${lv}</div>
        <div class="small">${esc(levelTitle(lv))}</div>
        <div class="progress"><div style="width:${((xp - start) / (end - start)) * 100}%"></div></div>
        <div class="muted small">${xp} XP（次まで ${end - xp}）</div></div>
    </div>
    <div class="card"><div class="muted small">直近4週間</div><div class="heat">${weeks.join("")}</div></div>

    <h2>今日の1問</h2>
    <div class="card" id="daily">
      <b>${esc(q.question)}</b>
      ${q.choices.map((c, i) => `<button class="choice ${answered === undefined ? "" : i === q.answer ? "correct" : i === answered ? "wrong" : "dimmed"}"
        data-i="${i}" ${answered === undefined ? "" : "disabled"}>${esc(c)}</button>`).join("")}
      ${answered === undefined ? "" : `<p>${md(q.explanation)}</p><p class="muted small">明日また新しい問題が出ます</p>`}
    </div>

    <h2>デイリークエスト</h2>
    <div class="card list">${content.game.quests.map((quest) => {
      const n = Math.min(questProgress(quest, state), quest.goal);
      return `<div class="item">${state.done.includes(quest.id) ? "✅" : "▫️"} ${esc(quest.title)}
        <span class="muted small">${n} / ${quest.goal}（+${content.game.questXP} XP）</span></div>`;
    }).join("")}</div>

    <h2>すぐ始める</h2>
    <div class="grid">
      <a class="card" href="#/quiz/random10"><b>ランダム10問</b></a>
      <a class="card" href="#/quiz/weak"><b>苦手を復習</b><div class="muted small">${(p.weak?.value || []).length} 問</div></a>
      <a class="card" href="#/game/survival"><b>サバイバル</b><div class="muted small">自己ベスト ${(p.gameBest || {}).survival || 0} 問</div></a>
      <a class="card" href="#/english"><b>英語で聞く</b></a>
    </div>

    ${column ? `<h2>今日のコラム</h2><a class="card" href="#/column/${esc(column.id)}"><b>${esc(column.title)}</b>
      <div class="muted small">${esc(column.lead)}・${column.minutes}分</div></a>` : ""}

    <h2>PCIe ニュース <a class="small" href="#/news">すべて</a></h2>
    <div class="card list" id="news"><div class="item muted">読み込み中…</div></div>

    <h2>実績（${list.filter((a) => a[2]).length} / ${list.length}）</h2>
    <div class="grid">${list.map(([title, detail, ok]) =>
      `<div class="card ${ok ? "" : "locked"}"><b>${ok ? "🏅" : "🔒"} ${esc(title)}</b><div class="muted small">${esc(detail)}</div></div>`).join("")}</div>`;

  document.getElementById("goal").onchange = (e) => {
    P().dailyGoal = { value: Number(e.target.value), updatedAt: now() };
    const key = todayKey();
    if (todayCount() >= dailyGoal() && !(P().goalMetDays || []).includes(key)) {
      P().goalMetDays = union(P().goalMetDays, [key]);
      P().bestStreak = Math.max(P().bestStreak || 0, streak());
    }
    save();
    todayHome();
  };
  document.querySelectorAll("#daily .choice").forEach((b) => {
    b.onclick = () => {
      const choice = Number(b.dataset.i);
      P().dailyAnswers = { ...(P().dailyAnswers || {}), [todayKey()]: choice };
      // 「今日の1問」は正解で 20 XP（ふつうの問題の 10 XP の代わり）
      recordQuizAnswer(q.id, choice === q.answer, 0);
      if (choice === q.answer) P().xp += content.game.dailyQuestionXP - content.game.correctXP;
      save();
      todayHome();
    };
  });
  loadNews().then((items) => {
    const box = document.getElementById("news");
    if (box) box.innerHTML = items.slice(0, 3).map(newsRow).join("");
  }).catch(() => {
    const box = document.getElementById("news");
    if (box) box.innerHTML = `<div class="item muted">ニュースを読み込めませんでした（インターネットにつながっているか確認してください）</div>`;
  });
}

// MARK: - 学ぶ（章・読みもの）

function learnHome() {
  chapters();
  app.insertAdjacentHTML("beforeend", `
    <h2>読みもの</h2>
    <div class="grid">
      <a class="card" href="#/columns"><b>コラム</b><div class="muted small">${content.columns.length} 本</div></a>
      <a class="card" href="#/glossary"><b>用語集</b><div class="muted small">${content.glossary.length} 語</div></a>
      <a class="card" href="#/news"><b>PCIe ニュース</b></a>
      <a class="card" href="#/ask"><b>質問する</b><div class="muted small">仕様書・PC の AI・Claude Code</div></a>
      <a class="card" href="#/english"><b>英語で聞く</b></a>
    </div>`);
}

function columnList() {
  app.innerHTML = `<h1>コラム</h1><div class="card list">${content.columns.map((c) => `
    <a class="item" href="#/column/${esc(c.id)}"><b>${esc(c.title)}</b><div class="muted small">${esc(c.lead)}・${c.minutes}分</div></a>`).join("")}</div>`;
}

function columnDetail(id) {
  const c = content.columns.find((x) => x.id === id);
  if (!c) return (app.innerHTML = "<p>コラムが見つかりません</p>");
  const chapter = c.chapterID && content.chapters.find((x) => x.id === c.chapterID);
  app.innerHTML = `<p class="muted small">${c.minutes}分で読めます</p><h1>${esc(c.title)}</h1><p class="muted">${esc(c.lead)}</p>
    <div class="card">${renderBlocks(c.blocks)}</div>
    ${chapter ? `<a class="btn" href="#/chapter/${esc(chapter.id)}">関連する章：${chapter.number}. ${esc(chapter.title)}</a>` : ""}`;
}

function glossary() {
  const categories = [...new Set(content.glossary.map((t) => t.category))];
  app.innerHTML = `<h1>用語集</h1>
    <input type="text" id="q" placeholder="用語を検索（例：LTSSM、クレジット）">
    <div id="terms"></div>`;
  const draw = () => {
    const q = document.getElementById("q").value.trim().toLowerCase();
    const hit = (t) => !q || [t.term, t.fullName, t.description].some((s) => s.toLowerCase().includes(q));
    document.getElementById("terms").innerHTML = categories.map((cat) => {
      const terms = content.glossary.filter((t) => t.category === cat && hit(t));
      return terms.length ? `<h2>${esc(cat)}</h2><div class="card list">${terms.map((t) =>
        `<div class="item"><b>${esc(t.term)}</b> <span class="muted small">${esc(t.fullName)}</span><div class="small">${md(t.description)}</div></div>`).join("")}</div>` : "";
    }).join("") || `<p class="muted">見つかりませんでした</p>`;
  };
  document.getElementById("q").oninput = draw;
  draw();
}

async function newsList() {
  app.innerHTML = `<h1>PCIe ニュース</h1><div class="card list" id="news"><div class="item muted">読み込み中…</div></div>`;
  try {
    document.getElementById("news").innerHTML = (await loadNews()).map(newsRow).join("");
  } catch (_) {
    document.getElementById("news").innerHTML = `<div class="item muted">読み込めませんでした</div>`;
  }
}

// MARK: - クイズ（レベル別・ゲーム・Claude Code への依頼）

function quizMenuFull() {
  quizMenu();
  const best = P().quizBest || {};
  const levels = ["入門", "中級", "上級"];
  app.querySelector(".grid").insertAdjacentHTML("beforeend",
    `<a class="card" href="#/game/survival"><b>❤️ サバイバル</b><div class="muted small">自己ベスト ${(P().gameBest || {}).survival || 0} 問</div></a>`);
  app.querySelector("h2").insertAdjacentHTML("beforebegin", `<h2>レベル別</h2><div class="grid">${levels.map((lv) => {
    const ids = new Set(content.chapters.filter((c) => c.level === lv).map((c) => c.id));
    const n = content.questions.filter((q) => ids.has(q.chapterID)).length;
    return `<a class="card" href="#/quiz/level-${lv}"><b>${lv}</b><div class="muted small">${n}問・最高 ${best[`level-${lv}`] ?? "-"}%</div></a>`;
  }).join("")}</div>`);
}

/** Claude Code の新しいセッションを開くリンク（アプリの ClaudeCodeRequestView.sessionURL と同じ形） */
function claudeCodeURL(prompt) {
  const enc = (v) => encodeURIComponent(v);
  return `https://claude.ai/code/new?q=${enc(prompt)}&repo=${enc("marugenyori/pcie_study")}&branch=main`;
}

window.quizAfterHTML = (q, chosen) => {
  const picked = chosen >= 0 ? q.choices[chosen] : "わからない";
  const ask = `PCIe学習アプリのクイズ（${q.id}）について質問です。コードは変えずに、日本語で答えてください。\n\n問題：${q.question}\n選択肢：${q.choices.join(" / ")}\n正解：${q.choices[q.answer]}\n私の回答：${picked}\n解説：${q.explanation}\n\n質問：`;
  const rewrite = `PCIe学習アプリのクイズ（${q.id}）を見直してください。CLAUDE.md のクイズのルール（QuizData・QuizNotes・QuizDetails を全問そろえる）に従い、ビルド確認・マージ・TestFlight まで進めてください。\n\n問題：${q.question}\n選択肢：${q.choices.join(" / ")}\n正解：${q.choices[q.answer]}\n\n気になる点：`;
  return `<div class="row small" style="margin-top:8px">
    <a class="btn small" href="#/ask?q=${encodeURIComponent(q.question)}">PC の AI・仕様書に質問</a>
    <a class="btn small" href="${esc(claudeCodeURL(ask))}" target="_blank" rel="noopener">Claude Code に質問</a>
    <a class="btn small" href="${esc(claudeCodeURL(rewrite))}" target="_blank" rel="noopener">問題の作り直しを頼む</a></div>`;
};

/** サバイバル：ライフ3つ。間違えるか「わからない」でライフが減る */
function survival() {
  let lives = 3, correct = 0, combo = 0;
  const questions = shuffle(content.questions);
  const missed = [];
  let index = 0;
  const show = () => {
    const q = questions[index % questions.length];
    app.innerHTML = `
      <div class="row"><h1 style="margin:0">サバイバル</h1><span class="spacer"></span>
        <span class="hearts">${[0, 1, 2].map((i) => (i < lives ? "❤️" : "🤍")).join("")}</span></div>
      <p class="muted small">正解 ${correct} 問</p>
      <div class="card"><b>${esc(q.question)}</b></div>
      ${q.choices.map((c, i) => `<button class="choice" data-i="${i}">${esc(c)}</button>`).join("")}
      <button class="choice" data-i="-1">わからない</button>
      <div id="after"></div>`;
    app.querySelectorAll(".choice").forEach((b) => { b.onclick = () => answer(q, Number(b.dataset.i)); });
  };
  const answer = (q, chosen) => {
    const ok = chosen === q.answer;
    combo = ok ? combo + 1 : 0;
    if (ok) correct++;
    else { lives--; missed.push(q); }
    recordQuizAnswer(q.id, ok, combo);
    app.querySelectorAll(".choice").forEach((b) => {
      const i = Number(b.dataset.i);
      b.disabled = true;
      b.classList.add(i === q.answer ? "correct" : i === chosen ? "wrong" : "dimmed");
    });
    document.getElementById("after").innerHTML = `<div class="card"><b>${ok ? "⭕ 正解" : "❌"}</b><p>${md(q.explanation)}</p></div>
      <button class="btn primary" id="next">${lives > 0 ? "次の問題へ" : "結果を見る"}</button>`;
    document.getElementById("next").onclick = () => { if (lives > 0) { index++; show(); } else finish(); };
  };
  const finish = () => {
    const best = (P().gameBest || {}).survival || 0;
    const record = correct > best;
    P().gameBest = maxMap(P().gameBest, { survival: correct });
    save();
    app.innerHTML = `<h1>ゲームオーバー</h1>
      <div class="card"><div class="stat">${correct} 問正解</div><div class="muted small">${record ? "🎉 自己ベスト更新！" : `自己ベスト ${best} 問`}</div></div>
      ${missed.length ? `<h2>間違えた問題</h2><div class="card list">${missed.map((q) =>
        `<div class="item">${esc(q.question)}<div class="small" style="color:var(--good)">正解：${esc(q.choices[q.answer])}</div></div>`).join("")}</div>` : ""}
      <div class="row"><button class="btn primary" id="again">もう一度</button><a class="btn" href="#/quiz">クイズへ</a></div>`;
    document.getElementById("again").onclick = survival;
  };
  app.innerHTML = `<h1>サバイバル</h1><div class="card"><p>ライフは3つ。間違えるか「わからない」でライフが減ります。何問続けられるかな？</p>
    <p class="muted small">自己ベスト ${(P().gameBest || {}).survival || 0} 問</p><button class="btn primary" id="start">スタート</button></div>`;
  document.getElementById("start").onclick = show;
}

// MARK: - 質問する（仕様書の RAG・PC の AI・Claude Code）

async function askPage(query = "") {
  const initial = new URLSearchParams(query).get("q") || "";
  let target = localStorage.getItem("askTarget") || "spec";
  const history = [];
  app.innerHTML = `
    <h1>質問する</h1>
    <div class="row">${[["spec", "仕様書（PC）"], ["llm", "PC の AI"], ["claude", "Claude Code"]].map(([k, l]) =>
      `<button class="btn ${target === k ? "primary" : ""}" data-target="${k}">${l}</button>`).join("")}</div>
    <p class="muted small" id="hint"></p>
    <div id="chat"></div>
    <div class="card row"><textarea id="input" rows="2" style="flex:1" placeholder="質問を入力（日本語でOK）">${esc(initial)}</textarea>
      <button class="btn primary" id="send">送信</button></div>`;
  const hints = {
    spec: "PC にある仕様書（Base 7.1）から関係する箇所を探し、PC の AI が根拠付きで答えます。",
    llm: "PC の AI（Ollama）が答えます。仕様書は見ないので、用語の意味や仕組みのざっくりした説明に向いています（iPhone の「Apple AI」の代わり）。",
    claude: "質問を入れた Claude Code の新しいセッションを、別のタブで開きます。送信は自分で押してください。",
  };
  const drawTarget = () => {
    app.querySelectorAll("[data-target]").forEach((b) => b.classList.toggle("primary", b.dataset.target === target));
    document.getElementById("hint").textContent = hints[target];
  };
  app.querySelectorAll("[data-target]").forEach((b) => {
    b.onclick = () => { target = b.dataset.target; localStorage.setItem("askTarget", target); drawTarget(); };
  });
  drawTarget();

  const chat = document.getElementById("chat");
  const send = async () => {
    const input = document.getElementById("input");
    const question = input.value.trim();
    if (!question) return;
    input.value = "";
    const box = document.createElement("div");
    box.innerHTML = `<div class="bubble user">${esc(question)}</div><div class="card"><div class="answer muted">送信しています…</div><div class="sources"></div></div>`;
    chat.appendChild(box);
    const answer = box.querySelector(".answer");
    if (target === "claude") {
      window.open(claudeCodeURL(`PCIe学習アプリ（このリポジトリ）を使って PCIe を勉強している人からの質問です。コードは変えずに、日本語で、専門用語には短い説明を添えて答えてください。数値やビット位置を書くときは、PCIe Base Specification のどの章かも書いてください。\n\n質問：${question}`), "_blank");
      answer.textContent = "Claude Code を別のタブで開きました。内容を確かめて送信してください。";
      return;
    }
    let text = "";
    try {
      const url = target === "spec" ? "/api/ask" : "/api/llm/chat";
      const body = target === "spec"
        ? { q: question, history: history.slice(-2) }
        : { messages: [...history.flatMap((h) => [{ role: "user", content: h.q }, { role: "assistant", content: h.a }]), { role: "user", content: question }] };
      const res = await fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
      if (!res.ok) throw new Error(res.status === 404 ? "PC のサーバがこの機能に未対応です（docs/PC_WEB_EXTRAS.md の準備が必要）" : `HTTP ${res.status}`);
      // 1行に1つの JSON が流れてくる（アプリの SpecRAGClient.ask と同じ形）
      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";
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
          if (ev.type === "status") answer.textContent = ev.text;
          else if (ev.type === "token") { text += ev.t; answer.classList.remove("muted"); answer.innerHTML = md(text).replace(/\n/g, "<br>"); }
          else if (ev.type === "sources") {
            box.querySelector(".sources").innerHTML = `<details><summary class="small">根拠にした仕様書の箇所（${ev.results.length}件）</summary>${ev.results.map((s) =>
              `<div class="small"><b>[${s.n}] ${s.num ? `§${esc(s.num)} ` : ""}${esc(s.title)}</b> <span class="muted">${esc(s.doc)}・p.${s.page}</span><div class="muted">${esc(s.text)}</div></div>`).join("")}</details>`;
          } else if (ev.type === "error") throw new Error(ev.message);
        }
      }
      history.push({ q: question, a: text });
      box.querySelector(".card").insertAdjacentHTML("beforeend", `<p class="muted small">AIは誤ることがあります。数値やビット位置は仕様書の原文で確認してください。</p>`);
    } catch (e) {
      answer.innerHTML = `<span style="color:var(--bad)">${esc(e.message)}</span>`;
    }
  };
  document.getElementById("send").onclick = send;
  document.getElementById("input").onkeydown = (e) => { if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) send(); };
}

// MARK: - 表示の設定（アプリの「表示」と同じテーマ色・文字の大きさ）

const themes = { lime: "#58cc02", blue: "#007aff", indigo: "#5856d6", teal: "#30b0c7", green: "#34c759", orange: "#ff9500", pink: "#ff2d55", purple: "#af52de" };
const themeNames = { lime: "ライム", blue: "ブルー", indigo: "インディゴ", teal: "ティール", green: "グリーン", orange: "オレンジ", pink: "ピンク", purple: "パープル" };
function applySettings() {
  const theme = localStorage.getItem("theme");
  const size = localStorage.getItem("textSize") || "100";
  const appearance = localStorage.getItem("appearance") || "system";
  const root = document.documentElement;
  if (theme && themes[theme]) {
    root.style.setProperty("--tint", themes[theme]);
    root.style.setProperty("--tint-soft", `${themes[theme]}26`);
  } else {
    root.style.removeProperty("--tint");
    root.style.removeProperty("--tint-soft");
  }
  root.style.fontSize = `${size}%`;
  if (appearance === "system") root.removeAttribute("data-theme");
  else root.setAttribute("data-theme", appearance);
}

function settingsPage() {
  const theme = localStorage.getItem("theme") || "teal";
  const size = localStorage.getItem("textSize") || "100";
  const appearance = localStorage.getItem("appearance") || "system";
  app.innerHTML = `<h1>表示の設定</h1>
    <div class="card">
      <h2>テーマ色</h2><div class="row">${Object.keys(themes).map((k) =>
        `<button class="btn ${k === theme ? "primary" : ""}" data-theme="${k}" style="${k === theme ? `background:${themes[k]}` : `color:${themes[k]}`}">${themeNames[k]}</button>`).join("")}</div>
      <h2>文字の大きさ</h2><select id="size">${[["87", "小さめ"], ["100", "標準"], ["112", "大きめ"], ["125", "とても大きい"], ["150", "特大"]].map(([v, l]) =>
        `<option value="${v}" ${v === size ? "selected" : ""}>${l}</option>`).join("")}</select>
      <h2>外観</h2><select id="appearance">${[["system", "PC の設定に合わせる"], ["light", "ライト"], ["dark", "ダーク"]].map(([v, l]) =>
        `<option value="${v}" ${v === appearance ? "selected" : ""}>${l}</option>`).join("")}</select>
    </div>
    <div class="card"><h2>iPhone との同期</h2><p class="small">${serverAvailable ? "PC のサーバとつながっています。" : "PC のサーバとつながっていません。"}</p>
      <button class="btn" id="sync">今すぐ同期</button></div>`;
  app.querySelectorAll("[data-theme]").forEach((b) => { b.onclick = () => { localStorage.setItem("theme", b.dataset.theme); applySettings(); settingsPage(); }; });
  document.getElementById("size").onchange = (e) => { localStorage.setItem("textSize", e.target.value); applySettings(); };
  document.getElementById("appearance").onchange = (e) => { localStorage.setItem("appearance", e.target.value); applySettings(); };
  document.getElementById("sync").onclick = async () => { save(); toast("同期しています…"); };
}

// MARK: - 画面の登録（app.js の同じ画面より先に当てはめる）

routes.unshift(
  [/^#?\/?$/, todayHome],
  [/^#\/learn$/, learnHome],
  [/^#\/columns$/, columnList],
  [/^#\/column\/(.+)$/, columnDetail],
  [/^#\/glossary$/, glossary],
  [/^#\/news$/, newsList],
  [/^#\/quiz$/, quizMenuFull],
  [/^#\/game\/survival$/, survival],
  [/^#\/ask(?:\?(.*))?$/, askPage],
  [/^#\/settings$/, settingsPage],
);
applySettings();
