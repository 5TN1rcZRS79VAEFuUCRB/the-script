import QtQuick
import Quickshell

// A month calendar under the clock.
Dropdown {
    id: menu
    menuWidth: 300
    property date shown: new Date()
    onOpening: shown = new Date()

    function shift(n) { const d = new Date(shown); d.setDate(1); d.setMonth(d.getMonth() + n); shown = d; }

    Item {
        width: parent.width; height: 36
        BarButton { x: 6; implicitHeight: 32; anchors.verticalCenter: parent.verticalCenter; Glyph { text: "" } onClicked: menu.shift(-1) }
        Label { anchors.centerIn: parent; text: Qt.formatDate(menu.shown, "MMMM yyyy"); font.weight: Font.DemiBold }
        BarButton { anchors.right: parent.right; anchors.rightMargin: 6; implicitHeight: 32; anchors.verticalCenter: parent.verticalCenter; Glyph { text: "" } onClicked: menu.shift(1) }
    }
    Grid {
        id: grid
        columns: 7
        x: 10
        width: parent.width - 20
        readonly property real cell: width / 7
        readonly property date first: new Date(menu.shown.getFullYear(), menu.shown.getMonth(), 1)
        Repeater {
            model: ["S", "M", "T", "W", "T", "F", "S"]
            Label { required property string modelData; width: grid.cell; height: 26; text: modelData; color: Theme.dim; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Theme.fontSize - 2 }
        }
        Repeater {
            model: 42
            Rectangle {
                required property int index
                readonly property date day: new Date(grid.first.getFullYear(), grid.first.getMonth(), index - grid.first.getDay() + 1)
                readonly property bool isToday: day.toDateString() === new Date().toDateString()
                width: grid.cell; height: 32
                color: isToday ? Theme.accent : "transparent"
                Label {
                    anchors.centerIn: parent
                    text: parent.day.getDate()
                    color: parent.day.getMonth() === menu.shown.getMonth() ? Theme.text : "#555555"
                }
            }
        }
    }
    Item { width: 1; height: 6 }
}
