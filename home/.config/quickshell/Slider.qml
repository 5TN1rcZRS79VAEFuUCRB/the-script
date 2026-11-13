import QtQuick

// A square slider, 0..1.
Item {
    id: s
    property real value: 0
    signal moved(real value)
    implicitHeight: 28
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 6
        color: Theme.raised
        Rectangle { width: parent.width * Math.max(0, Math.min(1, s.value)); height: parent.height; color: Theme.accent }
    }
    Rectangle {
        x: (s.width - width) * Math.max(0, Math.min(1, s.value))
        anchors.verticalCenter: parent.verticalCenter
        width: 12; height: 18
        color: Theme.text
    }
    MouseArea {
        anchors.fill: parent
        function set(mx) { s.moved(Math.max(0, Math.min(1, mx / s.width))); }
        onPressed: m => set(m.x)
        onPositionChanged: m => { if (pressed) set(m.x); }
        onWheel: w => s.moved(Math.max(0, Math.min(1, s.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
