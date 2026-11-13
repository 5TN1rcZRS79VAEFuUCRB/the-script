pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Overview state, shared by the bar's Activities button, the Super key and OverviewWindow.
Singleton {
    id: root
    property bool shown: false
    property var screen: Quickshell.screens[0]

    function open() {
        const mon = Hyprland.focusedMonitor;
        root.screen = Quickshell.screens.find(s => Hyprland.monitorFor(s) === mon) || Quickshell.screens[0];
        root.shown = true;
    }
    function close() { root.shown = false; }
    function toggle() { if (root.shown) close(); else open(); }
}
