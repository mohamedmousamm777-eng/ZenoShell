pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "../weather/wx.js" as W

// Weather and map. Nothing goes on the network until the user allows it (consent).
// Services used, only after the permission:
//   - Open-Meteo: forecast, air quality, city search, grid of values for the map layers
//   - CARTO / OpenStreetMap: map tiles (downloaded by scripts/maptiles.sh into a local cache)
//   - ipwho.is (or geojs.io): approximate location from the IP, only if the user chooses "automatic"
Singleton {
    id: root

    // ---------- Saved settings ----------
    property bool consent: false           // the user allowed internet access for this feature
    property bool autoLocation: true
    property bool hasPlace: false
    property real lat: 0
    property real lon: 0
    property string place: ""
    property string units: "metric"        // metric | imperial
    property string lang: "en"             // en | it
    property string mapStyle: "auto"       // auto | light | dark
    property int refreshMin: 30
    property string layer: "temp"          // temp | wind | cloud | rain | press

    // ---------- Panel ----------
    property bool open: false
    property string screenName: ""

    function openPanel() {
        Settings.open = false
        screenName = Compositor.focusedMonitor
        open = true
    }
    function closePanel() { open = false }
    function togglePanel() { if (open) closePanel(); else openPanel() }

    // ---------- Data ----------
    property var wx: null                  // result of W.parseForecast
    property real aqi: -1
    property real fetchedAt: 0
    property bool loading: false
    property string error: ""

    property var grid: null
    property real gridAt: 0
    property bool gridBusy: false

    property var results: []               // city search
    property bool searching: false
    property int searchSeq: 0

    signal placePicked()

    function tr(key) { return W.tr(lang, key) }

    // ---------- Storage ----------
    readonly property string cfgPath: Quickshell.env("HOME") + "/.local/state/quickshell/weather.json"

    FileView {
        id: cfg
        path: root.cfgPath
        blockLoading: true
        printErrors: false
    }

    function save() {
        try {
            cfg.setText(JSON.stringify({
                consent: consent, autoLocation: autoLocation, hasPlace: hasPlace, lat: lat, lon: lon, place: place,
                units: units, lang: lang, mapStyle: mapStyle, refreshMin: refreshMin, layer: layer
            }))
        } catch (e) {}
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/quickshell"])
        try {
            const d = JSON.parse(cfg.text())
            if (typeof d.consent === "boolean") consent = d.consent
            if (typeof d.autoLocation === "boolean") autoLocation = d.autoLocation
            if (typeof d.hasPlace === "boolean" && typeof d.lat === "number" && typeof d.lon === "number") {
                hasPlace = d.hasPlace; lat = d.lat; lon = d.lon
            }
            if (typeof d.place === "string") place = d.place
            if (d.units === "metric" || d.units === "imperial") units = d.units
            if (d.lang === "en" || d.lang === "it") lang = d.lang
            if (d.mapStyle === "auto" || d.mapStyle === "light" || d.mapStyle === "dark") mapStyle = d.mapStyle
            if (d.refreshMin === 15 || d.refreshMin === 30 || d.refreshMin === 60) refreshMin = d.refreshMin
            if (["temp", "wind", "cloud", "rain", "press"].indexOf(d.layer) >= 0) layer = d.layer
        } catch (e) {}
    }

    function set(key, value) {
        root[key] = value
        save()
        if (key === "units") { grid = null; refresh() }
    }

    function setConsent(on) {
        consent = on
        save()
        if (!on) { loading = false; error = "" }
        else if (hasPlace) refresh()
        else if (autoLocation) locate()
    }

    // ---------- Network ----------
    function get(url, ok, fail) {
        const x = new XMLHttpRequest()
        x.timeout = 15000
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status === 200) {
                let j = null
                try { j = JSON.parse(x.responseText) } catch (e) { fail("bad data"); return }
                ok(j)
            } else {
                fail(x.status === 0 ? "offline" : "error " + x.status)
            }
        }
        x.open("GET", url)
        x.send()
    }

    onOpenChanged: {
        if (!open || !consent) return
        if (!hasPlace) { if (autoLocation) locate() }
        else if (!wx || Date.now() - fetchedAt > refreshMin * 60000) refresh()
    }

    Timer {
        interval: root.refreshMin * 60000
        running: root.open && root.consent && root.hasPlace
        repeat: true
        onTriggered: root.refresh()
    }

    function refresh() {
        if (!consent || !hasPlace) return
        loading = true
        const imp = units === "imperial"
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat.toFixed(4) + "&longitude=" + lon.toFixed(4)
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m,surface_pressure"
            + "&hourly=uv_index,visibility"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset"
            + "&timezone=auto&forecast_days=5"
            + "&temperature_unit=" + (imp ? "fahrenheit" : "celsius")
            + "&wind_speed_unit=" + (imp ? "mph" : "kmh")
        get(url, j => {
            try {
                wx = W.parseForecast(j)
                fetchedAt = Date.now()
                error = ""
            } catch (e) {
                error = "unexpected data"
            }
            loading = false
        }, err => { error = err; loading = false })

        get("https://air-quality-api.open-meteo.com/v1/air-quality?latitude=" + lat.toFixed(4) + "&longitude=" + lon.toFixed(4)
            + "&current=european_aqi",
            j => { aqi = (j.current && typeof j.current.european_aqi === "number") ? j.current.european_aqi : -1 },
            () => { aqi = -1 })
    }

    function setPlace(la, lo, name, auto) {
        lat = la; lon = lo; place = name; hasPlace = true; autoLocation = auto
        grid = null
        wx = null
        save()
        placePicked()
        refresh()
    }

    // Approximate location from the IP (only if the user chose "automatic")
    function locate() {
        if (!consent) return
        loading = true
        error = ""
        get("https://ipwho.is/", j => {
            if (j.success !== false && typeof j.latitude === "number") {
                setPlace(j.latitude, j.longitude, (j.city || "") + (j.country_code ? ", " + j.country_code : ""), true)
            } else locateFallback()
        }, () => locateFallback())
    }

    function locateFallback() {
        get("https://get.geojs.io/v1/ip/geo.json", j => {
            const la = parseFloat(j.latitude), lo = parseFloat(j.longitude)
            if (isFinite(la) && isFinite(lo)) setPlace(la, lo, (j.city || "") + (j.country_code ? ", " + j.country_code : ""), true)
            else { error = "location"; loading = false }
        }, () => { error = "location"; loading = false })
    }

    function search(text) {
        const q = text.trim()
        const seq = ++searchSeq
        if (!consent || q.length < 2) { results = []; searching = false; return }
        searching = true
        get("https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(q) + "&count=6&format=json&language=" + lang,
            j => {
                if (seq !== searchSeq) return
                const out = []
                const r = j.results || []
                for (let i = 0; i < r.length; i++) {
                    const sub = [r[i].admin1, r[i].country].filter(x => !!x).join(", ")
                    out.push({ name: r[i].name, sub: sub, lat: r[i].latitude, lon: r[i].longitude,
                               label: r[i].name + (r[i].country_code ? ", " + r[i].country_code : "") })
                }
                results = out
                searching = false
            }, () => { if (seq === searchSeq) { results = []; searching = false } })
    }

    // ---------- Grid of values for the map layers ----------
    function fetchGrid(s, n, w, e) {
        if (!consent || gridBusy) return
        gridBusy = true
        const q = W.gridQuery(s, n, w, e)
        const imp = units === "imperial"
        get("https://api.open-meteo.com/v1/forecast?latitude=" + q.lat + "&longitude=" + q.lon
            + "&current=temperature_2m,cloud_cover,precipitation,pressure_msl,wind_speed_10m,wind_direction_10m"
            + "&temperature_unit=" + (imp ? "fahrenheit" : "celsius") + "&wind_speed_unit=" + (imp ? "mph" : "kmh"),
            j => {
                try { grid = W.parseGrid(j, s, n, w, e); gridAt = Date.now() } catch (err) {}
                gridBusy = false
            }, () => { gridBusy = false })
    }

    // ---------- Map tiles ----------
    readonly property string tileDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
                                      + "/quickshell-weather/tiles"
    property var tileReady: ({})
    property var tilePending: []

    function requestTiles(keys) {
        if (!consent) return
        let added = false
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i]
            if (tileReady[k] || tilePending.indexOf(k) >= 0) continue
            tilePending.push(k)
            added = true
        }
        if (added) pumpTiles()
    }

    function pumpTiles() {
        if (tileProc.running || tilePending.length === 0) return
        const take = tilePending.splice(0, 12)
        tileProc.command = ["sh", Quickshell.shellPath("scripts/maptiles.sh")].concat(take)
        tileProc.running = true
    }

    function tileDone(key) {
        const o = Object.assign({}, tileReady)
        o[key] = true
        tileReady = o
    }

    function clearCache() {
        const home = Quickshell.env("HOME")
        if (!home) return
        Quickshell.execDetached(["rm", "-rf", (Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")) + "/quickshell-weather"])
        tileReady = ({})
    }

    Process {
        id: tileProc
        stdout: SplitParser { onRead: line => root.tileDone(line) }
        onExited: root.pumpTiles()
    }
}
