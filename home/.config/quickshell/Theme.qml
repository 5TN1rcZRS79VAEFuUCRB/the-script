pragma Singleton
import QtQuick
import Quickshell

// the-script's look: GNOME's dark colors, square corners, thin borders.
Singleton {
    readonly property color bar: "#000000"
    readonly property color base: "#1b1b1b"       // dropdowns, overview boxes
    readonly property color raised: "#2a2a2a"     // hovered rows and buttons
    readonly property color pressed: "#383838"
    readonly property color border: "#3d3d3d"
    readonly property color text: "#ffffff"
    readonly property color dim: "#9a9a9a"
    readonly property color accent: "#3584e4"     // GNOME blue: selection, sliders
    readonly property color warn: "#e5a50a"
    readonly property color bad: "#e01b24"

    readonly property string font: "Adwaita Sans"
    readonly property string icons: "Symbols Nerd Font"
    readonly property int fontSize: 14
    readonly property int barHeight: 32

    readonly property string wallpaper: Quickshell.env("HOME") + "/.local/share/wallpapers/the-script.jpg"
}
