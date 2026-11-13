import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// The top bar: Activities and the window's app on the left, the clock in the middle, then the
// to-do count, tray icons, sound, battery and power on the right. Everything opens a dropdown.
PanelWindow {
    id: bar
    required property var modelData
    property alias todo: todoMenu
    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "the-script-bar"
    color: Theme.bar

    readonly property bool focusedHere: Hyprland.focusedMonitor && Hyprland.monitorFor(screen) === Hyprland.focusedMonitor
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [bar.sink] }

    // ---------------------------------------------------------------- left
    Row {
        anchors.left: parent.left
        height: parent.height
        BarButton {
            active: Overview.shown
            Label { text: "Activities"; font.weight: Font.DemiBold }
            onClicked: Overview.toggle()
        }
        Label {
            leftPadding: 10
            height: parent.height
            width: Math.min(implicitWidth, bar.width / 2 - 260)
            text: Hyprland.activeToplevel && Hyprland.activeToplevel.wayland && bar.focusedHere ? Windows.appName(Hyprland.activeToplevel) : ""
            font.weight: Font.DemiBold
        }
    }

    // ---------------------------------------------------------------- clock
    SystemClock { id: clock; precision: SystemClock.Minutes }
    BarButton {
        id: clockButton
        anchors.horizontalCenter: parent.horizontalCenter
        active: calendar.visible
        Label { text: Qt.formatDateTime(clock.date, "ddd MMM d   h:mm AP"); font.weight: Font.DemiBold }
        onClicked: calendar.toggle()
    }
    CalendarMenu { id: calendar; button: clockButton; barWindow: bar }

    // ---------------------------------------------------------------- right
    Row {
        anchors.right: parent.right
        height: parent.height

        BarButton {
            id: todoButton
            active: todoMenu.visible
            Glyph { text: todoMenu.focusText !== "" ? "" : "" }
            Label { text: todoMenu.barText }
            onClicked: todoMenu.toggle()
        }

        Repeater {
            model: SystemTray.items
            BarButton {
                id: trayButton
                required property var modelData
                implicitWidth: 34
                Image {
                    width: 18; height: 18
                    sourceSize.width: 36; sourceSize.height: 36
                    source: trayButton.modelData.icon
                    smooth: true
                }
                onClicked: m => {
                    if (m.button === Qt.LeftButton && !modelData.onlyMenu) {
                        modelData.activate();
                    } else if (m.button === Qt.MiddleButton) {
                        modelData.secondaryActivate();
                    } else if (modelData.hasMenu) {
                        const p = trayButton.mapToItem(null, 0, trayButton.height);
                        modelData.display(bar, p.x, p.y);
                    }
                }
                onWheel: w => modelData.scroll(w.angleDelta.y / 120, false)
            }
        }

        BarButton {
            id: audioButton
            active: audioMenu.visible
            readonly property var a: bar.sink ? bar.sink.audio : null
            Glyph { text: !audioButton.a || audioButton.a.muted ? "" : (audioButton.a.volume < 0.4 ? "" : "") }
            Label { text: audioButton.a ? (audioButton.a.muted ? "Muted" : Math.round(audioButton.a.volume * 100) + "%") : "" }
            onClicked: audioMenu.toggle()
            onWheel: w => {
                if (!a) return;
                a.muted = false;
                a.volume = Math.max(0, Math.min(1, a.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05)));
            }
        }

        BarButton {
            id: batteryButton
            readonly property var dev: UPower.displayDevice
            visible: dev && dev.ready && dev.isLaptopBattery
            readonly property bool charging: dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged || dev.state === UPowerDeviceState.PendingCharge)
            readonly property int pct: dev ? Math.round(dev.percentage * (dev.percentage <= 1 ? 100 : 1)) : 0
            Glyph {
                text: batteryButton.charging ? "" : ["", "", "", "", ""][Math.min(4, Math.floor(batteryButton.pct / 20))]
                color: !batteryButton.charging && batteryButton.pct <= 10 ? Theme.bad : Theme.text
            }
            Label { text: batteryButton.pct + "%" }
        }

        BarButton {
            id: powerButton
            active: powerMenu.visible
            implicitWidth: 40
            Glyph { text: "" }
            onClicked: powerMenu.toggle()
        }
    }

    TodoMenu { id: todoMenu; button: todoButton; barWindow: bar }
    AudioMenu { id: audioMenu; button: audioButton; barWindow: bar }
    PowerMenu { id: powerMenu; button: powerButton; barWindow: bar }
}
