import QtQuick

// A flat, square bar button: highlights on hover, stays lit while its dropdown is open.
Rectangle {
    id: btn
    property bool active: false
    property alias hovered: mouse.containsMouse
    default property alias content: row.data
    signal clicked(var mouse)
    signal wheel(var wheel)

    implicitWidth: row.implicitWidth + 20
    implicitHeight: Theme.barHeight
    color: active ? Theme.pressed : (mouse.containsMouse ? Theme.raised : "transparent")

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => btn.clicked(m)
        onWheel: w => btn.wheel(w)
    }
}
