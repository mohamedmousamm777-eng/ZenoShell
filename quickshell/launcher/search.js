.pragma library

// Pure logic of the launcher: no Quickshell here, so it is easy to test.

// ---------- Web ----------
// Edit this list to add or change engines. The first one is the default.
const engines = [
    { key: "g",   name: "Google",     url: "https://www.google.com/search?q=%s" },
    { key: "ddg", name: "DuckDuckGo", url: "https://duckduckgo.com/?q=%s" },
    { key: "yt",  name: "YouTube",    url: "https://www.youtube.com/results?search_query=%s" },
    { key: "gh",  name: "GitHub",     url: "https://github.com/search?q=%s" },
    { key: "wp",  name: "Wikipedia",  url: "https://en.wikipedia.org/w/index.php?search=%s" },
    { key: "mp",  name: "Maps",       url: "https://www.google.com/maps/search/%s" }
]

function engineUrl(engine, text) {
    return engine.url.replace("%s", encodeURIComponent(text))
}

function looksLikeUrl(q) {
    if (/\s/.test(q)) return false
    if (/^https?:\/\/\S+$/i.test(q)) return true
    return /^(www\.)?[a-z0-9-]+(\.[a-z0-9-]+)*\.(com|org|net|io|dev|it|eu|app|co|me|ai|tv|gg|xyz|info|edu|gov|uk|de|fr|es|ch|us|cloud)(\/\S*)?$/i.test(q)
}

function toUrl(q) {
    return /^https?:\/\//i.test(q) ? q : "https://" + q
}

