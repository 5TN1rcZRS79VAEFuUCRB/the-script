pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Open windows, most recently used first (for the overview and Alt+Tab).
Singleton {
    id: root

    property var mru: []   // window addresses, most recent first

    readonly property var list: {
        const all = Hyprland.toplevels.values.filter(t => t.address && t.wayland);
        const rank = a => { const i = root.mru.indexOf(a); return i < 0 ? 100000 : i; };
        return all.slice().sort((a, b) => rank(a.address) - rank(b.address));
    }

    function touch(address) {
        if (address)
            root.mru = [address].concat(root.mru.filter(a => a !== address));
    }

    function focus(t) {
        if (!t) return;
        const addr = t.address.startsWith("0x") ? t.address : "0x" + t.address;
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr}" })`);
    }

    function appName(t) {
        const id = t && t.wayland ? t.wayland.appId : "";
        const e = id ? DesktopEntries.heuristicLookup(id) : null;
        return e ? e.name : (id || "Window");
    }

    function iconFor(appId) {
        const e = appId ? DesktopEntries.heuristicLookup(appId) : null;
        const p = Quickshell.iconPath(e && e.icon ? e.icon : appId, true);
        return p || Quickshell.iconPath("application-x-executable", true);
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            if (Hyprland.activeToplevel) root.touch(Hyprland.activeToplevel.address);
        }
    }

    // Start from Hyprland's own focus history, so windows opened before the shell are in order.
    Timer {
        running: true
        interval: 300
        onTriggered: {
            Hyprland.refreshToplevels();
            seed.start();
        }
    }
    Timer {
        id: seed
        interval: 300
        onTriggered: {
            const ts = Hyprland.toplevels.values.filter(t => t.address && t.lastIpcObject);
            ts.sort((a, b) => (a.lastIpcObject.focusHistoryID ?? 999) - (b.lastIpcObject.focusHistoryID ?? 999));
            const seen = ts.map(t => t.address);
            root.mru = root.mru.concat(seen.filter(a => !root.mru.includes(a)));
        }
    }
}
