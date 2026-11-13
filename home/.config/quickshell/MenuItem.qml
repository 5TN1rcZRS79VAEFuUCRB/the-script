import QtQuick

// A row in a dropdown: text, an optional icon and an optional check mark.
Rectangle {
    id: item
    property string text: ""
    property string glyph: ""
    property string detail: ""
    property bool checked: false
    property bool enabled: true
    property bool header: false
    signal clicked()

    width: parent ? parent.width : 300
    implicitHeight: header ? 28 : 34
    color: !header && enabled && mouse.containsMouse ? Theme.raised : "transparent"

    Glyph {
        id: g
        visible: item.glyph !== "" || item.checked
        text: item.checked ? "" : item.glyph
        color: item.checked ? Theme.accent : Theme.text
        x: 12; width: 18
        anchors.verticalCenter: parent.verticalCenter
    }
    Label {
        anchors.left: parent.left
        anchors.leftMargin: item.header ? 12 : 38
        anchors.right: d.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: item.text
        color: item.header ? Theme.dim : (item.enabled ? Theme.text : Theme.dim)
        font.pixelSize: item.header ? Theme.fontSize - 2 : Theme.fontSize
        font.weight: item.header ? Font.DemiBold : Font.Normal
        font.capitalization: item.header ? Font.AllUppercase : Font.MixedCase
    }
    Label {
        id: d
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: item.detail
        color: Theme.dim
        font.pixelSize: Theme.fontSize - 1
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: item.enabled && !item.header
        onClicked: item.clicked()
    }
}
