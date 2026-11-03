// ブラウザ版の図解・ツール・「英語で聞く」のスライド
//
// 数値やデータは content.json（アプリの PCIeCalc・TLPHeaderModel・LTSSMModel・TopologySample から書き出したもの）を使う。
"use strict";

const hex = (n, width) => n.toString(16).toUpperCase().padStart(width, "0");
const parseHex = (text) => {
  const t = String(text).trim().replace(/^0x/i, "");
  return /^[0-9a-f]+$/i.test(t) ? BigInt(`0x${t}`) : null;
};
const formatGBps = (v) => (v < 1 ? `${Math.round(v * 1000)} MB/s` : `${v.toFixed(2)} GB/s`);
function formatBytes(bytes) {
  const units = [[1n << 40n, "TB"], [1n << 30n, "GB"], [1n << 20n, "MB"], [1n << 10n, "KB"]];
  for (const [unit, name] of units) {
    if (bytes >= unit) {
      const v = Number(bytes) / Number(unit);
      return Number.isInteger(v) ? `${v} ${name}` : `${v.toFixed(2)} ${name}`;
    }
  }
  return `${bytes} B`;
}
const result = (title, value, caption = "") =>
  `<div class="card result"><div class="muted small">${esc(title)}</div><div class="stat">${esc(value)}</div>${caption ? `<div class="muted small">${esc(caption)}</div>` : ""}</div>`;
const gens = () => content.diagrams.generations;

// MARK: - ツール

function toolsHome() {
  app.innerHTML = `<h1>ツール</h1><div class="grid">
    <a class="card" href="#/tool/bandwidth"><b>帯域幅計算</b><div class="muted small">世代とレーン数から実効帯域を計算</div></a>
    <a class="card" href="#/tool/tlp"><b>TLP転送効率</b><div class="muted small">ペイロードサイズとヘッダのオーバーヘッド</div></a>
    <a class="card" href="#/tool/ecam"><b>ECAMアドレス計算</b><div class="muted small">BDF ⇄ コンフィグ空間アドレス</div></a>
    <a class="card" href="#/tool/bar"><b>BARサイズ判定</b><div class="muted small">全1書き込み後の読み戻し値から計算</div></a>
    <a class="card" href="#/clips"><b>配信で英語</b><div class="muted small">録画した動画のスクリプトで練習</div></a>
  </div>`;
}

const genOptions = (selected) => gens().map((g) => `<option value="${g.gen}" ${g.gen === selected ? "selected" : ""}>${g.name}（${g.rate} GT/s）</option>`).join("");
const laneOptions = (selected) => [1, 2, 4, 8, 16].map((l) => `<option ${l === selected ? "selected" : ""}>${l}</option>`).join("");

function bandwidthTool() {
  app.innerHTML = `<h1>帯域幅計算</h1><div class="card row">
    <label>世代 <select id="gen">${genOptions(5)}</select></label>
    <label>レーン数 x<select id="lanes">${laneOptions(16)}</select></label></div><div id="out"></div>`;
  const draw = () => {
    const g = gens().find((x) => x.gen === Number(document.getElementById("gen").value));
    const lanes = Number(document.getElementById("lanes").value);
    const per = (g.rate * g.efficiency * lanes) / 8;
    document.getElementById("out").innerHTML = `<div class="grid">
      ${result("片方向の帯域（符号化後）", formatGBps(per))}
      ${result("双方向の合計", formatGBps(per * 2))}
      ${g.isFlit ? result("FLITのTLP領域（236/256）を考慮した片方向", formatGBps(per * content.diagrams.flitTLPRatio)) : ""}</div>
      <p class="muted small">符号化：${esc(g.encoding)}　生の値（符号化前）: ${((g.rate * lanes) / 8).toFixed(2)} GB/s</p>`;
  };
  app.querySelectorAll("select").forEach((s) => { s.onchange = draw; });
  draw();
}

function tlpTool() {
  app.innerHTML = `<h1>TLP転送効率</h1><div class="card row">
    <label>ペイロード <select id="payload">${[0, 4, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096].map((p) => `<option ${p === 256 ? "selected" : ""}>${p}</option>`).join("")}</select> B</label>
    <label><input type="checkbox" id="dw4"> 64ビットアドレス（4DWヘッダ）</label>
    <label><input type="checkbox" id="ecrc"> ECRC付き</label>
    <label>世代 <select id="gen">${genOptions(4).replace(/<option value="[67]".*?<\/option>/g, "")}</select></label>
    <label>x<select id="lanes">${laneOptions(16)}</select></label></div>
    <p class="muted small">条件（Gen1〜5・非FLIT）：フレーミング・Seq#・LCRC で1 TLPあたり ${content.diagrams.tlpFramingOverhead} バイト</p><div id="out"></div>
    <p class="small">ペイロードが小さいほどヘッダの割合が増え、効率が下がります。MPS（Max Payload Size）を大きくするとDMAの効率が上がりますが、経路上の全デバイスが対応する値に揃える必要があります。</p>`;
  const draw = () => {
    const payload = Number(document.getElementById("payload").value);
    const header = document.getElementById("dw4").checked ? 16 : 12;
    const total = payload + header + (document.getElementById("ecrc").checked ? 4 : 0) + content.diagrams.tlpFramingOverhead;
    const eff = total ? payload / total : 0;
    const g = gens().find((x) => x.gen === Number(document.getElementById("gen").value));
    const lanes = Number(document.getElementById("lanes").value);
    document.getElementById("out").innerHTML = `<div class="grid">${result("TLP転送効率", `${(eff * 100).toFixed(1)}%`, `${payload} B / ${total} B`)}
      ${result(`${g.name} x${lanes} での実効データ帯域（目安）`, formatGBps(((g.rate * g.efficiency * lanes) / 8) * eff))}</div>`;
  };
  app.querySelectorAll("select, input").forEach((s) => { s.onchange = draw; });
  draw();
}

