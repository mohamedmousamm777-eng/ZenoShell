.pragma library

// Pure logic of the weather panel (maps, colors, parsing): no Quickshell here, so it can be tested.

const TS = 256

// ---------- Web Mercator ----------
function worldSize(z) { return TS * Math.pow(2, z) }
function lonToX(lon, z) { return (lon + 180) / 360 * worldSize(z) }
function latToY(lat, z) {
    const l = Math.max(-85.0511, Math.min(85.0511, lat)) * Math.PI / 180
    return (1 - Math.log(Math.tan(l) + 1 / Math.cos(l)) / Math.PI) / 2 * worldSize(z)
}
function xToLon(x, z) { return x / worldSize(z) * 360 - 180 }
function yToLat(y, z) {
    const n = Math.PI * (1 - 2 * y / worldSize(z))
    return 180 / Math.PI * Math.atan(0.5 * (Math.exp(n) - Math.exp(-n)))
}

// ---------- Text ----------
const days = {
    en: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
    it: ["Dom", "Lun", "Mar", "Mer", "Gio", "Ven", "Sab"]
}

const words = {
    en: {
        today: "Today", uv: "UV", feels: "Feels like", humidity: "Humidity", wind: "Wind", pressure: "Pressure",
        visibility: "Visibility", air: "Air quality", sunrise: "Sunrise", sunset: "Sunset",
        temp: "Temperature", cloud: "Clouds", rain: "Rain", press: "Pressure", windl: "Wind",
        low: "Low", high: "High", loading: "Loading…", offline: "No connection", retry: "Retry",
        refresh: "Refresh", changePlace: "Change location", myLocation: "Use my approximate location",
        search: "Search a city…", noResults: "No cities found",
        mapOffline: "Map tiles unavailable",
        c0: "Clear", c1: "Mostly clear", c2: "Partly cloudy", c3: "Cloudy", c45: "Fog", c51: "Drizzle", c61: "Rain",
        c71: "Snow", c80: "Showers", c95: "Thunderstorm",
        aq0: "Good", aq1: "Fair", aq2: "Moderate", aq3: "Poor", aq4: "Very poor", aq5: "Extremely poor",
        zoomIn: "Zoom in", zoomOut: "Zoom out", locate: "Center on my place",
        askTitle: "Weather & map",
        askText: "To show the weather and the map, ZenoShell needs to use the internet. Nothing is sent until you allow it.",
        askWeather: "Weather and air quality: Open-Meteo (open-meteo.com)",
        askMap: "Map: CARTO / OpenStreetMap tiles, saved in a local cache",
        askIp: "Approximate location (optional): an IP location service, only if you choose it",
        allowAuto: "Allow, use my approximate location", allowCity: "Allow, I will choose a city", notNow: "Not now",
        needsPlace: "Choose where to show the weather"
    },
    it: {
        today: "Oggi", uv: "UV", feels: "Percepita", humidity: "Umidità", wind: "Vento", pressure: "Pressione",
        visibility: "Visibilità", air: "Aria", sunrise: "Alba", sunset: "Tramonto",
        temp: "Temperatura", cloud: "Nuvole", rain: "Pioggia", press: "Pressione", windl: "Vento",
        low: "Bassa", high: "Alta", loading: "Caricamento…", offline: "Nessuna connessione", retry: "Riprova",
        refresh: "Aggiorna", changePlace: "Cambia posizione", myLocation: "Usa la mia posizione approssimativa",
        search: "Cerca una città…", noResults: "Nessuna città trovata",
        mapOffline: "Mappa non disponibile",
        c0: "Sereno", c1: "Prevalentemente sereno", c2: "Parzialmente nuvoloso", c3: "Nuvoloso", c45: "Nebbia", c51: "Pioviggine", c61: "Pioggia",
        c71: "Neve", c80: "Rovesci", c95: "Temporale",
        aq0: "Buona", aq1: "Discreta", aq2: "Moderata", aq3: "Scadente", aq4: "Molto scadente", aq5: "Pessima",
        zoomIn: "Ingrandisci", zoomOut: "Riduci", locate: "Centra sul mio luogo",
        askTitle: "Meteo e mappa",
        askText: "Per mostrare il meteo e la mappa ZenoShell deve usare internet. Non viene inviato nulla finché non lo permetti.",
        askWeather: "Meteo e qualità dell'aria: Open-Meteo (open-meteo.com)",
        askMap: "Mappa: tessere CARTO / OpenStreetMap, salvate in una cache locale",
        askIp: "Posizione approssimativa (facoltativa): un servizio di localizzazione via IP, solo se lo scegli",
        allowAuto: "Consenti, usa la mia posizione approssimativa", allowCity: "Consenti, scelgo una città", notNow: "Non ora",
        needsPlace: "Scegli dove mostrare il meteo"
    }
}

