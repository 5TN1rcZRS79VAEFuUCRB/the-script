// The todo daemon in the top bar: the bar text from `todo-bar` (next due date, points, streak, or the
// focus countdown). Click it or press Super+T for the menu (`todo json`), whose items run
// `todo do <action> <id>`.
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Meta from 'gi://Meta';
import Pango from 'gi://Pango';
import Shell from 'gi://Shell';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const BIN = GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin']);
const TODO = GLib.build_filenamev([BIN, 'todo']);
const TODO_BAR = GLib.build_filenamev([BIN, 'todo-bar']);

const SOURCE_ICON = {
    canvas: 'x-office-document-symbolic', schoology: 'x-office-document-symbolic', todo: 'task-due-symbolic',
    anki: 'anki', workout: 'emoji-activities-symbolic',
};
const ACT_ICON = {
    focus: 'alarm-symbolic', more: 'alarm-symbolic', rest: 'media-playback-pause-symbolic',
    pause: 'media-playback-stop-symbolic', stop: 'process-stop-symbolic', finish: 'object-select-symbolic',
    workout: 'object-select-symbolic', done: 'object-select-symbolic', done_on_time: 'object-select-symbolic',
    done_late: 'object-select-symbolic', open: 'web-browser-symbolic', hide: 'view-conceal-symbolic',
    sync: 'view-refresh-symbolic',
};
// A running focus timer or break: the bar's Nerd Font icon, then the countdown.
const FOCUS_ICON = '\u{F051B}', REST_ICON = '\u{F0176}';
// Rows that only show something: not greyed out like reactive: false would.
const INFO = {activate: false, hover: false, can_focus: false};

// Runs argv and resolves to {ok, out, err}.
function run(argv) {
    return new Promise((resolve, reject) => {
        let proc;
        try {
            proc = Gio.Subprocess.new(argv, Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE);
        } catch (e) {
            reject(e);
            return;
        }
        proc.communicate_utf8_async(null, null, (p, res) => {
            try {
                const [, out, err] = p.communicate_utf8_finish(res);
                resolve({ok: p.get_successful(), out: out ?? '', err: err ?? ''});
            } catch (e) {
                reject(e);
            }
        });
    });
}

