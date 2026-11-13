// the-script's plain overview: Super shows the search box and every open window, nothing else.
// The dash (the dock at the bottom, with the app grid button) is hidden and takes no room; typing still
// searches apps, files and settings. With one workspace (the-script-gnome sets that) GNOME leaves out
// the workspace strip by itself. Turn this off in the Extensions app to get the dash back.
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class PlainOverview extends Extension {
    enable() {
        const dash = Main.overview.dash;
        dash.hide();
        dash.set_height(0);   // the overview lays out by the dash's height even while it's hidden
        this._id = dash.connect('notify::visible', () => dash.visible && dash.hide());
    }

    disable() {
        const dash = Main.overview.dash;
        dash.disconnect(this._id);
        dash.set_height(-1);
        dash.show();
    }
}
