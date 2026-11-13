import QtQuick
import Quickshell
import Quickshell.Wayland

// The wallpaper, under all windows.
PanelWindow {
    required property var modelData
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "the-script-wallpaper"
    color: "black"

    Image {
        anchors.fill: parent
        source: "file://" + Theme.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: parent.width
        sourceSize.height: parent.height
    }
}
