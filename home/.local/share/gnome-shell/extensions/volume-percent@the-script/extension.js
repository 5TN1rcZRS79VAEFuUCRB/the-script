// The output volume as a percentage: after the speaker icon in the top bar, and as the label of the
// popup the volume keys (and scrolling on the icon) show. Above 100% when Over-Amplification is on.
import Clutter from 'gi://Clutter';
import St from 'gi://St';

import {Extension, InjectionManager} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as Volume from 'resource:///org/gnome/shell/ui/status/volume.js';

// The popup's icons for the output volume; brightness, the microphone and the rest keep no label.
const VOLUME_ICON = /^audio-(volume|headphones|speakers)/;

export default class VolumePercentExtension extends Extension {
    enable() {
        this._control = Volume.getMixerControl();
        this._label = new St.Label({style_class: 'volume-percent', y_align: Clutter.ActorAlign.CENTER});
        // The speaker indicator hides itself with no output device, and the label with it.
        Main.panel.statusArea.quickSettings._volumeOutput?.add_child(this._label);

        this._control.connectObject(
            'state-changed', () => this._watchSink(),
            'default-sink-changed', () => this._watchSink(),
            this);
        this._watchSink();

        this._injections = new InjectionManager();
        this._injections.overrideMethod(Main.osdWindowManager, '_showOsdWindow', orig =>
            function (monitorIndex, icon, label, level, maxLevel) {
                if (!label && typeof level === 'number' && level >= 0 && VOLUME_ICON.test(icon?.to_string() ?? ''))
                    label = icon.to_string().includes('muted') ? 'Muted' : `${Math.round(level * 100)}%`;
                orig.call(this, monitorIndex, icon, label, level, maxLevel);
            });
    }

    disable() {
        this._injections.clear();
        this._injections = null;
        this._sink?.disconnectObject(this);
        this._sink = null;
        this._control.disconnectObject(this);
        this._control = null;
        this._label.destroy();
        this._label = null;
    }

    _watchSink() {
        this._sink?.disconnectObject(this);
        this._sink = this._control.get_default_sink();
        this._sink?.connectObject(
            'notify::volume', () => this._update(),
            'notify::is-muted', () => this._update(),
            this);
        this._update();
    }

    // Blank while muted: the icon already says so.
    _update() {
        const sink = this._sink;
        this._label.text = !sink || sink.is_muted
            ? '' : `${Math.round(100 * sink.volume / this._control.get_vol_max_norm())}%`;
        this._label.visible = this._label.text !== '';
    }
}
