import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

// Super: a search box over every open window, like GNOME's Activities overview (without the dock,
// workspaces and app grid). Type to find apps and windows; Enter opens the highlighted one, the arrow
// keys and Tab move the highlight, Esc or Super closes. Click a window to go to it, its x to close it.
PanelWindow {
    id: win
    screen: Overview.screen
    visible: Overview.shown
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "the-script-overview"
    WlrLayershell.keyboardFocus: Overview.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    property string query: ""
    property int selected: -1
    property string wallpaper: Theme.wallpaper

    // The wallpaper Noctalia shows right now, behind the dimmed overview.
    Process {
        id: wallGet
        command: ["noctalia", "msg", "wallpaper-get"]
        stdout: StdioCollector {
            onStreamFinished: { const p = this.text.trim(); if (p.startsWith("/")) win.wallpaper = p; }
        }
    }

    readonly property var apps: {
        const q = query.trim().toLowerCase();
        if (q === "") return [];
        const scored = [];
        for (const e of DesktopEntries.applications.values) {
            const name = (e.name || "").toLowerCase();
            const words = name.split(/[\s\-_.]+/);
            const extra = [e.genericName || "", e.comment || "", String(e.keywords || ""), e.id || ""].join(" ").toLowerCase();
            let s = 0;
            if (name === q) s = 100;
            else if (name.startsWith(q)) s = 80;
            else if (words.some(w => w.startsWith(q))) s = 60;
            else if (name.includes(q)) s = 40;
            else if (extra.includes(q)) s = 20;
            if (s > 0) scored.push({ e: e, s: s });
        }
        scored.sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name));
        return scored.slice(0, 8).map(x => x.e);
    }
    readonly property var windows: {
        const q = query.trim().toLowerCase();
        return Windows.list.filter(t => q === "" || (t.title || "").toLowerCase().includes(q)
            || (t.wayland && t.wayland.appId.toLowerCase().includes(q)) || Windows.appName(t).toLowerCase().includes(q));
    }
    readonly property int count: apps.length + windows.length

    onQueryChanged: selected = count > 0 ? 0 : -1
    Connections {
        target: Overview
        function onShownChanged() {
            if (Overview.shown) {
                win.query = "";
                search.text = "";
                win.selected = -1;
                search.forceActiveFocus();
                wallGet.running = true;
            }
        }
    }

    function activate(i) {
        if (i < 0 || i >= count) return;
        Overview.close();
        if (i < apps.length) {
            const e = apps[i];
            if (e.runInTerminal) Quickshell.execDetached(["foot", "-e"].concat(e.command));
            else e.execute();
        } else {
            Windows.focus(windows[i - apps.length]);
        }
    }

    // Dimmed wallpaper behind everything; clicking it closes the overview.
    Image {
        anchors.fill: parent
        source: "file://" + win.wallpaper
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: width
        sourceSize.height: height
        asynchronous: true
    }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.72 }
    MouseArea { anchors.fill: parent; onClicked: Overview.close() }

    // ---------------------------------------------------------------- search box
    Rectangle {
        radius: Theme.radius
        id: box
        width: Math.min(560, parent.width - 40)
        height: 44
        anchors.horizontalCenter: parent.horizontalCenter
        y: 28
        color: Theme.base
        border.color: search.activeFocus ? Theme.accent : Theme.border
        border.width: 1
        Glyph { x: 14; anchors.verticalCenter: parent.verticalCenter; text: ""; color: Theme.dim }
        TextInput {
            id: search
            anchors.fill: parent
            anchors.leftMargin: 42
            anchors.rightMargin: 14
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text
            selectionColor: Theme.accent
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 2
            clip: true
            onTextChanged: win.query = text
            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === ""
                text: "Type to search"
                color: Theme.dim
                font.pixelSize: Theme.fontSize + 2
            }
            Keys.onPressed: ev => {
                const n = win.count;
                if (ev.key === Qt.Key_Escape) { Overview.close(); }
                else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                    if (win.selected >= 0) win.activate(win.selected);
                    else if (win.query !== "" && n > 0) win.activate(0);
                    else Overview.close();
                }
                else if (n > 0 && (ev.key === Qt.Key_Right || ev.key === Qt.Key_Down || (ev.key === Qt.Key_Tab && !(ev.modifiers & Qt.ShiftModifier))))
                    win.selected = (win.selected + 1) % n;
                else if (n > 0 && (ev.key === Qt.Key_Left || ev.key === Qt.Key_Up || ev.key === Qt.Key_Backtab || ev.key === Qt.Key_Tab))
                    win.selected = (win.selected - 1 + n) % n;
                else return;
                ev.accepted = true;
            }
        }
    }

    // ---------------------------------------------------------------- apps (while searching)
    Row {
        id: appRow
        visible: win.apps.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: box.y + box.height + 24
        height: visible ? 112 : 0
        spacing: 8
        Repeater {
            model: win.apps
            Rectangle {
                radius: Theme.radius
                required property var modelData
                required property int index
                readonly property bool sel: win.selected === index
                width: 112; height: 112
                color: sel ? Theme.raised : (ma.containsMouse ? "#20ffffff" : "transparent")
                border.color: sel ? Theme.accent : "transparent"
                border.width: 2
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 14
                    width: 56; height: 56
                    sourceSize.width: 112; sourceSize.height: 112
                    source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                }
                Label {
                    x: 6; width: parent.width - 12; y: 78; height: 26
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData.name
                    font.pixelSize: Theme.fontSize - 1
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: win.activate(index) }
            }
        }
    }

    // ---------------------------------------------------------------- windows
    Item {
        id: area
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: appRow.visible ? appRow.bottom : box.bottom
        anchors.margins: 32
        anchors.topMargin: appRow.visible ? 20 : 32

        readonly property int n: win.windows.length
        readonly property real ratio: win.width / Math.max(1, win.height)
        readonly property int labelH: 30
        readonly property var fit: {
            let best = { cols: 1, w: 0 };
            for (let c = 1; c <= Math.max(1, n); c++) {
                const rows = Math.ceil(n / c);
                const w = Math.min((width - (c - 1) * 24) / c, ((height - (rows - 1) * 24) / rows - labelH) * ratio);
                if (w > best.w) best = { cols: c, w: w };
            }
            best.w = Math.min(best.w, width * 0.42);
            return best;
        }

        Label {
            anchors.centerIn: parent
            visible: area.n === 0
            text: win.query === "" ? "No open windows" : (win.apps.length ? "" : "No results")
            color: Theme.dim
            font.pixelSize: Theme.fontSize + 2
        }

        // Rows of windows, the last one centered like the others.
        Column {
            anchors.centerIn: parent
            spacing: 24
            Repeater {
                model: Math.ceil(area.n / area.fit.cols)
                Row {
                    id: rowItem
                    required property int index
                    readonly property int first: index * area.fit.cols
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 24
            Repeater {
                model: win.windows.slice(rowItem.first, rowItem.first + area.fit.cols)
                Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property int flat: win.apps.length + rowItem.first + index
                    readonly property bool sel: win.selected === flat
                    width: area.fit.w
                    height: area.fit.w / area.ratio + area.labelH

                    Rectangle {
                        radius: Theme.radius
                        id: frame
                        width: parent.width
                        height: parent.width / area.ratio
                        color: "#101010"
                        border.color: tile.sel ? Theme.accent : (tma.containsMouse ? "#9a9a9a" : Theme.border)
                        border.width: tile.sel || tma.containsMouse ? 3 : 1
                        ScreencopyView {
                            anchors.centerIn: parent
                            captureSource: Overview.shown ? tile.modelData.wayland : null
                            live: Overview.shown
                            constraintSize: Qt.size(frame.width - 8, frame.height - 8)
                        }
                        Rectangle {
                            id: closeBtn
                            visible: tma.containsMouse
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 6
                            width: 26; height: 26
                            radius: 13
                            color: cma.containsMouse ? Theme.bad : Theme.raised
                            border.color: Theme.border
                            Glyph { anchors.centerIn: parent; text: ""; font.pixelSize: Theme.fontSize - 1 }
                        }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: frame.height + 6
                        spacing: 6
                        Image {
                            width: 18; height: 18
                            sourceSize.width: 36; sourceSize.height: 36
                            source: Windows.iconFor(tile.modelData.wayland ? tile.modelData.wayland.appId : "")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Label {
                            width: Math.min(implicitWidth, tile.width - 30)
                            text: tile.modelData.title || Windows.appName(tile.modelData)
                            font.pixelSize: Theme.fontSize - 1
                        }
                    }
                    MouseArea {
                        id: tma
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: m => {
                            if (m.button === Qt.MiddleButton) tile.modelData.wayland.close();
                            else win.activate(tile.flat);
                        }
                    }
                    MouseArea {
                        id: cma
                        x: closeBtn.x; y: closeBtn.y; width: closeBtn.width; height: closeBtn.height
                        visible: closeBtn.visible
                        hoverEnabled: true
                        onClicked: tile.modelData.wayland.close()
                    }
                }
            }
                }
            }
        }
    }
}