function ecamTool() {
  app.innerHTML = `<h1>ECAMアドレス計算</h1>
    <div class="card"><h2>BDF → アドレス</h2><div class="row">
      <label>ECAM Base 0x<input type="text" id="base" value="E0000000" style="width:10em"></label>
      <label>Bus <input type="number" id="bus" min="0" max="255" value="1"></label>
      <label>Device <input type="number" id="dev" min="0" max="31" value="0"></label>
      <label>Function <input type="number" id="fn" min="0" max="7" value="0"></label>
      <label>Offset 0x<input type="text" id="off" value="000" style="width:5em"></label></div><div id="out1"></div></div>
    <div class="card"><h2>アドレス → BDF</h2><label>アドレス 0x<input type="text" id="addr" value="E0100000" style="width:12em"></label><div id="out2"></div></div>
    <p class="small">ECAMは1 Functionあたり4KB、1バスあたり 32×8×4KB = 1MB、256バスで256MBの領域を使います。Baseの値はACPIのMCFGテーブルに記載されています（Linuxでは dmesg の「MMCONFIG」や「ECAM」で確認できます）。</p>`;
  const draw = () => {
    const base = parseHex(document.getElementById("base").value);
    const off = parseHex(document.getElementById("off").value);
    const bus = BigInt(Math.min(255, Math.max(0, Number(document.getElementById("bus").value) || 0)));
    const dev = BigInt(Math.min(31, Math.max(0, Number(document.getElementById("dev").value) || 0)));
    const fn = BigInt(Math.min(7, Math.max(0, Number(document.getElementById("fn").value) || 0)));
    document.getElementById("out1").innerHTML = base === null || off === null || off > 0xFFFn
      ? `<p style="color:var(--bad)" class="small">16進数で入力してください（Offsetは 000〜FFF）</p>`
      : result(`${hex(Number(bus), 2)}:${hex(Number(dev), 2)}.${fn} + 0x${hex(Number(off), 3)}`,
        `0x${(base + (bus << 20n) + (dev << 15n) + (fn << 12n) + off).toString(16).toUpperCase()}`);
    const addr = parseHex(document.getElementById("addr").value);
    if (base === null || addr === null || addr < base) {
      document.getElementById("out2").innerHTML = `<p class="muted small">Base 以上のアドレスを16進数で入力してください</p>`;
      return;
    }
    const d = addr - base;
    document.getElementById("out2").innerHTML = result("BDF ＋ レジスタ",
      `${hex(Number((d >> 20n) & 0xFFn), 2)}:${hex(Number((d >> 15n) & 0x1Fn), 2)}.${(d >> 12n) & 7n} + 0x${hex(Number(d & 0xFFFn), 3)}`)
      + (d >= 0x10000000n ? `<p class="small" style="color:orange">256バス分（256MB）の範囲を超えています</p>` : "");
  };
  app.querySelectorAll("input").forEach((s) => { s.oninput = draw; });
  draw();
}

function barTool() {
  app.innerHTML = `<h1>BARサイズ判定</h1><div class="card">
    <label>BAR 読み戻し値 0x<input type="text" id="low" value="FFF0000C" style="width:10em"></label>
    <label id="hiLabel">上位BAR 読み戻し値 0x<input type="text" id="high" value="FFFFFFFF" style="width:10em"></label>
    <p class="muted small">全ビット1を書き込んだ後の読み戻し値</p></div><div id="out"></div>
    <div class="card small"><b>手順</b><ol><li>BARの元の値を保存</li><li>FFFFFFFFh を書き込む</li><li>読み戻す（固定0のビットがサイズを表す）</li>
      <li>属性ビットをマスクし、ビット反転して +1</li><li>元の値を書き戻す</li></ol></div>`;
  const draw = () => {
    const low = parseHex(document.getElementById("low").value);
    const high = parseHex(document.getElementById("high").value);
    const out = document.getElementById("out");
    const invalid = () => { out.innerHTML = `<p style="color:var(--bad)" class="small">有効な値を16進数で入力してください（0 は未実装のBARを意味します）</p>`; };
    if (low === null || low > 0xFFFFFFFFn) return invalid();
    const is64 = (low & 1n) === 0n && ((low >> 1n) & 3n) === 2n;
    document.getElementById("hiLabel").style.display = is64 ? "" : "none";
    if (low & 1n) {
      const mask = low & 0xFFFFFFFCn;
      if (!mask) return invalid();
      out.innerHTML = `<div class="grid">${result("BARサイズ", formatBytes(((~mask) + 1n) & 0xFFFFFFFFn))}${result("種類", "I/O 空間")}</div>`;
      return;
    }
    const lowMask = low & 0xFFFFFFF0n;
    const combined = is64 ? (((high ?? 0xFFFFFFFFn) & 0xFFFFFFFFn) << 32n) | lowMask : 0xFFFFFFFF00000000n | lowMask;
    if (combined === 0xFFFFFFFF00000000n || combined === 0n) return invalid();
    const size = ((~combined) + 1n) & 0xFFFFFFFFFFFFFFFFn;
    out.innerHTML = `<div class="grid">${result("BARサイズ", formatBytes(size))}
      ${result("種類", `メモリ空間・${is64 ? "64" : "32"}ビット`, (low >> 3n) & 1n ? "プリフェッチ可" : "プリフェッチ不可")}</div>`;
  };
  app.querySelectorAll("input").forEach((s) => { s.oninput = draw; });
  draw();
}