function tr(lang, key) {
    const t = words[lang] || words.en
    return t[key] !== undefined ? t[key] : (words.en[key] !== undefined ? words.en[key] : key)
}

function dayLabel(dateStr, lang, i) {
    if (i === 0) return tr(lang, "today")
    const p = dateStr.split("-")
    const d = new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))
    return (days[lang] || days.en)[d.getDay()]
}

// ---------- Conditions (WMO codes) ----------
// kind: clear, partly, cloud, fog, drizzle, rain, snow, storm
function kindOf(code) {
    if (code === 0 || code === 1) return "clear"
    if (code === 2) return "partly"
    if (code === 3) return "cloud"
    if (code === 45 || code === 48) return "fog"
    if (code >= 51 && code <= 57) return "drizzle"
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return "rain"
    if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow"
    if (code >= 95) return "storm"
    return "cloud"
}

function condText(code, lang) {
    const k = kindOf(code)
    const key = { clear: code === 0 ? "c0" : "c1", partly: "c2", cloud: "c3", fog: "c45", drizzle: "c51",
                  rain: code >= 80 ? "c80" : "c61", snow: "c71", storm: "c95" }[k]
    return tr(lang, key)
}

// Air quality (European index)
function aqiInfo(v) {
    if (v < 0) return { key: "", t: 0 }
    const key = v <= 20 ? "aq0" : v <= 40 ? "aq1" : v <= 60 ? "aq2" : v <= 80 ? "aq3" : v <= 100 ? "aq4" : "aq5"
    return { key: key, t: Math.max(0, Math.min(1, v / 100)) }
}

// ---------- Parsing ----------
function hhmm(s) { return s ? s.slice(11, 16) : "" }
function toMin(s) {
    if (!s) return -1
    return parseInt(s.slice(11, 13)) * 60 + parseInt(s.slice(14, 16))
}

// Result of api.open-meteo.com/v1/forecast (one place)
function parseForecast(j) {
    const c = j.current
    if (!c) throw "no current"
    const hour = c.time ? c.time.slice(0, 13) : ""
    let idx = -1
    if (j.hourly && j.hourly.time) {
        for (let i = 0; i < j.hourly.time.length; i++) if (j.hourly.time[i].slice(0, 13) === hour) { idx = i; break }
    }
    const at = (name, fallback) => (idx >= 0 && j.hourly[name] && j.hourly[name][idx] !== null && j.hourly[name][idx] !== undefined)
        ? j.hourly[name][idx] : fallback
    const d = j.daily || {}
    const n = d.time ? d.time.length : 0
    const list = []
    for (let i = 0; i < Math.min(5, n); i++)
        list.push({ date: d.time[i], code: d.weather_code[i], lo: d.temperature_2m_min[i], hi: d.temperature_2m_max[i] })
    return {
        temp: c.temperature_2m, feels: c.apparent_temperature, hum: c.relative_humidity_2m,
        code: c.weather_code, isDay: c.is_day !== 0,
        wind: c.wind_speed_10m, press: c.surface_pressure,
        uv: at("uv_index", c.uv_index !== undefined ? c.uv_index : 0),
        vis: at("visibility", c.visibility !== undefined ? c.visibility : -1),
        placeNow: toMin(c.time),
        sunrise: d.sunrise ? hhmm(d.sunrise[0]) : "", sunset: d.sunset ? hhmm(d.sunset[0]) : "",
        sunriseMin: d.sunrise ? toMin(d.sunrise[0]) : -1, sunsetMin: d.sunset ? toMin(d.sunset[0]) : -1,
        days: list
    }
}

// ---------- Grid for the map layers ----------
const COLS = 9
const ROWS = 6

function gridQuery(s, n, w, e) {
    const lats = [], lons = []
    for (let r = 0; r < ROWS; r++) {
        for (let c = 0; c < COLS; c++) {
            lats.push((n - (n - s) * r / (ROWS - 1)).toFixed(3))
            lons.push((w + (e - w) * c / (COLS - 1)).toFixed(3))
        }
    }
    return { lat: lats.join(","), lon: lons.join(",") }
}

function parseGrid(j, s, n, w, e) {
    const arr = Array.isArray(j) ? j : [j]
    if (arr.length !== COLS * ROWS) throw "grid size"
    const g = { s: s, n: n, w: w, e: e, cols: COLS, rows: ROWS, temp: [], cloud: [], rain: [], press: [], wind: [], dir: [] }
    for (let i = 0; i < arr.length; i++) {
        const c = arr[i].current || {}
        g.temp.push(c.temperature_2m)
        g.cloud.push(c.cloud_cover)
        g.rain.push(c.precipitation)
        g.press.push(c.pressure_msl)
        g.wind.push(c.wind_speed_10m)
        g.dir.push(c.wind_direction_10m)
    }
    return g
}

