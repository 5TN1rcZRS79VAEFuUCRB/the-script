import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Sound: volume, mute, and which output and input to use.
Dropdown {
    id: menu
    menuWidth: 360

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var devices: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)

    PwObjectTracker { objects: menu.devices }

    MenuItem { header: true; text: "Volume" }
    Item {
        width: parent.width; height: 36
        Glyph {
            x: 12; width: 18; anchors.verticalCenter: parent.verticalCenter
            text: menu.sink && menu.sink.audio && menu.sink.audio.muted ? "" : ""
            MouseArea { anchors.fill: parent; onClicked: if (menu.sink) menu.sink.audio.muted = !menu.sink.audio.muted }
        }
        Slider {
            x: 38; width: parent.width - 38 - 60
            anchors.verticalCenter: parent.verticalCenter
            value: menu.sink && menu.sink.audio ? menu.sink.audio.volume : 0
            onMoved: v => { if (menu.sink) { menu.sink.audio.muted = false; menu.sink.audio.volume = v; } }
        }
        Label {
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
            text: menu.sink && menu.sink.audio ? (menu.sink.audio.muted ? "Muted" : Math.round(menu.sink.audio.volume * 100) + "%") : ""
            color: Theme.dim
        }
    }
    Separator {}
    MenuItem { header: true; text: "Output" }
    Repeater {
        model: menu.devices.filter(n => n.isSink)
        MenuItem {
            required property var modelData
            text: modelData.description || modelData.nickname || modelData.name
            checked: menu.sink && modelData.id === menu.sink.id
            onClicked: Pipewire.preferredDefaultAudioSink = modelData
        }
    }
    MenuItem { header: true; text: "Input" }
    Repeater {
        model: menu.devices.filter(n => !n.isSink)
        MenuItem {
            required property var modelData
            text: modelData.description || modelData.nickname || modelData.name
            checked: menu.source && modelData.id === menu.source.id
            detail: modelData.audio && modelData.audio.muted ? "muted" : ""
            onClicked: Pipewire.preferredDefaultAudioSource = modelData
        }
    }
    MenuItem {
        visible: menu.source !== null
        text: menu.source && menu.source.audio && menu.source.audio.muted ? "Unmute microphone" : "Mute microphone"
        glyph: ""
        onClicked: if (menu.source) menu.source.audio.muted = !menu.source.audio.muted
    }
    Separator {}
    MenuItem { text: "Sound settings"; glyph: ""; onClicked: { Quickshell.execDetached(["pavucontrol"]); menu.close(); } }
}