// MARK: - 図解

function diagramsHome() {
  app.innerHTML = `<h1>図解</h1><div class="grid">
    <a class="card" href="#/diagram/topology"><b>トポロジとBDF</b><div class="muted small">RC・スイッチ・EPの階層をクリックして確認</div></a>
    <a class="card" href="#/diagram/layers"><b>レイヤとカプセル化</b><div class="muted small">TLPが各層で包まれる様子をステップ表示</div></a>
    <a class="card" href="#/diagram/tlp"><b>TLPヘッダ構造</b><div class="muted small">各フィールドをクリック／Fmt・Typeデコーダ</div></a>
    <a class="card" href="#/diagram/acknak"><b>ACK/NAK 再送シミュレータ</b><div class="muted small">エラーを注入して再送の動きを体験</div></a>
    <a class="card" href="#/diagram/ltssm"><b>LTSSM 状態遷移</b><div class="muted small">リンクアップの流れを再生・手動遷移</div></a>
  </div>`;
}

function topologyDiagram() {
  const all = [];
  const walk = (n, depth) => { all.push({ ...n, depth }); n.children.forEach((c) => walk(c, depth + 1)); };
  walk(content.diagrams.topology, 0);
  let selected = all[1];
  const draw = () => {
    app.innerHTML = `<h1>トポロジとBDF</h1><div class="topo">${all.map((n) => `
      <button class="topo-node ${n.id === selected.id ? "on" : ""}" data-id="${esc(n.id)}" style="margin-left:${n.depth * 22}px">
        <b>${esc(n.name)}</b> <span class="muted small">${esc(n.kind)}${n.bdf ? `・${esc(n.bdf)}` : ""}${n.header ? `・${esc(n.header)}` : ""}</span></button>`).join("")}</div>
      <div class="card"><b>${esc(selected.name)}</b> <span class="badge">${esc(selected.kind)}</span>
        ${selected.bdf ? `<div class="small">BDF：${esc(selected.bdf)}</div>` : ""}${selected.header ? `<div class="small">ヘッダ：${esc(selected.header)}</div>` : ""}
        <p>${esc(selected.detail)}</p></div>`;
    app.querySelectorAll(".topo-node").forEach((b) => { b.onclick = () => { selected = all.find((n) => n.id === b.dataset.id); draw(); }; });
  };
  draw();
}

