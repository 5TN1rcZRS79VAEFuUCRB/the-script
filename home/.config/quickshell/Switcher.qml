import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Alt+Tab: the open windows, most recently used first. Hyprland's config sends next/prev on each
// Tab and commit when Alt is let go (it watches the key, so this needs no keyboard focus).
PanelWindow {
    id: sw
    property bool shown: false
    property int index: 0
    property var items: []

    screen: Overview.screen
    visible: shown
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "the-script-switcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    mask: Region { item: panel }

    function step(d) {
        if (!shown) {
            items = Windows.list.slice();
            if (items.length === 0) return;
            const mon = Hyprland.focusedMonitor;
            Overview.screen = Quickshell.screens.find(s => Hyprland.monitorFor(s) === mon) || Quickshell.screens[0];
            index = items.length > 1 ? (d > 0 ? 1 : items.length - 1) : 0;
            shown = true;
        } else {
            index = (index + d + items.length) % items.length;
        }
    }
    function commit() {
        if (!shown) return;
        shown = false;
        Windows.focus(items[index]);
    }

    readonly property int tileW: Math.min(240, (width - 80) / Math.max(1, items.length) - 12)

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: row.width + 24
        height: row.height + 24
        color: Theme.base
        border.color: Theme.border
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 12
            Repeater {
                model: sw.items
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool sel: sw.index === index
                    width: sw.tileW
                    height: sw.tileW * 0.62 + 34
                    color: sel ? Theme.raised : "transparent"
                    border.color: sel ? Theme.accent : "transparent"
                    border.width: 2
                    ScreencopyView {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 6
                        captureSource: sw.shown ? modelData.wayland : null
                        live: false
                        constraintSize: Qt.size(parent.width - 12, sw.tileW * 0.62 - 6)
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        spacing: 6
                        Image {
                            width: 18; height: 18
                            sourceSize.width: 36; sourceSize.height: 36
                            source: Windows.iconFor(modelData.wayland ? modelData.wayland.appId : "")
                        }
                        Label {
                            width: Math.min(implicitWidth, sw.tileW - 36)
                            height: 18
                            text: Windows.appName(modelData)
                            font.pixelSize: Theme.fontSize - 1
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { sw.index = index; sw.commit(); }
                    }
                }
            }
        }
    }
}
