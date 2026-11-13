pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The overview's look: Noctalia's current palette (written by Noctalia's template in
// ~/.config/noctalia/the-script.toml to ~/.cache/the-script/noctalia-colors.json), so it follows
// whatever theme Noctalia uses. Until that file exists, Noctalia-like dark defaults.
Singleton {
    id: t
    property var c: ({})

    readonly property color base: c.surface || "#1c1b1f"
    readonly property color raised: c.surface_variant || "#2b2930"
    readonly property color pressed: Qt.lighter(raised, 1.25)
    readonly property color border: c.outline || "#4a4458"
    readonly property color text: c.on_surface || "#e6e1e5"
    readonly property color dim: c.on_surface_variant || "#a7a2ad"
    readonly property color accent: c.primary || "#c7b8f5"
    readonly property color bad: c.error || "#f2b8b5"

    readonly property int radius: 12
    readonly property string font: "sans-serif"
    readonly property string icons: "Symbols Nerd Font"
    readonly property int fontSize: 14

    readonly property string wallpaper: Quickshell.env("HOME") + "/.local/share/wallpapers/the-script.jpg"

    FileView {
        path: Quickshell.env("HOME") + "/.cache/the-script/noctalia-colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { t.c = JSON.parse(text()); } catch (e) {} }
    }
}