function layersDiagram() {
  let step = 0, mode = "gen12", payload = 64, dw4 = false, ecrc = false;
  const colors = { 0: "#3b82f6", 1: "#22c55e", 2: "#f59e0b" };
  const notes = [
    "トランザクション層がヘッダとデータからTLPを作ります。必要ならend-to-endのECRCを付けます。",
    "データリンク層が12ビットのシーケンス番号と32ビットのLCRCを付けます。このTLPは再送に備えてリプレイバッファに保持されます。",
    "",
  ];
  const draw = () => {
    const seg = [];
    if (step >= 2) seg.push(mode === "gen12" ? ["STP", 1, 2] : ["STPトークン（Seq#含む）", 4, 2]);
    if (step >= 1 && !(step >= 2 && mode === "gen35")) seg.push(["Seq#", 2, 1]);
    seg.push(["Header", dw4 ? 16 : 12, 0]);
    if (payload > 0) seg.push(["Data", payload, 0]);
    if (ecrc) seg.push(["ECRC", 4, 0]);
    if (step >= 1) seg.push(["LCRC", 4, 1]);
    if (step >= 2 && mode === "gen12") seg.push(["END", 1, 2]);
    const total = seg.reduce((a, s) => a + s[1], 0);
    const note = step < 2 ? notes[step] : mode === "gen12"
      ? "物理層がSTPとENDの特殊シンボルで囲み、8b/10b符号化してレーンに振り分けます。"
      : "物理層がSTPトークン（長さとシーケンス番号を含む4バイト）を先頭に付けます。ENDはなく、長さで終端を判断します。128b/130bのブロックに詰めてレーンに振り分けます。";
    app.innerHTML = `<h1>レイヤとカプセル化</h1>
      <div class="row">${["トランザクション層", "データリンク層", "物理層"].map((l, i) => `<button class="btn ${step === i ? "primary" : ""}" data-step="${i}">${i + 1}. ${l}</button>`).join("")}</div>
      <div class="card"><div class="packet">${seg.map(([label, bytes, layer]) =>
        `<div class="seg" style="background:${colors[layer]};flex:${label === "Data" ? Math.max(4, Math.min(bytes / 8, 12)) : Math.max(bytes / 2, 1)}">${esc(label)}<br><small>${bytes} B</small></div>`).join("")}</div>
        <p class="small">合計 <b>${total} B</b>　効率 ${total ? ((payload / total) * 100).toFixed(1) : "-"}%</p><p>${esc(note)}</p></div>
      <div class="card row">
        <label>物理層 <select id="mode"><option value="gen12" ${mode === "gen12" ? "selected" : ""}>Gen1/2</option><option value="gen35" ${mode === "gen35" ? "selected" : ""}>Gen3〜5</option></select></label>
        <label>ペイロード <input type="number" id="payload" min="0" max="512" step="16" value="${payload}"> バイト</label>
        <label><input type="checkbox" id="dw4" ${dw4 ? "checked" : ""}> 64ビットアドレス（4DWヘッダ）</label>
        <label><input type="checkbox" id="ecrc" ${ecrc ? "checked" : ""}> ECRCを付ける（TD=1）</label></div>`;
    app.querySelectorAll("[data-step]").forEach((b) => { b.onclick = () => { step = Number(b.dataset.step); draw(); }; });
    document.getElementById("mode").onchange = (e) => { mode = e.target.value; draw(); };
    document.getElementById("payload").onchange = (e) => { payload = Math.max(0, Math.min(512, Number(e.target.value) || 0)); draw(); };
    document.getElementById("dw4").onchange = (e) => { dw4 = e.target.checked; draw(); };
    document.getElementById("ecrc").onchange = (e) => { ecrc = e.target.checked; draw(); };
  };
  draw();
}

function tlpDiagram() {
  const formats = content.diagrams.tlpFormats;
  let format = formats[0], field = format.fields[0];
  const draw = () => {
    const rows = [];
    for (let dw = 0; dw < format.dwCount; dw++) {
      const fields = format.fields.filter((f) => f.dw === dw).sort((a, b) => b.hi - a.hi);
      rows.push(`<div class="dw"><span class="muted small">DW${dw}</span><div class="bits">${fields.map((f) =>
        `<button class="bitfield ${f === field ? "on" : ""}" data-dw="${dw}" data-hi="${f.hi}" style="flex:${f.hi - f.lo + 1}" title="${esc(f.fullName)}">${esc(f.name)}</button>`).join("")}</div></div>`);
    }
    app.innerHTML = `<h1>TLPヘッダ構造</h1>
      <div class="row">${formats.map((f, i) => `<button class="btn ${f === format ? "primary" : ""}" data-format="${i}">${esc(f.name)}</button>`).join("")}</div>
      <div class="card"><div class="muted small">bit 31 ← → bit 0</div>${rows.join("")}</div>
      <div class="card"><b>${esc(field.fullName)}</b> <span class="muted small">DW${field.dw}・${field.hi === field.lo ? `bit ${field.hi}` : `bit ${field.hi}:${field.lo}`}</span><p>${esc(field.detail)}</p></div>
      <div class="card"><h2>Fmt・Type デコーダ</h2><label>Byte 0 = 0x<input type="text" id="byte0" value="40" style="width:5em"></label>
        <div id="decoded"></div><p class="muted small">例：00 = MRd 3DW、40 = MWr 3DW、4A = CplD、04 = CfgRd0、34 = Msg</p></div>`;
    app.querySelectorAll("[data-format]").forEach((b) => { b.onclick = () => { format = formats[Number(b.dataset.format)]; field = format.fields[0]; draw(); }; });
    app.querySelectorAll(".bitfield").forEach((b) => {
      b.onclick = () => { field = format.fields.find((f) => f.dw === Number(b.dataset.dw) && f.hi === Number(b.dataset.hi)); draw(); };
    });
    const decode = () => {
      const v = parseHex(document.getElementById("byte0").value);
      const n = v === null || v > 255n ? null : Number(v);
      document.getElementById("decoded").innerHTML = n === null ? `<p class="muted small">00〜FF の16進数で入力してください</p>`
        : `<p>Fmt = ${(n >> 5).toString(2).padStart(3, "0")}、Type = ${(n & 31).toString(2).padStart(5, "0")} → <b>${esc(content.diagrams.tlpTypeNames[n])}</b></p>`;
    };
    document.getElementById("byte0").oninput = decode;
    decode();
  };
  draw();
}

