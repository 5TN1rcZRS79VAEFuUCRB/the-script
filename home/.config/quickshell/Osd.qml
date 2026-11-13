import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire

// A small box at the bottom of the screen when the volume or brightness changes.
PanelWindow {
    id: osd
    property string glyph: ""
    property real value: 0
    property bool shown: false

    screen: Overview.screen
    visible: shown
    anchors.bottom: true
    margins.bottom: 80
    implicitWidth: 320
    implicitHeight: 52
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "the-script-osd"
    color: "transparent"

    function show(g, v) { glyph = g; value = v; shown = true; hide.restart(); }
    Timer { id: hide; interval: 1400; onTriggered: osd.shown = false }

    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [osd.sink] }
    property bool ready: false
    Timer { running: true; interval: 2000; onTriggered: osd.ready = true }
    Connections {
        target: osd.sink ? osd.sink.audio : null
        function onVolumeChanged() { if (osd.ready) osd.show("", osd.sink.audio.volume); }
        function onMutedChanged() { if (osd.ready) osd.show(osd.sink.audio.muted ? "" : "", osd.sink.audio.muted ? 0 : osd.sink.audio.volume); }
    }

    Process {
        id: bright
        command: ["brightnessctl", "-m", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = this.text.trim().split(",");
                if (f.length >= 4) osd.show("", parseInt(f[3]) / 100);
            }
        }
    }
    IpcHandler {
        target: "osd"
        function brightness(): void { bright.running = true; }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.base
        border.color: Theme.border
        Glyph { x: 16; width: 22; anchors.verticalCenter: parent.verticalCenter; text: osd.glyph; font.pixelSize: Theme.fontSize + 4 }
        Rectangle {
            x: 52; width: parent.width - 52 - 60; height: 6
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.raised
            Rectangle { width: parent.width * Math.max(0, Math.min(1, osd.value)); height: parent.height; color: Theme.accent }
        }
        Label { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: Math.round(osd.value * 100) + "%" }
    }
}