// ---------- Query parsing ----------
// Returns { mode, arg, engine }
// mode: "" (normal), "cmd", "bg", "files", "web", "windows", "clip", "emoji"
function parse(raw) {
    const q = raw.replace(/^\s+/, "")
    let m

    if (q.startsWith(">")) return { mode: "cmd", arg: q.slice(1).trim() }
    if (q.startsWith("!")) return { mode: "bg", arg: q.slice(1).trim() }
    if (q.startsWith("/") || q.startsWith("~/")) return { mode: "files", arg: q.replace(/^~?\//, "").trim() }
    if ((m = /^f\s+(.*)$/i.exec(q))) return { mode: "files", arg: m[1].trim() }
    if ((m = /^w(\s+(.*))?$/i.exec(q)) && (q.length === 1 || /^w\s/i.test(q)))
        return { mode: "windows", arg: (m[2] || "").trim() }
    if ((m = /^c(\s+(.*))?$/i.exec(q)) && (q.length === 1 || /^c\s/i.test(q)))
        return { mode: "clip", arg: (m[2] || "").trim() }
    if (q.startsWith(":")) return { mode: "emoji", arg: q.slice(1).trim().toLowerCase() }

    for (let i = 0; i < engines.length; i++) {
        const e = engines[i]
        if (q.toLowerCase() === e.key + " " || q.toLowerCase().startsWith(e.key + " "))
            return { mode: "web", arg: q.slice(e.key.length).trim(), engine: e }
    }
    return { mode: "", arg: raw.trim() }
}

// ---------- Calculator ----------
const fns = {
    sqrt: Math.sqrt, abs: Math.abs, sin: Math.sin, cos: Math.cos, tan: Math.tan,
    asin: Math.asin, acos: Math.acos, atan: Math.atan, ln: Math.log, log: Math.log10,
    exp: Math.exp, round: Math.round, floor: Math.floor, ceil: Math.ceil
}
const consts = { pi: Math.PI, e: Math.E }

function tokenize(s) {
    const t = []
    let i = 0
    while (i < s.length) {
        const c = s[i]
        if (/\s/.test(c)) { i++; continue }
        let m
        if ((m = /^(\d+([.,]\d+)?|[.,]\d+)/.exec(s.slice(i)))) {
            t.push({ n: parseFloat(m[0].replace(",", ".")) })
            i += m[0].length
        } else if ((m = /^[a-z]+/i.exec(s.slice(i)))) {
            t.push({ id: m[0].toLowerCase() })
            i += m[0].length
        } else if (s.startsWith("**", i)) { t.push({ op: "^" }); i += 2 }
        else if ("+-*/^%()×÷".indexOf(c) >= 0) {
            t.push({ op: c === "×" ? "*" : (c === "÷" ? "/" : c) })
            i++
        } else return null
    }
    return t
}

// Returns a number, or null if the text is not an expression.
function evalExpr(s) {
    const t = tokenize(s)
    if (!t || t.length === 0) return null
    let p = 0
    let used = false           // had at least an operator or a function

    const peek = () => t[p]
    const isOp = o => t[p] && t[p].op === o

    function expr() {
        let v = term()
        while (isOp("+") || isOp("-")) {
            const o = t[p++].op
            const r = term()
            v = o === "+" ? v + r : v - r
        }
        return v
    }
    function term() {
        let v = unary()
        while (isOp("*") || isOp("/") || (isOp("%") && startsOperand(p + 1))) {
            const o = t[p++].op
            const r = unary()
            v = o === "*" ? v * r : (o === "/" ? v / r : v % r)
        }
        return v
    }
    function startsOperand(i) {
        const x = t[i]
        return !!x && (x.n !== undefined || x.id !== undefined || x.op === "(" || x.op === "-" || x.op === "+")
    }
    function unary() {
        if (isOp("-")) { p++; used = true; return -unary() }
        if (isOp("+")) { p++; used = true; return unary() }
        return power()
    }
    function power() {
        let v = postfix()
        if (isOp("^")) { p++; used = true; v = Math.pow(v, unary()) }
        return v
    }
    function postfix() {
        let v = atom()
        while (isOp("%") && !startsOperand(p + 1)) { p++; used = true; v = v / 100 }
        return v
    }
    function atom() {
        const x = peek()
        if (!x) throw "end"
        if (x.n !== undefined) { p++; return x.n }
        if (x.op === "(") {
            p++
            const v = expr()
            if (!isOp(")")) throw "paren"
            p++
            return v
        }
        if (x.id !== undefined) {
            p++
            if (fns[x.id]) {
                if (!isOp("(")) throw "fn"
                p++
                const v = expr()
                if (!isOp(")")) throw "paren"
                p++
                used = true
                return fns[x.id](v)
            }
            if (consts[x.id] !== undefined) return consts[x.id]
            throw "id"
        }
        throw "tok"
    }

    try {
        const v = expr()
        if (p !== t.length) return null
        if (!used && t.length === 1) return null
        if (!used && t.every(x => x.n !== undefined || x.id !== undefined)) return null
        if (typeof v !== "number" || !isFinite(v)) return null
        return v
    } catch (e) {
        return null
    }
}

function fmt(v) {
    let s = parseFloat(v.toPrecision(12)).toString()
    if (s.indexOf("e") >= 0) s = v.toExponential(6)
    return s
}

// ---------- Units ----------
// Factors to a base unit per family; temperature is handled apart.
const units = {
    km: ["len", 1000], m: ["len", 1], cm: ["len", 0.01], mm: ["len", 0.001],
    mi: ["len", 1609.344], ft: ["len", 0.3048], in: ["len", 0.0254], yd: ["len", 0.9144],
    kg: ["mass", 1], g: ["mass", 0.001], mg: ["mass", 0.000001], lb: ["mass", 0.45359237], oz: ["mass", 0.028349523125],
    l: ["vol", 1], ml: ["vol", 0.001], gal: ["vol", 3.785411784], cup: ["vol", 0.2365882365],
    b: ["data", 1], kb: ["data", 1e3], mb: ["data", 1e6], gb: ["data", 1e9], tb: ["data", 1e12],
    kib: ["data", 1024], mib: ["data", 1048576], gib: ["data", 1073741824],
    s: ["time", 1], min: ["time", 60], h: ["time", 3600], d: ["time", 86400],
    c: ["temp", 0], f: ["temp", 0], k: ["temp", 0]
}

function convert(text) {
    const m = /^\s*(-?\d+(?:[.,]\d+)?)\s*°?([a-z]+)\s+(?:to|in|->|→|a)\s+°?([a-z]+)\s*$/i.exec(text)
    if (!m) return null
    const n = parseFloat(m[1].replace(",", "."))
    const a = m[2].toLowerCase(), b = m[3].toLowerCase()
    const ua = units[a], ub = units[b]
    if (!ua || !ub || ua[0] !== ub[0]) return null
    let out
    if (ua[0] === "temp") {
        const c = a === "c" ? n : (a === "f" ? (n - 32) * 5 / 9 : n - 273.15)
        out = b === "c" ? c : (b === "f" ? c * 9 / 5 + 32 : c + 273.15)
    } else {
        out = n * ua[1] / ub[1]
    }
    return { value: fmt(out), unit: m[3] }
}

// ---------- System ----------
const system = [
    { id: "lock",     name: "Lock screen", words: ["lock", "lock screen", "blocca"],              action: "lock",     danger: false, glyph: "L" },
    { id: "suspend",  name: "Suspend",     words: ["suspend", "sleep", "sospendi"],               action: "suspend",  danger: false, glyph: "S" },
    { id: "logout",   name: "Log out",     words: ["logout", "log out", "exit", "esci"],          action: "logout",   danger: true,  glyph: "O" },
    { id: "reboot",   name: "Restart",     words: ["reboot", "restart", "riavvia"],               action: "reboot",   danger: true,  glyph: "R" },
    { id: "shutdown", name: "Shut down",   words: ["shutdown", "shut down", "poweroff", "power off", "spegni"], action: "shutdown", danger: true, glyph: "P" }
]

function matchSystem(q) {
    const s = q.trim().toLowerCase()
    if (s.length < 2) return []
    return system.filter(x => x.words.some(w => w.startsWith(s)))
}

// ---------- Emoji ----------
const emojiData = (
    "😀 grinning smile happy|😂 laugh joy tears lol|🙂 slight smile|😉 wink|😍 love heart eyes|😘 kiss|😎 cool sunglasses|" +
    "🤔 thinking hmm|😅 sweat nervous|😭 cry sob sad|😡 angry mad|🥳 party celebrate|😴 sleep tired|🤯 mind blown|😬 grimace|" +
    "🙄 eye roll|😇 angel innocent|🤗 hug|🤝 handshake deal|👍 thumbs up yes ok|👎 thumbs down no|👏 clap applause|🙏 pray thanks please|" +
    "💪 strong muscle|👋 wave hello bye|✌️ peace victory|🤞 fingers crossed luck|👀 eyes look|🧠 brain|❤️ heart love red|💔 broken heart|" +
    "🔥 fire hot|✨ sparkles magic|⭐ star|🌟 glowing star|💯 hundred perfect|✅ check done yes|❌ cross no|⚠️ warning|❓ question|" +
    "❗ exclamation|💡 idea bulb|🎉 tada party|🎁 gift present|🎂 cake birthday|🍕 pizza|🍔 burger|🍟 fries|🍺 beer|☕ coffee|🍷 wine|" +
    "🍎 apple|🍌 banana|🍓 strawberry|🥑 avocado|🍰 dessert|🐶 dog|🐱 cat|🐭 mouse|🐻 bear|🦊 fox|🐧 penguin linux tux|🐍 snake python|" +
    "🦀 crab rust|🐘 elephant|🦄 unicorn|🌍 earth world|🌙 moon night|☀️ sun|⛅ cloud|🌧️ rain|❄️ snow cold|⚡ lightning bolt|🌈 rainbow|" +
    "🌸 flower blossom|🌳 tree|🚀 rocket launch|✈️ plane flight|🚗 car|🚲 bike|🏠 home house|🏖️ beach|⛰️ mountain|💻 laptop computer|" +
    "🖥️ desktop monitor|⌨️ keyboard|🖱️ mouse computer|📱 phone mobile|🔋 battery|🔌 plug power|📷 camera photo|🎧 headphones music|🎵 music note|" +
    "🎮 game controller|📚 books|📝 note memo write|📌 pin|📎 paperclip|🔒 lock secure|🔑 key|🔍 search magnifier|🛠️ tools wrench|⚙️ gear settings|" +
    "🧪 test tube|📦 package box|💰 money bag|💸 money fly|📈 chart up|📉 chart down|⏰ alarm clock|⌛ hourglass wait|📅 calendar|" +
    "➡️ arrow right|⬅️ arrow left|⬆️ arrow up|⬇️ arrow down|🔄 refresh reload|♻️ recycle|➕ plus add|➖ minus|✔️ tick|©️ copyright|™️ trademark|" +
    "€ euro|£ pound|¥ yen|° degree|× multiply times|÷ divide|≈ approx|≠ not equal|≤ less equal|≥ greater equal|∞ infinity|π pi|→ arrow|… ellipsis"
).split("|").map(s => {
    const i = s.indexOf(" ")
    return { ch: s.slice(0, i), words: s.slice(i + 1) }
})

function matchEmoji(q) {
    const s = q.trim().toLowerCase()
    const out = []
    for (let i = 0; i < emojiData.length && out.length < 60; i++) {
        const e = emojiData[i]
        if (s === "" || e.words.indexOf(s) >= 0) out.push(e)
    }
    return out
}

function shortPath(p, home) {
    return home && p.startsWith(home) ? "~" + p.slice(home.length) : p
}