/** ACK/NAK 再送シミュレータ（アプリの AckNakSimulator と同じ動き） */
function ackNakDiagram() {
  const MOD = 4096, LIMIT = 4;
  const sim = { next: 0, buffer: [], link: [], rcv: 0, received: [], replayNum: 0, log: [], retrain: 0, dropNext: false };
  const add = (kind, text) => sim.log.push({ kind, text });
  const before = (a, b) => { const d = (b - a + MOD) % MOD; return d !== 0 && d < MOD / 2; };
  const replay = () => {
    sim.replayNum++;
    if (sim.replayNum >= LIMIT) { sim.retrain++; add("warn", `REPLAY_NUM が ${LIMIT} に到達 → 物理層がRecoveryでリンクを再トレーニング`); sim.replayNum = 0; }
    for (const seq of sim.buffer) { sim.link.push({ seq, bad: false, replay: true }); add("tx", `TX: TLP #${seq} を再送`); }
  };
  const send = (bad) => {
    const seq = sim.next;
    sim.buffer.push(seq);
    sim.link.push({ seq, bad, replay: false });
    sim.next = (sim.next + 1) % MOD;
    add("tx", `TX: TLP #${seq} を送信${bad ? "（途中でビット化け）" : ""}`);
  };
  const deliver = (isAck, seq) => {
    const name = isAck ? "ACK" : "NAK";
    add(isAck ? "ack" : "nak", `RX → TX: ${name} ${seq} を送信`);
    if (sim.dropNext) { sim.dropNext = false; add("warn", `${name} DLLP がCRCエラーで失われた！送信側は何も受け取れない`); return; }
    const count = sim.buffer.length;
    sim.buffer = sim.buffer.filter((s) => before(seq, s));
    const freed = count - sim.buffer.length;
    if (freed > 0) { sim.replayNum = 0; add(isAck ? "ack" : "nak", `TX: #${seq} までの ${freed} 個をバッファから解放`); }
    if (!isAck) {
      if (!sim.buffer.length) add("nak", "TX: 再送対象なし");
      else { add("nak", `TX: NAK受信 → #${sim.buffer[0]} 以降を再送`); replay(); }
    }
  };
  const process = () => {
    if (!sim.link.length) { add("warn", "リンク上に処理するTLPがありません"); return; }
    let nak = false, ack = false;
    for (const p of sim.link) {
      if (p.bad) { add("rx", `RX: TLP #${p.seq} のLCRCエラー → 破棄`); nak = true; continue; }
      if (p.seq === sim.rcv) {
        if (nak) { add("rx", `RX: TLP #${p.seq} はNAK後の後続TLP扱いで破棄`); continue; }
        sim.received.push(p.seq);
        sim.rcv = (sim.rcv + 1) % MOD;
        add("rx", `RX: TLP #${p.seq} を受理${p.replay ? "（再送分）" : ""}`);
        ack = true;
      } else if (before(p.seq, sim.rcv)) { add("rx", `RX: TLP #${p.seq} は受信済み（重複）→ 破棄してACK`); ack = true; }
      else { add("rx", `RX: TLP #${p.seq} は期待値 #${sim.rcv} より先 → 欠落を検出、破棄`); nak = true; }
    }
    sim.link = [];
    const last = (sim.rcv - 1 + MOD) % MOD;
    if (nak) deliver(false, last); else if (ack) deliver(true, last);
  };
  const timer = () => {
    if (!sim.buffer.length) { add("warn", "リプレイバッファが空なのでタイマは動いていません"); return; }
    add("warn", "TX: REPLAY_TIMER 満了 → バッファ内のTLPを再送");
    replay();
  };
  const colors = { tx: "var(--tint)", rx: "var(--text)", ack: "var(--good)", nak: "var(--bad)", warn: "orange" };
  const draw = () => {
    app.innerHTML = `<h1>ACK/NAK 再送シミュレータ</h1>
      <div class="grid">
        <div class="card"><b>送信側</b><div class="small">NEXT_TRANSMIT_SEQ：${sim.next}</div><div class="small">REPLAY_NUM：${sim.replayNum}・再トレーニング ${sim.retrain} 回</div>
          <div class="small">リプレイバッファ：${sim.buffer.length ? sim.buffer.map((s) => `#${s}`).join(" ") : "（空）"}</div></div>
        <div class="card"><b>リンク上</b><div class="small">${sim.link.length ? sim.link.map((p) => `#${p.seq}${p.bad ? "⚡" : ""}${p.replay ? "↻" : ""}`).join(" ") : "（なし）"}</div></div>
        <div class="card"><b>受信側</b><div class="small">NEXT_RCV_SEQ：${sim.rcv}</div><div class="small">受理：${sim.received.slice(-12).map((s) => `#${s}`).join(" ") || "（なし）"}</div></div>
      </div>
      <div class="row">
        <button class="btn primary" data-a="send">TLPを送る</button><button class="btn" data-a="bad">ビット化けしたTLPを送る</button>
        <button class="btn" data-a="rx">受信側が処理</button><button class="btn" data-a="timer">REPLAY_TIMER 満了</button>
        <label><input type="checkbox" id="drop" ${sim.dropNext ? "checked" : ""}> 次の ACK/NAK を失わせる</label>
        <button class="btn small" data-a="reset">リセット</button></div>
      <div class="card log">${sim.log.slice(-30).reverse().map((l) => `<div class="small" style="color:${colors[l.kind]}">${esc(l.text)}</div>`).join("") || `<span class="muted small">ボタンを押すと、ここに動きが出ます</span>`}</div>`;
    app.querySelectorAll("[data-a]").forEach((b) => {
      b.onclick = () => {
        ({ send: () => send(false), bad: () => send(true), rx: process, timer,
          reset: () => Object.assign(sim, { next: 0, buffer: [], link: [], rcv: 0, received: [], replayNum: 0, log: [], retrain: 0, dropNext: false }) })[b.dataset.a]();
        draw();
      };
    });
    document.getElementById("drop").onchange = (e) => { sim.dropNext = e.target.checked; };
  };
  draw();
}

function ltssmDiagram() {
  const model = content.diagrams.ltssm;
  const states = Object.fromEntries(model.states.map((s) => [s.id, s]));
  let current = model.initial, step = -1, timer = null;
  const draw = () => {
    const state = states[current];
    const note = step >= 0 ? model.scenarioNotes[step] : "";
    app.innerHTML = `<h1>LTSSM 状態遷移</h1>
      <div class="ltssm">${model.groups.map((g) => `<span class="ltssm-group ${state.group === g ? "on" : ""}">${esc(g)}</span>`).join("")}</div>
      <div class="card"><div class="muted small">${esc(state.group)}</div><h2 style="margin-top:0">${esc(state.id)}</h2><p>${esc(state.description)}</p>
        ${note ? `<div class="note">${esc(note)}</div>` : ""}
        <b class="small">次の状態へ（クリックで進む）</b>
        ${state.transitions.map((t) => `<button class="choice" data-to="${esc(t.to)}"><b>${esc(t.to)}</b><div class="muted small">${esc(t.condition)}</div></button>`).join("")}</div>
      <div class="row"><button class="btn primary" id="play">${timer ? "■ 止める" : "▶ リンクアップの流れを再生"}</button>
        <button class="btn" id="reset">最初に戻す</button>
        ${step >= 0 ? `<span class="muted small">${step + 1} / ${model.scenario.length}</span>` : ""}</div>`;
    app.querySelectorAll("[data-to]").forEach((b) => { b.onclick = () => { stop(); current = b.dataset.to; step = -1; draw(); }; });
    document.getElementById("play").onclick = () => { if (timer) { stop(); draw(); } else play(); };
    document.getElementById("reset").onclick = () => { stop(); current = model.initial; step = -1; draw(); };
  };
  const stop = () => { clearInterval(timer); timer = null; };
  const play = () => {
    step = 0;
    current = model.scenario[0];
    timer = setInterval(() => {
      if (!document.querySelector(".ltssm")) return stop();
      if (step >= model.scenario.length - 1) { stop(); draw(); return; }
      step++;
      current = model.scenario[step];
      draw();
    }, 1600);
    draw();
  };
  cleanup = stop;
  draw();
}

// MARK: - 「英語で聞く」のスライド（アプリの EnglishSlides.swift と同じ図）

/** 箱：[文字, 説明, 強調するか] */
const B = (text, detail, on) => ({ text, detail, on });
const A = (symbol, label, on) => ({ arrow: symbol, label, on });
function slideHTML(rows, note) {
  const cell = (c) => c.arrow
    ? `<div class="s-arrow ${c.on ? "on" : ""}">${c.arrow}${c.label ? `<small>${esc(c.label)}</small>` : ""}</div>`
    : `<div class="s-box ${c.on ? "on" : ""}"><b>${esc(c.text)}</b>${c.detail ? `<small>${esc(c.detail)}</small>` : ""}</div>`;
  return `<div class="slide">${rows.map((r) => `<div class="s-row">${r.map(cell).join("")}</div>`).join("")}<div class="s-note">${esc(note)}</div></div>`;
}

const slideDefs = {
  "en-layers": (i) => {
    const all = i === 0, tx = (n) => all || i === n, rx = all || i === 5;
    return [[[B("送る側", "", false), A("", "", false), B("受ける側", "", false)],
      [B("Transaction", "TLP を作る", tx(1)), A("", "", false), B("Transaction", "TLP を作る", rx)],
      [B("Data Link", i === 3 ? "↻ 再送" : "Seq / LCRC", all || i === 2 || i === 3), A("", "", false), B("Data Link", "Seq / LCRC", rx)],
      [B("Physical", "電気信号", tx(4)), A("→", "レーン", all || i === 4), B("Physical", "電気信号", rx)]],
      ["PCIe は3つの層でできている", "読み書きの依頼 → TLP（パケット）", "Seq番号 ＋ TLP ＋ LCRC", "壊れていたら自動で送り直す", "電気信号にしてレーンで送る", "受ける側は下から上へ"][i]];
  },
  "en-topology": (i) => [[[B("CPU ・ メモリ", "", i <= 1)], [A("↓", "", i <= 1)], [B("Root Complex", "木の根", i <= 1)],
    [A("↓", i === 4 ? "リンク（2つのポートをつなぐ）" : "", i === 0 || i === 4)], [B("Switch", i === 3 ? "上り1つ ・ 下り複数" : "", i === 0 || i === 3)],
    [A("↙", "", [0, 3, 5].includes(i)), A("↘", "", [0, 3, 5].includes(i))],
    [B("Endpoint", "SSD", i === 0 || i === 2), B("Endpoint", "ネットワークカード", i === 0 || i === 2)]],
    ["PCIe は木の形", "Root Complex が CPU とメモリをつなぐ", "SSD などの機器 ＝ Endpoint", "Switch で機器を増やせる", "1本のリンク ＝ 両端に1つずつのポート", "PCI と違い、線を共有しない（1対1）"][i]],
  "en-tlp": (i) => [[[B("Header", i === 1 ? "3〜4 DW" : i === 5 ? "Requester ID ・ Tag" : "", [0, 1, 5].includes(i)), B("Data", "なくてもよい", i === 0 || i === 3), B("ECRC", "なくてもよい", i === 0)],
    [B("Requester", "依頼する側", i >= 2), A("→", i === 2 ? "Memory Write" : "Memory Read", i >= 2), B("Completer", "答える側", i >= 2)],
    [A(i === 4 ? "⏰" : "←", i === 3 || i === 5 ? "Completion" : i === 4 ? "返事が来ない" : "返事なし", i >= 2)]],
    ["ヘッダ ＋ データ ＋ ECRC", "1 DW（ダブルワード）＝ 4 バイト", "書き込みは posted：返事を待たない", "読み出しは non-posted：データ付きの Completion が返る", "答えがなければ Completion Timeout", "Requester ID と Tag で、どの依頼の答えか分かる"][i]],
  "en-replay": (i) => [[[B("送る側", "再送バッファ：" + (i === 1 ? "2 3" : "1 2 3"), true), A(i === 1 ? "←" : i === 2 ? "←" : i === 3 ? "⏱" : "→", i === 1 ? "ACK" : i === 2 ? "NAK" : i === 3 ? "時間切れ" : "TLP", [0, 1, 2, 3].includes(i)), B("受ける側", i === 2 ? "壊れた TLP" : "TLP を確認", [1, 2].includes(i))],
    ...(i >= 4 ? [[B("0", "", true), B("1", "", true), B("2", "", true), B("3", "", true), A("→", "", i === 5), B("Recovery", "再トレーニング", i === 5)]] : [])],
    ["送ったものは、確認が取れるまで取っておく", "ACK が来たらバッファから消す", "NAK が来たら、バッファに残っている TLP を再送", "返事がないと REPLAY_TIMER が切れて再送", "REPLAY_NUM：続けて再送した回数", "回数があふれたら、信号を疑ってリンクを立ち上げ直す"][i]],
  "en-credits": (i) => [[[B("送る側", "", [0, 4].includes(i)), A(i === 4 ? "←" : i === 1 ? "←" : "→", i === 4 ? "UpdateFC" : i === 1 ? "空き＝クレジット" : "TLP", [0, 1, 4].includes(i)), B("受ける側", "バッファ", [0, 1, 4].includes(i))],
    ...(i === 2 ? [[B("", "", false), B("Posted", "", true), B("Non-Posted", "", true), B("Completion", "", true)], [B("Header", "", true), B("□", "", true), B("□", "", true), B("□", "", true)], [B("Data", "", true), B("□", "", true), B("□", "", true), B("□", "", true)]] : []),
    ...(i === 3 ? [[B("1 クレジット", "", true), A("=", "", true), B("16 バイト", "", true), A("=", "", true), B("4 DW", "", true)]] : []),
    ...(i === 5 ? [[B("初期化で 0", "", true), A("→", "", true), B("∞", "無限", true)]] : [])],
    ["受け取れる分しか送らない", "受ける側が空きをクレジットで知らせる", "ヘッダとデータ × 3種類で別々に数える", "データのクレジットは 16 バイト単位", "空いたら UpdateFC でクレジットを返す", "最初に 0 を知らせる ＝ 無限"][i]],
  "en-lanes": (i) => [i === 1 || i === 2 ? [[1, 2, 4, 8, 16].map((w) => B(`x${w}`, "▬".repeat(Math.min(w, 8)), w === 16 && i === 2 || i === 1))]
    : i === 3 || i === 4 ? [[B("8b/10b", "20% が無駄", i === 3)], [B("128b/130b", "約 1.5%", i === 4)]]
    : i === 5 ? [[B("データ", "0 1 1 0 1 …", true), A("→", "", true), B("クロックを取り出す", "専用のクロック線なし", true)]]
    : [[B("デバイス A", "", true), A("⇄", "送信用ペア・受信用ペア", true), B("デバイス B", "", true)]],
    ["1レーン ＝ 送信と受信の差動ペア2組", "リンクの幅は x1〜x16", "x16 ＝「by sixteen」と読む", "第1・第2世代は 8b/10b", "8 GT/s からは 128b/130b", "クロックはデータの流れから取り出す"][i]],
  "en-ltssm": (i) => [[[B("Detect", "相手がいるか確かめる", i === 0 || i === 1)], [A("↓", "", i <= 2)], [B("Polling", "ビットと記号を合わせる", i === 0 || i === 2)],
    [A("↓", "", i === 0 || i === 3)], [B("Configuration", "幅とレーン番号を決める", i === 0 || i === 3)], [A("↓", "", i === 0 || i === 4)],
    [B("L0", "ふだんの状態", [0, 4, 5].includes(i)), A("⇄", "", i === 5), B("Recovery", "立て直す・速度を変える", i === 5)]],
    ["LTSSM ＝ リンクを立ち上げる状態マシン", "Detect：つながっているか", "Polling：トレーニング用の信号をやりとり", "Configuration：何レーンで使うか決める", "L0：TLP と DLLP が流れる", "問題や速度変更は Recovery を通って L0 へ戻る"][i]],
  "en-config": (i) => [[[B("0〜255 バイト", "PCI と同じ部分（Vendor ID ・ BAR など）", i <= 4)], [B("256 バイト〜4 KB", "PCIe で広がった部分", i === 0)],
    ...(i === 2 ? [[B("Bus", "", true), B("Device", "", true), B("Function", "", true), A("→", "", true), B("Vendor ID", "読めたら機器あり", true)]] : []),
    ...(i === 3 ? [[B("BAR", "", true), A("→", "", true), B("必要なメモリの大きさ", "", true)]] : []),
    ...(i === 4 ? [[B("BAR", "", true), A("→", "全部 1 を書く", true), B("読み戻す", "下の 0 の数で大きさが分かる", true)]] : []),
    ...(i === 5 ? [[B("CPU", "", true), A("→", "ふつうのメモリ読み書き", true), B("ECAM", "コンフィグ空間", true)]] : [])],
    ["機能ごとに 4 KB のコンフィグ空間", "最初の 256 バイトは PCI と互換", "番号ごとに Vendor ID を読む ＝ 列挙", "BAR：必要なメモリの大きさを示す", "全部 1 を書いて読み戻すと大きさが分かる", "ECAM ならメモリの読み書きでアクセスできる"][i]],
  "en-msi": (i) => [i <= 1 ? [[B("デバイス", "", true), A(i === 0 ? "⚡" : "✉", i === 0 ? "専用の線（INTx）" : "メッセージで代わりに送る", true), B("CPU", "", true)]]
    : i <= 3 ? [[B("デバイス", "", true), A("→", i === 3 ? "データの書き込み → 特別なアドレスへの書き込み" : "特別なアドレスへの書き込み", true), B("CPU", "割り込み", true)]]
    : [[0, 1, 2, 3].map((n) => B(`ベクタ ${n}`, `キュー ${n}`, true)), [0, 1, 2, 3].map((n) => B(`コア ${n}`, "", i === 5))],
    ["昔の PCI は専用の線で割り込み", "PCIe には割り込みの線がない", "MSI：メモリへの書き込みで割り込む", "ただの書き込みなので、前に書いたデータを追い越さない", "MSI-X：最大 2048 個のベクタ", "コアごとに自分のキューを処理できる"][i]],
  "en-gen6": (i) => [i === 1 || i === 2 ? [[B("NRZ", "2段階 ＝ 1ビット", true), B("PAM4", i === 2 ? "4段階 ＝ 2ビット（段の差が小さい）" : "4段階 ＝ 2ビット", true)]]
    : i === 3 || i === 5 ? [[B("受信", "", true), A("→", "", true), B("FEC", "ほとんど直す", true), A("→", "", i === 5), B("CRC", "直せない分は再送", i === 5)]]
    : i === 4 ? [[B("TLP ・ DLLP", "", true), B("CRC", "", true), B("FEC", "", true)]]
    : [[B("PCIe 5.0", "32 GT/s", false), A("→", "2倍", true), B("PCIe 6.0", "64 GT/s", true)]],
    ["PCIe 6.0 は 64 GT/s", "速くする代わりに、1回で2ビット送る", "段階の差が小さいので、ノイズに弱い", "軽い FEC（前方誤り訂正）を追加", "決まった大きさのフリット（256 バイト）で送る", "FEC で直せないものは CRC で見つけて再送"][i]],
};
window.renderSlide = (lessonID, index) => {
  const def = slideDefs[lessonID];
  if (!def) return "";
  const [rows, note] = def(index);
  return slideHTML(rows, note);
};

// MARK: - 画面の登録

routes.unshift(
  [/^#\/tools$/, toolsHome],
  [/^#\/tool\/bandwidth$/, bandwidthTool],
  [/^#\/tool\/tlp$/, tlpTool],
  [/^#\/tool\/ecam$/, ecamTool],
  [/^#\/tool\/bar$/, barTool],
  [/^#\/diagrams$/, diagramsHome],
  [/^#\/diagram\/topology$/, topologyDiagram],
  [/^#\/diagram\/layers$/, layersDiagram],
  [/^#\/diagram\/tlp$/, tlpDiagram],
  [/^#\/diagram\/acknak$/, ackNakDiagram],
  [/^#\/diagram\/ltssm$/, ltssmDiagram],
);
