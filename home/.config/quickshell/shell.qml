//@ pragma IconTheme Adwaita
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// the-script's Super overview (Quickshell on Hyprland): a search box over every open window, side by
// side with live previews. Everything else (bar, Alt+Tab, notifications) is Noctalia. Started by
// the-script-session; saving a file reloads it.
ShellRoot {
    OverviewWindow {}

    // Super (hyprland.lua) reaches the shell as hl.dsp.global("quickshell:overview").
    GlobalShortcut { name: "overview"; description: "Overview: search and all windows"; onPressed: Overview.toggle() }

    // Noctalia's launcher button: qs ipc call overview toggle
    IpcHandler {
        target: "overview"
        function toggle(): void { Overview.toggle(); }
    }
}
