import QtQuick
import Quickshell
import Quickshell.Hyprland

// A dropdown hanging under a bar button. Clicking anywhere else closes it.
PopupWindow {
    id: pop
    required property Item button
    required property var barWindow
    property int menuWidth: 320
    default property alias content: col.data
    signal opening()

    function toggle() { if (visible) close(); else open(); }
    function open() { opening(); visible = true; }
    function close() { visible = false; }

    anchor.item: button
    anchor.rect.x: 0
    anchor.rect.y: button.height
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.Slide
    implicitWidth: menuWidth
    implicitHeight: col.implicitHeight + 12
    color: "transparent"

    HyprlandFocusGrab {
        windows: [pop, pop.barWindow]
        active: pop.visible
        onCleared: pop.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.base
        border.color: Theme.border
        border.width: 1
        Column {
            id: col
            x: 1; y: 6
            width: parent.width - 2
        }
    }
}
