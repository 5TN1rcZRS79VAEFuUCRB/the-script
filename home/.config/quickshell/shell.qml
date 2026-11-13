//@ pragma IconTheme Adwaita
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower

// the-script's desktop shell (Quickshell on Hyprland): wallpaper, top bar, Super overview, Alt+Tab
// switcher and the volume/brightness box. Started by the-script-session; saving a file reloads it.
ShellRoot {
    Variants { model: Quickshell.screens; Wallpaper {} }
    Variants { id: bars; model: Quickshell.screens; Bar {} }
    OverviewWindow {}
    Switcher { id: switcher }
    Osd {}

    // Hyprland's keys reach the shell as global shortcuts (hl.dsp.global("quickshell:NAME")).
    GlobalShortcut { name: "overview"; description: "Overview: search and all windows"; onPressed: Overview.toggle() }
    GlobalShortcut { name: "switcher-next"; description: "Alt+Tab"; onPressed: { Overview.close(); switcher.step(1); } }
    GlobalShortcut { name: "switcher-prev"; description: "Alt+Shift+Tab"; onPressed: { Overview.close(); switcher.step(-1); } }
    GlobalShortcut { name: "switcher-commit"; description: "Alt released"; onPressed: switcher.commit() }
    GlobalShortcut {
        name: "todo"
        description: "To-do list"
        onPressed: {
            const mon = Hyprland.focusedMonitor;
            const b = bars.instances.find(b => Hyprland.monitorFor(b.screen) === mon) || bars.instances[0];
            if (b) b.todo.toggle();
        }
    }

    // Laptops: a warning at 10% and 5% while on battery (near empty, UPower itself shuts the laptop down).
    Timer {
        property int warned: 100
        interval: 30000; running: true; repeat: true
        onTriggered: {
            const d = UPower.displayDevice;
            if (!d || !d.ready || !d.isLaptopBattery) return;
            const pct = Math.round(d.percentage * (d.percentage <= 1 ? 100 : 1));
            if (!UPower.onBattery) { warned = 100; return; }
            for (const level of [5, 10]) {
                if (pct <= level && warned > level) {
                    warned = level;
                    Quickshell.execDetached(["notify-send", "-u", "critical", "-i", "battery-caution", "Battery low", `${pct}% left. Plug in the charger.`]);
                    break;
                }
            }
        }
    }

    IpcHandler {
        target: "overview"
        function toggle(): void { Overview.toggle(); }
    }
}
