// The todo daemon on the taskbar: the bar text from `todo-bar` (next due date, points, streak, or the
// focus countdown). Click it or press Meta+T for a popup with the menu (`todo json`), whose buttons
// run `todo do <action> <id>`. The popup is laid out like Plasma's own (Bluetooth, Networks).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
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
    property string menuText: ""  // its text, so an unchanged menu isn't rebuilt (and doesn't collapse)
    property string error: ""
    property string openId: ""    // the task whose actions are showing
    // A running focus timer or break: the bar's Nerd Font icon, then the countdown.
    readonly property bool timing: status.startsWith("\u{F051B}") || status.startsWith("\u{F0176}")

    readonly property string statusCmd: "\"$HOME/.local/bin/todo-bar\""
    readonly property string jsonCmd: "\"$HOME/.local/bin/todo\" json"

    readonly property var sourceIcon: ({
        canvas: "applications-education", schoology: "applications-education", todo: "view-calendar-tasks",
        anki: "anki", workout: "games-achievements"
    })
    readonly property var actIcon: ({
        focus: "chronometer-start", more: "chronometer-start", rest: "chronometer-pause",
        pause: "media-playback-stop", stop: "process-stop", finish: "dialog-ok-apply",
        workout: "dialog-ok-apply", done: "dialog-ok-apply", done_on_time: "dialog-ok-apply",
        done_late: "dialog-ok-apply", open: "internet-web-browser", hide: "view-hidden", sync: "view-refresh"
    })

    Plasmoid.icon: "task-due"
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    toolTipMainText: ""

    function shellQuote(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

    // Detached: a focus session runs for 10 minutes. The list refreshes once it has had a moment.
    function run(act, id) {
        runner.connectSource("setsid -f \"$HOME/.local/bin/todo\" do " + act + (id ? " " + shellQuote(id) : ""))
        if (act === "focus" || act === "more" || act === "open") {
            root.expanded = false
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
                    if (data["stdout"] !== root.menuText) {
                        root.menu = JSON.parse(data["stdout"])
                        root.menuText = data["stdout"]
                    }
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
        running: root.expanded
        repeat: true
        triggeredOnStart: true
        onTriggered: runner.connectSource(root.jsonCmd)
    }

    Timer {
        id: refreshSoon
        interval: 1000
        onTriggered: runner.connectSource(root.jsonCmd)
    }

    compactRepresentation: MouseArea {
        Layout.minimumWidth: label.implicitWidth + Kirigami.Units.largeSpacing
        Layout.preferredWidth: Layout.minimumWidth
        onClicked: root.expanded = !root.expanded

        PC3.Label {
            id: label
            anchors.centerIn: parent
            text: root.status
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 26
        Layout.preferredWidth: Kirigami.Units.gridUnit * 26
        Layout.preferredHeight: Kirigami.Units.gridUnit * 32
        collapseMarginsHint: true

        // Points and level progress on the left, Sync now on the right.
        header: PlasmaExtras.PlasmoidHeading {
            contentItem: RowLayout {
                spacing: Kirigami.Units.largeSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        PlasmaExtras.Heading {
                            level: 2
                            text: root.menu ? `${root.menu.pts} points` : root.error || "Loading…"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        PC3.Label {
                            visible: !!root.menu
                            text: root.menu ? `${root.menu.streak}-day streak`
                                + (root.menu.freezes ? ` · ${root.menu.freezes} freeze` : "") : ""
                            opacity: 0.7
                        }
                    }
                    // Every 100 points is a level.
                    PC3.ProgressBar {
                        Layout.fillWidth: true
                        visible: !!root.menu
                        from: 0
                        to: 100
                        value: root.menu ? 100 - root.menu.to_next : 0
                    }
                    PC3.Label {
                        visible: !!root.menu
                        text: root.menu ? `Level ${root.menu.level} · ${root.menu.to_next} to level ${root.menu.level + 1}` : ""
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }

                PC3.ToolButton {
                    Layout.alignment: Qt.AlignTop
                    icon.name: root.actIcon.sync
                    display: QQC2.AbstractButton.IconOnly
                    text: "Sync now"
                    onClicked: root.run("sync", "")
                    PC3.ToolTip.text: text
                    PC3.ToolTip.visible: hovered
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }
        }

        contentItem: ColumnLayout {
            spacing: 0

            // The running focus timer or break, and the session buttons: focus, finished, stop, 10 more
            // minutes, break.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                visible: root.timing || (root.menu && root.menu.top.length > 0)
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    visible: root.timing
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        source: root.status.startsWith("\u{F051B}") ? "chronometer-start" : "chronometer-pause"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    }
                    PlasmaExtras.Heading {
                        Layout.fillWidth: true
                        level: 3
                        text: root.status.replace(/^\S+ /, "")
                        elide: Text.ElideRight
                    }
                }

                Repeater {
                    model: root.menu ? root.menu.top : []
                    PC3.Button {
                        required property var modelData
                        Layout.fillWidth: true
                        icon.name: root.actIcon[modelData.act] || ""
                        text: modelData.text
                        onClicked: root.run(modelData.act, modelData.id)
                        PC3.ToolTip.text: text
                        PC3.ToolTip.visible: hovered && implicitWidth > width
                        PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
                visible: root.timing || (root.menu && root.menu.top.length > 0)
            }

            PC3.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff

                ListView {
                    id: list
                    model: root.menu ? root.menu.tasks : []
                    clip: true
                    currentIndex: -1
                    topMargin: Kirigami.Units.smallSpacing
                    bottomMargin: Kirigami.Units.smallSpacing
                    leftMargin: Kirigami.Units.smallSpacing
                    rightMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing
                    highlight: PlasmaExtras.Highlight {}
                    highlightMoveDuration: Kirigami.Units.shortDuration
                    highlightResizeDuration: Kirigami.Units.shortDuration

                    PlasmaExtras.PlaceholderMessage {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.gridUnit * 4
                        visible: root.menu && list.count === 0
                        iconName: "checkmark"
                        text: "All caught up"
                    }

                    // Click a task for its actions. The list is rebuilt when the menu changes, so the open
                    // task is remembered by id and opened again.
                    delegate: PlasmaExtras.ExpandableListItem {
                        id: row
                        required property var modelData
                        required property int index
                        width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
                        icon: root.sourceIcon[modelData.source] || "view-calendar-tasks"
                        iconEmblem: modelData.late ? "emblem-important" : ""
                        title: modelData.title
                        subtitle: (modelData.course ? modelData.course + " · " : "")
                            + (modelData.late ? modelData.left : "due in " + modelData.left)
                        subtitleColor: modelData.late ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor

                        Instantiator {
                            model: row.modelData.actions
                            delegate: QQC2.Action {
                                required property var modelData
                                text: modelData.text
                                icon.name: modelData.act === "open" && row.modelData.source === "anki"
                                    ? "anki" : (root.actIcon[modelData.act] || "")
                                onTriggered: root.run(modelData.act, modelData.id)
                            }
                            onObjectAdded: (i, action) => row.contextualActions.push(action)
                        }

                        onItemExpanded: root.openId = modelData.id
                        onItemCollapsed: {
                            if (root.openId === modelData.id) {
                                root.openId = ""
                            }
                        }
                        Component.onCompleted: {
                            if (root.openId === modelData.id) {
                                Qt.callLater(expand)
                            }
                        }
                    }
                }
            }
        }
    }
}