const TodoButton = GObject.registerClass(
class TodoButton extends PanelMenu.Button {
    _init() {
        super._init(0.5, 'To-do');
        this._status = '';
        this._json = null;   // the last `todo json` text, so an unchanged menu isn't rebuilt
        this._openId = '';   // the task whose actions are showing
        this._rebuilding = false;
        this._busy = {};

        this._label = new St.Label({text: '', y_align: Clutter.ActorAlign.CENTER});
        this.add_child(this._label);

        this.menu.box.add_style_class_name('todo-menu');
        this._header = new PopupMenu.PopupMenuItem('Loading...', INFO);
        this._header.label.add_style_class_name('todo-header');
        this._header.label.clutter_text.line_wrap = true;
        this.menu.addMenuItem(this._header);
        this._timer = new PopupMenu.PopupImageMenuItem('', 'alarm-symbolic', INFO);
        this.menu.addMenuItem(this._timer);
        // Timer and session rows: focus, finished, stop, 10 more minutes, break.
        this._top = new PopupMenu.PopupMenuSection();
        this.menu.addMenuItem(this._top);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // The tasks scroll when there are many. Added as a menu section first, so its items close the
        // menu and open their submenus like any other, then moved into the scroll view.
        this._tasks = new PopupMenu.PopupMenuSection();
        this.menu.addMenuItem(this._tasks);
        this.menu.box.remove_child(this._tasks.actor);
        this._scroll = new St.ScrollView({style_class: 'todo-tasks', overlay_scrollbars: true, child: this._tasks.actor});
        this.menu.box.add_child(this._scroll);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        const sync = new PopupMenu.PopupImageMenuItem('Sync now', ACT_ICON.sync);
        sync.connect('activate', () => this._do('sync', ''));
        this.menu.addMenuItem(sync);

        this._timer.visible = false;
        this._tick = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
            this._refreshStatus();
            return GLib.SOURCE_CONTINUE;
        });
        this._refreshStatus();

        // Only while open: `todo json` also closes the sticky reminders, which counts as seeing them.
        this._menuTick = 0;
        this.menu.connect('open-state-changed', (m, open) => {
            if (open) {
                this._refreshMenu();
                this._menuTick = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 3, () => {
                    this._refreshMenu();
                    return GLib.SOURCE_CONTINUE;
                });
            } else if (this._menuTick) {
                GLib.source_remove(this._menuTick);
                this._menuTick = 0;
            }
        });
    }

    // One run of each command at a time, so a slow one doesn't pile up.
    async _once(key, argv) {
        if (this._busy[key])
            return null;
        this._busy[key] = true;
        try {
            return await run(argv);
        } catch (e) {
            return {ok: false, out: '', err: e.message};
        } finally {
            this._busy[key] = false;
        }
    }

    async _refreshStatus() {
        const r = await this._once('status', [TODO_BAR]);
        if (!r || this._destroyed)
            return;
        this._status = r.out.trim();
        this._label.text = this._status;
        this._updateTimer();
    }

    _updateTimer() {
        const timing = this._status.startsWith(FOCUS_ICON) || this._status.startsWith(REST_ICON);
        this._timer.visible = timing;
        if (timing) {
            this._timer.setIcon(this._status.startsWith(FOCUS_ICON) ? 'alarm-symbolic' : 'media-playback-pause-symbolic');
            this._timer.label.text = this._status.replace(/^\S+ /, '');
        }
    }

    async _refreshMenu() {
        const r = await this._once('json', [TODO, 'json']);
        if (!r || this._destroyed || r.out === this._json)
            return;
        let menu;
        try {
            menu = JSON.parse(r.out);
        } catch (e) {
            this._header.label.text = r.err.trim() || 'todo json failed';
            return;
        }
        this._json = r.out;
        this._build(menu);
    }

    _build(menu) {
        this._header.label.text = `${menu.pts} points · Level ${menu.level} (${menu.to_next} to go) · ` +
            `${menu.streak}-day streak` + (menu.freezes ? ` · ${menu.freezes} freeze` : '');

        this._rebuilding = true;
        this._top.removeAll();
        for (const a of menu.top)
            this._top.addMenuItem(this._action(a, ACT_ICON[a.act]));

        this._tasks.removeAll();
        if (!menu.tasks.length)
            this._tasks.addMenuItem(new PopupMenu.PopupImageMenuItem('All caught up', 'object-select-symbolic',
                INFO));
        // Click a task for its actions.
        for (const t of menu.tasks) {
            const item = new PopupMenu.PopupSubMenuMenuItem((t.course ? `${t.course} · ` : '') + t.title, true);
            item.icon.icon_name = SOURCE_ICON[t.source] ?? 'task-due-symbolic';
            item.label.clutter_text.ellipsize = Pango.EllipsizeMode.END;
            const left = new St.Label({text: t.left, style_class: 'todo-left', y_align: Clutter.ActorAlign.CENTER});
            if (t.late)
                left.add_style_class_name('todo-late');
            item.insert_child_at_index(left, item.get_n_children() - 1);   // before the arrow
            for (const a of t.actions) {
                const icon = a.act === 'open' && t.source === 'anki' ? 'anki' : ACT_ICON[a.act];
                item.menu.addMenuItem(this._action(a, icon));
            }
            item.menu.connect('open-state-changed', (m, open) => {
                if (this._rebuilding)
                    return;
                if (open)
                    this._openId = t.id;
                else if (this._openId === t.id)
                    this._openId = '';
            });
            this._tasks.addMenuItem(item);
            if (t.id === this._openId)
                item.setSubmenuShown(true);
        }
        this._rebuilding = false;
    }

    _action(a, icon) {
        const item = icon
            ? new PopupMenu.PopupImageMenuItem(a.text, icon)
            : new PopupMenu.PopupMenuItem(a.text);
        item.connect('activate', () => this._do(a.act, a.id));
        return item;
    }

    // Detached: a focus session runs for 10 minutes. Picking an item closes the menu, and it is read
    // again when next opened.
    _do(act, id) {
        const argv = ['setsid', '-f', TODO, 'do', act];
        if (id)
            argv.push(id);
        run(argv).catch(e => logError(e, 'todo do'));
    }

    destroy() {
        this._destroyed = true;
        GLib.source_remove(this._tick);
        if (this._menuTick)
            GLib.source_remove(this._menuTick);
        super.destroy();
    }
});

export default class TodoExtension extends Extension {
    enable() {
        this._button = new TodoButton();
        Main.panel.addToStatusArea(this.uuid, this._button, 1, 'left');   // after Activities: the right side is too narrow for it
        Main.wm.addKeybinding('toggle-menu', this.getSettings(), Meta.KeyBindingFlags.NONE,
            Shell.ActionMode.NORMAL | Shell.ActionMode.OVERVIEW, () => this._button.menu.toggle());
    }

    disable() {
        Main.wm.removeKeybinding('toggle-menu');
        this._button.destroy();
        this._button = null;
    }
}
