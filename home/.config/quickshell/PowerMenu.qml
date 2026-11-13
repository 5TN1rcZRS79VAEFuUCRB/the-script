import QtQuick
import Quickshell
import Quickshell.Hyprland

// Lock, sleep, log out, restart, shut down.
Dropdown {
    id: menu
    menuWidth: 220
    function run(cmd) { menu.close(); Quickshell.execDetached(cmd); }

    MenuItem { text: "Lock"; glyph: ""; detail: "Super+L"; onClicked: menu.run(["loginctl", "lock-session"]) }
    MenuItem { text: "Suspend"; glyph: ""; onClicked: menu.run(["systemctl", "suspend"]) }
    Separator {}
    MenuItem { text: "Log Out"; glyph: ""; onClicked: { menu.close(); Hyprland.dispatch("hl.dsp.exit()"); } }
    MenuItem { text: "Restart"; glyph: ""; onClicked: menu.run(["systemctl", "reboot"]) }
    MenuItem { text: "Shut Down"; glyph: ""; onClicked: menu.run(["systemctl", "poweroff"]) }
}