// Bilinear value at a coordinate; NaN outside the grid
function sample(g, vals, lat, lon) {
    const fr = (g.n - lat) / (g.n - g.s) * (g.rows - 1)
    const fc = (lon - g.w) / (g.e - g.w) * (g.cols - 1)
    if (!(fr >= -0.01 && fr <= g.rows - 0.99 && fc >= -0.01 && fc <= g.cols - 0.99)) return NaN
    const r = Math.max(0, Math.min(g.rows - 1, fr)), c = Math.max(0, Math.min(g.cols - 1, fc))
    const r0 = Math.min(g.rows - 2, Math.floor(r)), c0 = Math.min(g.cols - 2, Math.floor(c))
    const ty = r - r0, tx = c - c0
    const v = (rr, cc) => vals[rr * g.cols + cc]
    const a = v(r0, c0), b = v(r0, c0 + 1), d = v(r0 + 1, c0), f = v(r0 + 1, c0 + 1)
    if ([a, b, d, f].some(x => typeof x !== "number")) return NaN
    return (a * (1 - tx) + b * tx) * (1 - ty) + (d * (1 - tx) + f * tx) * ty
}

// ---------- Layers ----------
const keyOf = { temp: "temp", wind: "wind", cloud: "cloud", rain: "rain", press: "press" }

const ramps = {
    temp:  [[0, 59, 91, 219], [0.25, 45, 190, 230], [0.5, 80, 200, 120], [0.72, 245, 210, 60], [0.88, 245, 140, 50], [1, 225, 60, 60]],
    wind:  [[0, 205, 232, 242], [0.35, 110, 190, 210], [0.7, 60, 130, 200], [1, 85, 60, 165]],
    cloud: [[0, 245, 245, 250], [1, 120, 128, 150]],
    rain:  [[0, 120, 200, 245], [0.5, 50, 120, 230], [1, 120, 50, 200]],
    press: [[0, 130, 80, 190], [0.5, 70, 170, 190], [1, 240, 200, 80]]
}

function rampColor(stops, t) {
    t = Math.max(0, Math.min(1, t))
    for (let i = 1; i < stops.length; i++) {
        if (t <= stops[i][0]) {
            const a = stops[i - 1], b = stops[i]
            const u = (t - a[0]) / (b[0] - a[0])
            return [a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u]
        }
    }
    const l = stops[stops.length - 1]
    return [l[1], l[2], l[3]]
}

// Normalized range of a layer in the loaded grid (and the text of the two ends)
function range(layer, g, units) {
    const imp = units === "imperial"
    const vals = (g && g[keyOf[layer]]) ? g[keyOf[layer]].filter(x => typeof x === "number") : []
    let lo = 0, hi = 1
    if (vals.length) { lo = Math.min.apply(null, vals); hi = Math.max.apply(null, vals) }
    if (layer === "temp") {
        lo = Math.floor(lo); hi = Math.ceil(hi); if (hi - lo < 4) hi = lo + 4
        return { lo: lo, hi: hi, loText: lo + "°", hiText: hi + "°" }
    }
    if (layer === "wind") {
        lo = 0; hi = Math.max(imp ? 20 : 30, Math.ceil(hi / 10) * 10)
        return { lo: lo, hi: hi, loText: "0", hiText: hi + (imp ? " mph" : " km/h") }
    }
    if (layer === "cloud") return { lo: 0, hi: 100, loText: "0%", hiText: "100%" }
    if (layer === "rain") {
        lo = 0; hi = Math.max(2, Math.ceil(hi))
        return { lo: lo, hi: hi, loText: "0", hiText: hi + " mm" }
    }
    lo = Math.floor(lo); hi = Math.ceil(hi); if (hi - lo < 8) { lo -= 4; hi += 4 }
    return { lo: lo, hi: hi, loText: String(lo), hiText: hi + " hPa" }
}

// RGBA (0..255, alpha 0..1) of a value in a layer
function layerColor(layer, v, lo, hi) {
    const t = (v - lo) / (hi - lo)
    const c = rampColor(ramps[layer], t)
    let a = 0.55
    if (layer === "cloud") a = Math.max(0, Math.min(1, t)) * 0.8
    else if (layer === "rain") a = t < 0.02 ? 0 : 0.3 + 0.55 * Math.min(1, t)
    return [Math.round(c[0]), Math.round(c[1]), Math.round(c[2]), a]
}

function fmtNum(v, d) {
    if (typeof v !== "number") return "–"
    return d ? v.toFixed(d) : String(Math.round(v))
}
