// The todo daemon on the taskbar: the bar text from `todo-bar` (next due date, points, streak, or the
// focus countdown). Click it or press Meta+T for a flyout with the menu (`todo json`), whose links run
// `todo do <action> <id>`.
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    property string status: ""   // the bar text, or the focus/break countdown
    property var menu: null       // todo json
    property string error: ""
    property string openId: ""    // the task whose actions are showing
    property bool open: false     // the flyout
    property double closedAt: 0
    // A running focus timer or break: the bar's Nerd Font icon, then the countdown.
    readonly property bool timing: status.startsWith("\u{F051B}") || status.startsWith("\u{F0176}")

    readonly property string statusCmd: "\"$HOME/.local/bin/todo-bar\""
    readonly property string jsonCmd: "\"$HOME/.local/bin/todo\" json"

    readonly property var sourceIcon: ({
        canvas: "x-office-document", schoology: "x-office-document", todo: "task-due",
        anki: "anki", workout: "preferences-desktop-personal"
    })
    readonly property var actIcon: ({
        focus: "appointment-soon", more: "appointment-soon", rest: "media-playback-pause",
        pause: "media-playback-stop", stop: "process-stop", finish: "dialog-ok-apply",
        workout: "dialog-ok-apply", done: "dialog-ok-apply", done_on_time: "dialog-ok-apply",
        done_late: "dialog-ok-apply", open: "internet-web-browser", hide: "view-hidden", sync: "view-refresh"
    })

    Plasmoid.icon: "task-due"
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: ""

    // Clicking the bar while the flyout is open closes it on focus loss first; don't reopen it.
    function toggle() {
        if (!open && Date.now() - closedAt < 300) {
            return
        }
        open = !open
    }

    Connections {
        target: Plasmoid
        function onActivated() {
            root.toggle()
        }
    }

    function shellQuote(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

    // Detached: a focus session runs for 10 minutes. The list refreshes once it has had a moment.
    function run(act, id) {
        runner.connectSource("setsid -f \"$HOME/.local/bin/todo\" do " + act + (id ? " " + shellQuote(id) : ""))
        if (act === "focus" || act === "more" || act === "open") {
            root.open = false
        }
        refreshSoon.restart()
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => {
            if (source === root.statusCmd) {
                root.status = data["stdout"].trim()
            } else if (source === root.jsonCmd) {
                try {
                    root.menu = JSON.parse(data["stdout"])
                    root.error = ""
                } catch (e) {
                    root.error = data["stderr"].trim() || "todo json failed"
                }
            }
            disconnectSource(source)
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: runner.connectSource(root.statusCmd)
    }

    // Only while open: `todo json` also closes the sticky reminders, which counts as seeing them.
    Timer {
        interval: 3000
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: runner.connectSource(root.jsonCmd)
    }

    Timer {
        id: refreshSoon
        interval: 1000
        onTriggered: runner.connectSource(root.jsonCmd)
    }

    // Win7 flyouts act through blue links (like their footers), not push buttons.
    component Link: MouseArea {
        id: link
        property alias text: linkText.text
        property string iconName: ""
        implicitWidth: linkRow.implicitWidth
        implicitHeight: linkRow.implicitHeight
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        RowLayout {
            id: linkRow
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                visible: link.iconName !== ""
                source: link.iconName
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            Text {
                id: linkText
                color: "#0066cc"
                font.underline: link.containsMouse
            }
        }
    }

    // ATP's tray draws its flyouts in its own solid dialog, not Plasma's translucent popup: so does this,
    // with the same background, position and footer.
    fullRepresentation: MouseArea {
        id: bar
        Layout.minimumWidth: label.implicitWidth + Kirigami.Units.largeSpacing
        Layout.preferredWidth: Layout.minimumWidth
        onClicked: root.toggle()

        PC3.Label {
            id: label
            anchors.centerIn: parent
            text: root.status
        }

        Connections {
            target: root
            function onOpenChanged() {
                dialog.visible = root.open
            }
        }

        PlasmaCore.Dialog {
            id: dialog
            flags: Qt.WindowStaysOnTopHint
            location: PlasmaCore.Types.Floating
            hideOnWindowDeactivate: true
            backgroundHints: PlasmaCore.Dialog.SolidBackground
            readonly property int margin: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing / 2

            function place() {
                const p = bar.mapToGlobal(0, 0)
                const right = bar.Screen.virtualX + bar.Screen.width
                x = Math.max(margin, Math.min(p.x + bar.width / 2 - width / 2, right - width - margin))
                y = p.y - height - margin
            }
            onWidthChanged: place()
            onHeightChanged: place()
            onVisibleChanged: {
                if (visible) {
                    place()
                } else {
                    root.open = false
                    root.closedAt = Date.now()
                }
            }

            mainItem: Item {
                Kirigami.Theme.colorSet: Kirigami.Theme.View
                Kirigami.Theme.inherit: false
                implicitWidth: Kirigami.Units.gridUnit * 24
                implicitHeight: Kirigami.Units.gridUnit * 24
                width: implicitWidth
                height: implicitHeight

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing * 2
                    anchors.bottomMargin: footer.height + Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    // Win7's "main instruction" style: larger, dark blue, not bold.
                    Text {
                        Layout.fillWidth: true
                        color: "#003399"
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                        text: root.menu
                            ? `${root.menu.pts} points · Level ${root.menu.level} (${root.menu.to_next} to go) · `
                              + `${root.menu.streak}-day streak` + (root.menu.freezes ? ` · ${root.menu.freezes} freeze` : "")
                            : root.error || "Loading..."
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        visible: root.timing
                        Kirigami.Icon {
                            source: root.status.startsWith("\u{F051B}") ? "appointment-soon" : "media-playback-pause"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        }
                        PC3.Label {
                            Layout.fillWidth: true
                            text: root.status.replace(/^\S+ /, "")
                            elide: Text.ElideRight
                        }
                    }

                    // Timer and session rows: focus, finished, stop, 10 more minutes, break.
                    Flow {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.largeSpacing
                        Repeater {
                            model: root.menu ? root.menu.top : []
                            Link {
                                required property var modelData
                                iconName: root.actIcon[modelData.act] || ""
                                text: modelData.text
                                onClicked: root.run(modelData.act, modelData.id)
                            }
                        }
                    }

                    PC3.ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: list
                            model: root.menu ? root.menu.tasks : []
                            clip: true
                            spacing: 1

                            PlasmaExtras.PlaceholderMessage {
                                anchors.centerIn: parent
                                width: parent.width - Kirigami.Units.gridUnit * 2
                                visible: root.menu && list.count === 0
                                iconName: "dialog-ok-apply"
                                text: "All caught up"
                            }

                            // Click a task for its actions.
                            delegate: ColumnLayout {
                                id: row
                                required property var modelData
                                readonly property bool open: root.openId === modelData.id
                                width: ListView.view.width
                                spacing: 0

                                PC3.ItemDelegate {
                                    Layout.fillWidth: true
                                    highlighted: row.open
                                    onClicked: root.openId = row.open ? "" : row.modelData.id
                                    contentItem: RowLayout {
                                        spacing: Kirigami.Units.smallSpacing
                                        Kirigami.Icon {
                                            source: root.sourceIcon[row.modelData.source]
                                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                        }
                                        PC3.Label {
                                            Layout.fillWidth: true
                                            text: (row.modelData.course ? row.modelData.course + " · " : "") + row.modelData.title
                                            elide: Text.ElideRight
                                        }
                                        PC3.Label {
                                            text: row.modelData.left
                                            color: row.modelData.late ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                                        }
                                    }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: Kirigami.Units.gridUnit * 1.5
                                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                                    visible: row.open
                                    Layout.topMargin: Kirigami.Units.smallSpacing
                                    spacing: Kirigami.Units.largeSpacing
                                    Repeater {
                                        model: row.open ? row.modelData.actions : []
                                        Link {
                                            required property var modelData
                                            iconName: modelData.act === "open" && row.modelData.source === "anki"
                                                ? "anki" : (root.actIcon[modelData.act] || "")
                                            text: modelData.text
                                            onClicked: root.run(modelData.act, modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // The tray flyouts' footer, with Sync now as its link.
                Rectangle {
                    id: footer
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                    }
                    height: 40
                    color: "#f1f5fb"
                    Rectangle {
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                        }
                        height: Kirigami.Units.smallSpacing
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#ccd9ea" }
                            GradientStop { position: 1.0; color: "#f1f5fb" }
                        }
                    }
                    Link {
                        anchors.centerIn: parent
                        text: "Sync now"
                        onClicked: root.run("sync", "")
                    }
                }
            }
        }
    }
}
