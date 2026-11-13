import QtQuick
import Quickshell
import Quickshell.Io

// The to-do list (~/.local/bin/todo): due counts on the bar, the list in a dropdown (Super+T).
Dropdown {
    id: menu
    menuWidth: 440

    property var data: null
    property int today: 0
    property int week: 0
    property string focusText: ""
    property int expanded: -1
    readonly property string todo: Quickshell.env("HOME") + "/.local/bin/todo"

    readonly property string barText: focusText !== "" ? focusText : (data ? `${today} · ${week}` : "?")

    function refresh() { if (!load.running) load.running = true; }
    function run(act, id) {
        Quickshell.execDetached(id ? [todo, "do", act, id] : [todo, "do", act]);
        menu.close();
        later.restart();
    }

    onOpening: { expanded = -1; refresh(); }

    Process {
        id: load
        command: [menu.todo, "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { menu.data = JSON.parse(this.text); } catch (e) { return; }
                const now = Date.now() / 1000, unit = { m: 60, h: 3600, d: 86400, w: 604800 };
                const end = new Date(); end.setHours(23, 59, 59, 0);
                let t = 0, w = 0;
                for (const task of menu.data.tasks || []) {
                    let s = 0;
                    const re = /(\d+)\s*([mhdw])/g;
                    let m;
                    while ((m = re.exec(task.left || "")) !== null) s += parseInt(m[1]) * (unit[m[2]] || 0);
                    if (task.late) s = 0;
                    if (task.late || now + s <= end.getTime() / 1000) t++;
                    if (task.late || s < 7 * 86400) w++;
                }
                menu.today = t; menu.week = w;
            }
        }
    }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: menu.refresh() }
    Timer { id: later; interval: 1500; onTriggered: menu.refresh() }

    // A focus session's countdown, written by todo as "END ICON TEXT".
    FileView {
        id: focusFile
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/todo-focus"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            const parts = (focusFile.loaded ? focusFile.text() : "").trim().split(/\s+/);
            const left = parseInt(parts[0]) - Math.floor(Date.now() / 1000);
            menu.focusText = left > 0 ? `${Math.floor(left / 60)}:${String(left % 60).padStart(2, "0")}` : "";
        }
    }

    MenuItem {
        header: true
        text: menu.data ? `${menu.data.pts} points · ${menu.data.streak}-day streak · level ${menu.data.level}` : "To-do"
    }
    Repeater {
        model: menu.data ? menu.data.top || [] : []
        MenuItem { required property var modelData; text: modelData.text; glyph: ""; onClicked: menu.run(modelData.act, modelData.id) }
    }
    Separator {}
    MenuItem { visible: menu.data && (menu.data.tasks || []).length === 0; text: menu.data ? "All caught up" : "To-do couldn't load"; enabled: false }
    Repeater {
        model: menu.data ? menu.data.tasks || [] : []
        Column {
            required property var modelData
            required property int index
            width: parent.width
            MenuItem {
                text: (modelData.late ? "! " : "") + modelData.title
                detail: (modelData.course ? modelData.course + " · " : "") + (modelData.late ? modelData.left : "in " + modelData.left)
                glyph: menu.expanded === index ? "" : ""
                onClicked: menu.expanded = menu.expanded === index ? -1 : index
            }
            Repeater {
                model: menu.expanded === index ? modelData.actions || [] : []
                MenuItem {
                    required property var modelData
                    text: "      " + modelData.text
                    onClicked: menu.run(modelData.act, modelData.id)
                }
            }
        }
    }
    Separator {}
    MenuItem { text: "Sync now"; glyph: ""; onClicked: menu.run("sync") }
}
