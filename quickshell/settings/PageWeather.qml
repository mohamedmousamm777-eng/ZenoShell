import QtQuick
import qs.theme
import qs.services
import qs.widgets
import qs.weather

SPage {
    title: "Weather & map"
    subtitle: "Forecast, air quality and a real map with colored layers. Nothing goes on the internet until you allow it."

    SSection {
        title: "Permission"

        SRow {
            title: "Use the internet for weather and map"
            hint: Weather.consent
                  ? "Allowed. Data comes from Open-Meteo (weather), CARTO / OpenStreetMap (map tiles) and, only if you chose automatic location, an IP location service."
                  : "Off. The weather panel stays empty and nothing is downloaded. Turn it on to see the forecast and the map."
            last: true
            Toggle {
                checked: Weather.consent
                onToggled: Weather.setConsent(!Weather.consent)
            }
        }
    }

    SSection {
        title: "Location"
        visible: Weather.consent
        height: visible ? implicitHeight : 0

        SRow {
            title: "Where"
            hint: Weather.hasPlace ? "Now: " + Weather.place : "Not chosen yet"
            SChoice {
                model: [{ id: "auto", label: "Automatic (IP)" }, { id: "city", label: "A city" }]
                current: Weather.autoLocation ? "auto" : "city"
                onPicked: id => {
                    if (id === "auto") { Weather.set("autoLocation", true); Weather.locate() }
                    else Weather.set("autoLocation", false)
                }
            }
        }

        SRow {
            visible: !Weather.autoLocation
            height: visible ? implicitHeight + 6 : 0
            title: "Search a city"
            last: true
            CitySearch {
                width: 280
                base: Theme.surfaceSoft
            }
        }

        SRow {
            visible: Weather.autoLocation
            height: visible ? implicitHeight : 0
            title: "Find my location again"
            hint: "Uses the IP address of this connection, so it is approximate."
            last: true
            SButton { label: "Update"; onClicked: Weather.locate() }
        }
    }

    SSection {
        title: "Units & language"
        visible: Weather.consent
        height: visible ? implicitHeight : 0

        SRow {
            title: "Units"
            SChoice {
                model: [{ id: "metric", label: "°C · km/h" }, { id: "imperial", label: "°F · mph" }]
                current: Weather.units
                onPicked: id => Weather.set("units", id)
            }
        }

        SRow {
            title: "Language of the panel"
            last: true
            SChoice {
                model: [{ id: "en", label: "English" }, { id: "it", label: "Italiano" }]
                current: Weather.lang
                onPicked: id => Weather.set("lang", id)
            }
        }
    }

    SSection {
        title: "Map & updates"
        visible: Weather.consent
        height: visible ? implicitHeight : 0

        SRow {
            title: "Map style"
            hint: "Automatic follows the theme: light map on light themes, dark map on dark themes."
            SChoice {
                model: [{ id: "auto", label: "Automatic" }, { id: "light", label: "Light" }, { id: "dark", label: "Dark" }]
                current: Weather.mapStyle
                onPicked: id => Weather.set("mapStyle", id)
            }
        }

        SRow {
            title: "Update every"
            hint: "Only while the panel is open."
            SChoice {
                model: [{ id: "15", label: "15 min" }, { id: "30", label: "30 min" }, { id: "60", label: "1 h" }]
                current: String(Weather.refreshMin)
                onPicked: id => Weather.set("refreshMin", parseInt(id))
            }
        }

        SRow {
            title: "Downloaded map tiles"
            hint: "Saved in ~/.cache/quickshell-weather so the map opens fast and works offline where you already looked."
            last: true
            SButton { label: "Clear cache"; onClicked: Weather.clearCache() }
        }
    }

    SSection {
        title: "Panel"

        SRow {
            title: "Open the weather panel"
            hint: "Shortcut: Alt+Shift+M. Esc or a click outside closes it."
            last: true
            SButton { label: "Open"; accent: true; onClicked: Weather.openPanel() }
        }
    }
}
