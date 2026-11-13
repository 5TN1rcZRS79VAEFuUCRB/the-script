#!/usr/bin/env bash
#
# the-script: recreates this desktop (GNOME, kept plain and set up for games) on an Arch Linux
# machine. Run as your normal user (it calls sudo where it needs root):  ./install.sh
# Safe to re-run; anything it would overwrite is backed up first.

set -euo pipefail
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

DO_PACKAGES=1
WITH_STEAM=0

usage() {
	cat <<'EOF'
Usage: ./install.sh [options]

  --steam         also install Steam (needs the [multilib] repo enabled in
                  /etc/pacman.conf) and the matching 32-bit graphics libraries
  --no-packages   skip the pacman step
  -h, --help      this text
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
	--steam)       WITH_STEAM=1 ;;
	--no-packages) DO_PACKAGES=0 ;;
	-h|--help)     usage; exit 0 ;;
	*)             echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
	esac
	shift
done

say()  { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "run this as your normal user, not root (it uses sudo where needed)"
command -v pacman >/dev/null || die "this installer is for Arch Linux (pacman not found)"
command -v sudo   >/dev/null || die "sudo is required"

BACKUP="$HOME/.desktop-backup/$(date +%Y%m%d-%H%M%S)"
REPLACED=()

backup_if_different() { # dest src
	local dest=$1 src=$2 rel
	if [ -e "$dest" ] && ! cmp -s "$src" "$dest"; then
		rel=${dest#"$HOME"/}
		mkdir -p "$BACKUP/$(dirname "$rel")"
		cp -a "$dest" "$BACKUP/$rel"
		REPLACED+=("$rel")
	fi
}

place() { # src dest
	local src=$1 dest=$2 mode=644
	[ -x "$src" ] && mode=755
	backup_if_different "$dest" "$src"
	install -Dm"$mode" "$src" "$dest"
}

# Moves a file or folder of this user's into the backup, for things the-script no longer installs.
retire() { # path...
	local p rel
	for p in "$@"; do
		[ -e "$p" ] || [ -L "$p" ] || continue
		rel=${p#"$HOME"/}
		mkdir -p "$BACKUP/$(dirname "$rel")"
		mv "$p" "$BACKUP/$rel"
		REPLACED+=("$rel")
	done
}

# Root-owned files: an existing different one is kept next to it as .bak-<date>.
sudo_place() { # src dest
	local mode=644
	[ -x "$1" ] && mode=755
	cmp -s "$1" "$2" 2>/dev/null && return
	[ -e "$2" ] && sudo cp -a "$2" "$2.bak-$(date +%Y%m%d-%H%M%S)"
	sudo install -Dm"$mode" "$1" "$2"
	echo "Installed $2"
}


# ---------------------------------------------------------------- passwordless sudo
# the-script-update re-runs this installer unattended when a commit is pushed, so its sudo calls
# cannot ask for a password. This makes the user root-equivalent without one: anything running as
# this user, and anyone who can push to the repo, gets root. Undo: sudo rm /etc/sudoers.d/10-the-script
SUDOERS=/etc/sudoers.d/10-the-script
if ! sudo test -e "$SUDOERS"; then
	say "Passwordless sudo for $(id -un) (lets the-script-update run this installer unattended)"
	tmp="$(mktemp)"
	echo "$(id -un) ALL=(ALL) NOPASSWD: ALL" > "$tmp"
	sudo visudo -cqf "$tmp" && sudo install -m440 "$tmp" "$SUDOERS"
	rm -f "$tmp"
fi
# The same rule under its name from niri-script, removed once the new one is in place.
sudo test -e "$SUDOERS" && sudo rm -f /etc/sudoers.d/10-niri-update

# ---------------------------------------------------------------- packages
listed() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$1" | grep -v '^$'; }
# Of the packages named, those nothing else installed still needs (safe to remove together).
unneeded() {
	[ $# -gt 0 ] || return 0
	python3 - "$@" <<'EOF'
import subprocess, sys
cands = set(sys.argv[1:])
info = subprocess.run(["pacman", "-Qi", *cands], capture_output=True, text=True).stdout
req, name = {}, None
for line in info.splitlines():
    if line.startswith("Name"):
        name = line.split(":", 1)[1].strip()
    elif line.startswith("Required By") and name:
        v = line.split(":", 1)[1].split()
        req[name] = set() if v == ["None"] else set(v)
while True:
    drop = {p for p in cands if req.get(p, set()) - cands}
    if not drop:
        break
    cands -= drop
for p in sorted(cands):
    print(p)
EOF
}
if [ "$DO_PACKAGES" -eq 1 ]; then
	say "Installing packages (sudo password may be requested)"
	mapfile -t PKGS < <(listed packages.txt)
	# Only packages not installed yet. Naming an installed one to `pacman -S` upgrades it alone (a
	# partial upgrade), and --noconfirm even overrides IgnorePkg: that pulled a pinned xorg-server
	# forward and Xorg then crashed in the amdgpu driver. Upgrades stay with pacman -Syu.
	mapfile -t MISSING < <(pacman -T "${PKGS[@]}" || true)
	[ ${#MISSING[@]} -eq 0 ] || sudo pacman -S --noconfirm "${MISSING[@]}"
fi

# ---------------------------------------------------------------- leftovers from niri-script
# This repo was niri-script, a niri desktop, before it became the-script. Its scripts, services and
# autostart are retired into the backup folder (a niri session still running keeps working until you
# log out). Its niri, waybar and dunst settings in ~/.config stay where they are, unused.
MIGRATED=0
if [ -e "$HOME/.local/state/niri-script-installed" ] || [ -L "$HOME/.local/share/niri-script" ]; then
	say "Retiring niri-script's scripts and services"
	MIGRATED=1
	systemctl --user disable --now niri-update.timer niri-steam-overlay.path 2>/dev/null || true
	retire "$HOME"/.config/systemd/user/niri-{update.timer,steam-overlay.path,steam-overlay.service}
	retire "$HOME"/.local/bin/{dmenu,niri-audio,niri-down,niri-mouse,niri-net,niri-place,niri-power,niri-status,niri-tray,niri-todo,niri-update,niri-steam-overlay}
	retire "$HOME/.local/share/Anki2/addons21/niri_todo"
	rm -f "$HOME/.local/share/niri-script" "$HOME/.local/state/niri-script-installed"
	[ -e /etc/udev/rules.d/70-niri-mouse-dpi.rules ] && sudo rm -f /etc/udev/rules.d/70-niri-mouse-dpi.rules
	# niri-script's updater, which ran this, then flags niri to restart once idle. Without its helper
	# scripts a restarted niri has no bar, so the flags are cleared once it has set them.
	if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
		systemd-run --user --collect -q --on-active=60 /usr/bin/rm -f \
			"$XDG_RUNTIME_DIR/niri-restart-session" "$XDG_RUNTIME_DIR/dwm-restart-session" || true
	fi
fi
# niri-update.service may be the unit running this installer. Removing its file now would make the
# daemon-reload below forget it is a oneshot, and systemd would kill this run on the default 90s start
# timeout. So it waits for a run that it did not start.
[ "$(systemctl --user show -p ActiveState --value niri-update.service 2>/dev/null)" = activating ] \
	|| retire "$HOME/.config/systemd/user/niri-update.service"
# niri itself and the packages only its session used. Not while a niri session is running.
NIRI_PKGS=(niri xwayland-satellite waybar dunst bemenu-wayland bemenu)
mapfile -t NIRI_HAVE < <(pacman -Qq "${NIRI_PKGS[@]}" 2>/dev/null || true)
if [ ${#NIRI_HAVE[@]} -gt 0 ] && ! pgrep -x niri >/dev/null; then
	say "Removing niri"
	sudo pacman -Rs --noconfirm "${NIRI_HAVE[@]}" || warn "could not remove niri; run: sudo pacman -Rs ${NIRI_HAVE[*]}"
fi

# ---------------------------------------------------------------- leftovers from AeroThemePlasma
# the-script was a Windows 7-style KDE Plasma desktop (AeroThemePlasma) before GNOME and plain Plasma.
# A machine that never left the Windows 7 desktop loses its add-ons here; Plasma goes below.
# aeroshell-libplasma-git stands in for libplasma, so libplasma replaces it (--ask=4: yes to the conflict).
AERO_PKGS=(aeroshell-libplasma-git aeroshell-workspace-git aeroshell-kwin-components-git aeroshell-smod-git
	aerothemeplasma-desktop-git aerothemeplasma-sounds-git aerothemeplasma-icons-git uac-polkit-agent-git
	ttf-selawik millennium kvantum)
mapfile -t AERO_HAVE < <(pacman -Qq "${AERO_PKGS[@]}" 2>/dev/null || true)
AERO=0
if [ ${#AERO_HAVE[@]} -gt 0 ]; then
	say "Removing AeroThemePlasma (Plasma stays)"
	AERO=1
	retire "$HOME"/.config/autostart/x-atpootb.desktop \
		"$HOME"/.local/share/plasma/plasmoids/io.gitgud.wackyideas.seventasks \
		"$HOME/.local/share/plasma/look-and-feel/authui7-dark" "$HOME/.local/share/color-schemes/Windows7AeroDark.colors" \
		"$HOME"/.config/Kvantum/{Windows7AeroDark,Windows7AeroKWin} "$HOME/.local/share/icons/Windows 7 Aero" \
		"$HOME/.local/share/wallpapers/windows7-harmony.jpg" "$HOME/.config/fontconfig/conf.d/50-segoe-ui-selawik.conf" \
		"$HOME/.local/share/Steam/millennium/themes/the-script"
	sudo rm -f /etc/sddm.conf.d/10-win7.conf /etc/pacman.d/hooks/element-msn-icon.hook
	# Element's own icon file still had Windows Live Messenger's icon copied over it, and on some machines a
	# NoExtract line in pacman.conf kept updates from replacing it. Without that line, reinstalling the
	# same version puts Element's icon back; if a newer one is out, that update does it instead.
	sudo sed -i '\|^NoExtract *= *usr/lib/element/build/icon.png$|d' /etc/pacman.conf
	sudo rm -f /usr/lib/element/build/icon.png.orig
	if pacman -Qkk element-desktop 2>&1 | grep -q 'build/icon.png' \
		&& [ "$(pacman -Q element-desktop | cut -d' ' -f2)" = "$(pacman -Si element-desktop 2>/dev/null | awk '/^Version/ {print $3}')" ]; then
		sudo pacman -S --noconfirm element-desktop >/dev/null || warn "could not restore Element's icon"
	fi
	if printf '%s\n' "${AERO_HAVE[@]}" | grep -qx aeroshell-libplasma-git; then
		sudo pacman -S --noconfirm --ask=4 libplasma || warn "could not put libplasma back in place of aeroshell-libplasma-git"
	fi
	mapfile -t AERO_HAVE < <(pacman -Qq "${AERO_PKGS[@]}" 2>/dev/null || true)
	if [ ${#AERO_HAVE[@]} -gt 0 ] && ! sudo pacman -Rs --noconfirm "${AERO_HAVE[@]}"; then
		warn "could not remove AeroThemePlasma; run: sudo pacman -Rs ${AERO_HAVE[*]}"
	fi
fi

# ---------------------------------------------------------------- leftovers from the first GNOME
# the-script was GNOME once before, with a ThinkPad look (gray folders, red accent, square title bars for
# KeePassXC and OBS through X11) and a patched Settings. Those leftovers go; GNOME itself is the desktop.
retire "$HOME/.local/share/dbus-1/services/org.gnome.Settings.service" \
	"$HOME"/.local/share/applications/{org.keepassxc.KeePassXC,com.obsproject.Studio}.desktop \
	"$HOME"/.local/share/backgrounds/{arch.svg,thinkpad.svg,thinkpad-20-dark.png,thinkpad-20-light.png}
rm -rf "$HOME/.local/share/icons/Adwaita-ThinkPad"   # made by install.sh, not yours
for f in "$HOME"/.config/gtk-{3,4}.0/gtk.css; do
	grep -q 'ThinkPad' "$f" 2>/dev/null && retire "$f"
done
rm -f "$HOME"/.local/state/the-script-{gnome-first-run,gnome-librewolf-dash,gnome-app-folders,gnome-app-folders-3,kde-pending,remove-gnome}
sudo rm -f /usr/local/libexec/settings-pointer-speed /etc/udev/rules.d/{70-mouse-dpi,70-dwm-mouse-dpi}.rules
systemctl --user disable --now display-wake.service >/dev/null 2>&1 || true
retire "$HOME/.local/bin/display-wake" "$HOME/.config/systemd/user/display-wake.service"

# ---------------------------------------------------------------- leftovers from KDE Plasma
# the-script was KDE Plasma before LXQt. Its login script, taskbar widget and settings files go now (a
# running Plasma keeps what it loaded until you log out). Plasma's own packages, SDDM and other desktops'
# leftovers (openbox, the X server from the dwm days) are removed by a run with no Plasma running:
# the-script-gnome starts one at the first GNOME login. SDDM goes once it isn't the login screen in use
# (after a restart into GDM). Settings of the removed apps in ~/.config stay, unused.
retire "$HOME/.local/bin/the-script-plasma" "$HOME/.config/autostart/the-script-plasma.desktop" \
	"$HOME/.local/share/plasma/plasmoids/local.todo" "$HOME/.local/share/plasma/plasmoids/local.niritodo" \
	"$HOME"/.local/share/applications/{kdesystemsettings,org.kde.kwrite}.desktop \
	"$HOME/.config/autostart/todo-lxqt.desktop" "$HOME/.icons/Adwaita-cursors"
rm -f "$HOME"/.local/state/the-script-plasma-*
# Plasma's GTK colors (gtk.css importing colors.css) would keep GTK apps in Breeze's.
for f in "$HOME"/.config/gtk-{3,4}.0/gtk.css; do
	grep -q 'colors.css' "$f" 2>/dev/null && retire "$f" "${f%/*}/colors.css"
done

KDE_PENDING="$HOME/.local/state/the-script-remove-kde"
mapfile -t KDE_PKGS < <({ pacman -Qgq plasma kde-applications 2>/dev/null
	printf '%s\n' plasma-desktop plasma-workspace kwin systemsettings plasma-nm plasma-pa plasma5support powerdevil \
		bluedevil kscreen breeze breeze-gtk breeze-cursors kde-gtk-config sddm-kcm \
		xdg-desktop-portal-kde dolphin konsole kate gwenview spectacle kdialog openbox obconf-qt \
		xorg-server xorg-xinit xf86-video-amdgpu xf86-video-ati xf86-video-intel xf86-video-nouveau \
		xf86-video-vesa xf86-video-fbdev xf86-input-libinput xf86-input-evdev
	systemctl is-active -q sddm 2>/dev/null || echo sddm; } | sort -u | xargs -r pacman -Qq 2>/dev/null || true)
if [ ${#KDE_PKGS[@]} -gt 0 ] && pgrep -x plasmashell >/dev/null; then
	say "Plasma is running: it is removed after you log into GNOME"
	mkdir -p "${KDE_PENDING%/*}" && touch "$KDE_PENDING"
elif [ ${#KDE_PKGS[@]} -gt 0 ]; then
	say "Removing Plasma, SDDM and other desktops' leftovers"
	# What packages.txt lists stays even where Plasma pulled it in first.
	mapfile -t keep < <(pacman -Qq $(listed packages.txt) 2>/dev/null || true)
	[ ${#keep[@]} -eq 0 ] || sudo pacman -D -q --asexplicit "${keep[@]}" >/dev/null
	# Only what nothing else installed still needs.
	mapfile -t KDE_PKGS < <(unneeded "${KDE_PKGS[@]}")
	if [ ${#KDE_PKGS[@]} -gt 0 ]; then
		if ! sudo pacman -Rs --noconfirm "${KDE_PKGS[@]}"; then
			warn "could not remove Plasma; run: sudo pacman -Rs ${KDE_PKGS[*]}"
			notify-send -u critical "the-script: Plasma was not removed" "Run: sudo pacman -Rs ${KDE_PKGS[*]}" 2>/dev/null || true
		fi
	fi
	if ! pacman -Qq sddm >/dev/null 2>&1; then   # SDDM's files from the-script
		sudo rm -f /etc/sddm.conf.d/{10-the-script,20-the-script-scale}.conf /usr/local/share/the-script/sddm-background.jpg \
			/usr/share/sddm/themes/breeze/theme.conf.user
		sudo rmdir -p --ignore-fail-on-non-empty /etc/sddm.conf.d /usr/share/sddm/themes/breeze 2>/dev/null || true
	fi
	# Done once SDDM (and the X server only it needed) is gone too; until then each login tries again.
	if pacman -Qq sddm >/dev/null 2>&1; then touch "$KDE_PENDING"; else rm -f "$KDE_PENDING"; fi
fi

# With Plasma gone, its apps' settings and caches (and niri's, foot's and Kvantum's) move to the backup
# folder.
if ! pacman -Qq plasma-workspace >/dev/null 2>&1; then
	retire "$HOME"/.config/{baloofilerc,dolphinrc,kaccessrc,kactivitymanagerdrc,kactivitymanagerd-statsrc,kate,kate-externaltoolspluginrc} \
		"$HOME"/.config/{katerc,katevirc,kcminputrc,kconf_updaterc,KDE,kded5rc,kded6rc,kdedefaults,kdeglobals,kde-mimeapps.list} \
		"$HOME"/.config/{kglobalshortcutsrc,konsolerc,konsolesshconfig,krunnerrc,kscreenlockerrc,ksmserverrc,ktimezonedrc} \
		"$HOME"/.config/{kuriikwsfilterrc,kwalletrc,kwinrc,kwinrulesrc,plasma-localerc,plasmanotifyrc,plasmaparc,plasmashellrc} \
		"$HOME"/.config/{powerdevilrc,spectaclerc,xsettingsd,session,Kvantum,niri,foot,kxkbrc,ksplashrc,gtkrc,gtkrc-2.0} \
		"$HOME"/.config/plasma-*-appletsrc "$HOME/.gtkrc-2.0" \
		"$HOME"/.local/share/{baloo,color-schemes,dolphin,kactivitymanagerd,kate,klipper,konsole,krunnerstaterc,kwalletd} \
		"$HOME"/.local/share/{plasma,sddm,kxmlgui5,knewstuff3,niri}
	rm -rf "$HOME"/.cache/{plasma*,kwin,krunner*,ksycoca6*,ksvg-elements*,dolphin,konsole,kate,org.kde.*,kioexec,icon-cache.kcache}
fi

# ---------------------------------------------------------------- leftovers from LXQt
# the-script was LXQt on labwc (the ClassicDark look) before Hyprland. Its scripts, themes and autostart
# entries go now (a running LXQt keeps what it loaded until you log out). LXQt's packages, labwc (with
# the-script's patched builds of them) and their apps are removed by a run with no LXQt running:
# the-script-gnome starts one at the first GNOME login. Their settings move to the backup folder then.
retire "$HOME"/.local/bin/{the-script-lxqt,start-menu-prime,audio-menu,audio-status,battery-text,todo-count,todo-menu} \
	"$HOME"/.config/autostart/{the-script-lxqt,steam-overlay-scale}.desktop \
	"$HOME/.local/share/themes/ClassicDark" "$HOME/.local/share/lxqt/themes/ClassicDark"
rm -rf "$HOME/.local/state/the-script-seeds"
LXQT_PENDING="$HOME/.local/state/the-script-remove-lxqt"
mapfile -t LXQT_PKGS < <({ pacman -Qgq lxqt 2>/dev/null
	printf '%s\n' lxqt-session lxqt-wayland-session labwc lxqt-panel lxqt-config lxqt-qtplugin lxqt-themes \
		lxqt-globalkeys lxqt-notificationd lxqt-policykit lxqt-powermanagement lxqt-runner \
		xdg-desktop-portal-lxqt xdg-desktop-portal-wlr pcmanfm-qt qterminal featherpad lximage-qt pavucontrol-qt \
		mate-icon-theme swaybg swaylock wtype wlrctl
	} | sort -u | xargs -r pacman -Qq 2>/dev/null || true)
if [ ${#LXQT_PKGS[@]} -gt 0 ] && pgrep -x lxqt-session >/dev/null; then
	say "LXQt is running: it is removed after you log into GNOME"
	mkdir -p "${LXQT_PENDING%/*}" && touch "$LXQT_PENDING"
elif [ ${#LXQT_PKGS[@]} -gt 0 ]; then
	say "Removing LXQt and labwc"
	# What packages.txt lists stays even where LXQt pulled it in first.
	mapfile -t keep < <(pacman -Qq $(listed packages.txt) 2>/dev/null || true)
	[ ${#keep[@]} -eq 0 ] || sudo pacman -D -q --asexplicit "${keep[@]}" >/dev/null
	mapfile -t LXQT_PKGS < <(unneeded "${LXQT_PKGS[@]}")
	if [ ${#LXQT_PKGS[@]} -gt 0 ] && ! sudo pacman -Rs --noconfirm "${LXQT_PKGS[@]}"; then
		warn "could not remove LXQt; run: sudo pacman -Rs ${LXQT_PKGS[*]}"
		notify-send -u critical "the-script: LXQt was not removed" "Run: sudo pacman -Rs ${LXQT_PKGS[*]}" 2>/dev/null || true
	fi
	rm -f "$LXQT_PENDING"
	retire "$HOME"/.config/{lxqt,labwc,pcmanfm-qt,qterminal.org,featherpad,lximage-qt,pavucontrol-qt}
fi
rm -rf "$HOME"/.cache/the-script-build-*   # pkg/build-patched.sh's leftover build folders
sudo rm -f /etc/greetd/lxqt-session

# ---------------------------------------------------------------- leftovers from Hyprland
# the-script was Hyprland with Noctalia and its own Super overview (Quickshell) before GNOME. Its
# settings and scripts go now (a running Hyprland keeps what it loaded until you log out). Hyprland,
# Noctalia, greetd and the apps only it used are removed by a run with no Hyprland running:
# the-script-gnome starts one at the first GNOME login.
retire "$HOME"/.config/{hypr,quickshell,noctalia,mako} "$HOME/.local/share/the-script-plugins" \
	"$HOME"/.local/bin/{the-script-session,the-script-displays,the-script-login,todo-pick} \
	"$HOME/.config/systemd/user/the-script-session.target" "$HOME/.cache/the-script/noctalia-colors.json"
# Hyprland's own GTK and Qt settings files; GNOME sets these itself.
for f in "$HOME"/.config/gtk-{3,4}.0/settings.ini; do
	grep -q 'gtk-application-prefer-dark-theme=1' "$f" 2>/dev/null && retire "$f"
done
retire "$HOME/.config/qt6ct"
grep -q 'the-script' "$HOME/.config/foot/foot.ini" 2>/dev/null && retire "$HOME/.config/foot/foot.ini"
HYPR_PENDING="$HOME/.local/state/the-script-remove-hyprland"
mapfile -t HYPR_PKGS < <(pacman -Qq hyprland hyprland-guiutils hyprpm noctalia quickshell xdg-desktop-portal-hyprland \
	hyprpolkitagent hypridle hyprlock mako greetd greetd-tuigreet foot thunar mousepad imv pavucontrol qt6ct \
	wlr-randr grim slurp xorg-xrandr xorg-xdpyinfo 2>/dev/null || true)
if [ ${#HYPR_PKGS[@]} -gt 0 ] && pgrep -x Hyprland >/dev/null; then
	say "Hyprland is running: it is removed after you log into GNOME"
	mkdir -p "${HYPR_PENDING%/*}" && touch "$HYPR_PENDING"
elif [ ${#HYPR_PKGS[@]} -gt 0 ]; then
	say "Removing Hyprland, Noctalia and greetd"
	mapfile -t keep < <(pacman -Qq $(listed packages.txt) 2>/dev/null || true)
	[ ${#keep[@]} -eq 0 ] || sudo pacman -D -q --asexplicit "${keep[@]}" >/dev/null
	mapfile -t HYPR_PKGS < <(unneeded "${HYPR_PKGS[@]}")
	if [ ${#HYPR_PKGS[@]} -gt 0 ] && ! sudo pacman -Rs --noconfirm "${HYPR_PKGS[@]}"; then
		warn "could not remove Hyprland; run: sudo pacman -Rs ${HYPR_PKGS[*]}"
		notify-send -u critical "the-script: Hyprland was not removed" "Run: sudo pacman -Rs ${HYPR_PKGS[*]}" 2>/dev/null || true
	fi
	rm -f "$HYPR_PENDING"
	pacman -Qq greetd >/dev/null 2>&1 || sudo rm -rf /etc/greetd
	retire "$HOME/.local/state/noctalia" "$HOME/.cache/noctalia" "$HOME/.cache/quickshell.log" \
		"$HOME/.cache/the-script-session.log" "$HOME/.cache/hyprland-session.log"
fi

# ---------------------------------------------------------------- dotfiles + scripts
say "Installing config files and scripts into $HOME"
while IFS= read -r -d '' f; do
	place "$f" "$HOME/${f#home/}"
done < <(find home -type f -print0)
systemctl --user daemon-reload 2>/dev/null || true

# The todo daemon outlives a logout, so a running one would keep the old code: restart it. The
# autostart entry at the next login then finds it running. niri-todo is its name from niri-script.
was_running=0
for d in '/\.local/bin/todo daemon' '/\.local/bin/niri-todo daemon'; do
	if pkill -f "$d"; then
		was_running=1
		for _ in $(seq 50); do pgrep -f "$d" >/dev/null || break; sleep 0.1; done
	fi
done
[ "$was_running" -eq 0 ] || systemd-run --user --collect -q "$HOME/.local/bin/todo" daemon \
	|| warn "could not restart the todo daemon; run: todo daemon &"

# Black hole wallpapers the-script set for a few minutes.
rm -f "$HOME"/.local/share/wallpapers/{black-hole,nasa-black-hole}.png

# ---------------------------------------------------------------- GNOME
# The settings themselves (dark style, one workspace, Alt+Tab, the extensions, the display scale) are in
# the-script-gnome, which also runs at every login: gsettings needs the session bus.
say "GNOME: the extensions and settings"
glib-compile-schemas "$HOME/.local/share/gnome-shell/extensions/todo@the-script/schemas" \
	|| warn "could not compile the to-do extension's settings; Super+T will not open it"
if [ "${XDG_CURRENT_DESKTOP:-}" = GNOME ]; then
	"$HOME/.local/bin/the-script-gnome" || warn "could not apply the GNOME settings; they apply at the next login"
fi

# The login screen. GDM takes over at the next boot; a running session is left alone. --force replaces
# the display-manager link another one (greetd, SDDM) holds.
say "Login screen: GDM"
if ! systemctl is-enabled -q gdm 2>/dev/null; then
	sudo systemctl enable --force gdm || warn "could not enable GDM; run: sudo systemctl enable --force gdm"
fi

# ---------------------------------------------------------------- LibreWolf
find_lw_profile() {
	local base d
	for base in "$HOME/.config/librewolf/librewolf" "$HOME/.librewolf"; do
		for d in "$base"/*.default-release; do
			[ -d "$d" ] && { printf '%s\n' "$d"; return 0; }
		done
	done
	return 1
}

say "LibreWolf settings"
if command -v librewolf >/dev/null; then
	# Once: your Firefox profile (bookmarks, logins to sites, extensions) becomes LibreWolf's, or at the
	# next login if a browser is open now. Firefox itself stays installed until you remove it.
	"$HOME/.local/bin/librewolf-import-firefox" || warn "could not copy your Firefox profile into LibreWolf"
	LW_PROFILE="$(find_lw_profile || true)"
	if [ -z "$LW_PROFILE" ]; then
		echo "No LibreWolf profile yet; starting LibreWolf headless once to create it..."
		timeout 20 librewolf --headless --no-remote about:blank >/dev/null 2>&1 || true
		LW_PROFILE="$(find_lw_profile || true)"
	fi
	if [ -n "$LW_PROFILE" ]; then
		place librewolf/user.js "$LW_PROFILE/user.js"
		# LibreWolf keeps its own rounded look; the square-corner userChrome.css from before is removed.
		retire "$LW_PROFILE/chrome/userChrome.css"
		echo "Installed user.js into $LW_PROFILE (restart LibreWolf to apply)"
	else
		warn "could not find/create a LibreWolf profile. Start LibreWolf once, close it, then run:"
		warn "  ./install.sh --no-packages"
	fi
	# Violentmonkey comes from a system-wide policy, so it is installed automatically the next time
	# LibreWolf starts (uBlock Origin comes with LibreWolf). A policy file in /etc replaces LibreWolf's
	# own instead of adding to it, so librewolf-policies merges the two, and a pacman hook merges them
	# again after each LibreWolf update. Needs root because it lives in /etc.
	# The Always-visible userscript ships in this repo, but Violentmonkey keeps its scripts in its
	# own storage, which a policy cannot seed, so it is imported by hand once (see the line printed).
	sudo_place librewolf/policies.json /usr/local/share/the-script/librewolf-policies.json
	sudo_place usr/local/libexec/librewolf-policies /usr/local/libexec/librewolf-policies
	sudo_place etc/pacman.d/hooks/librewolf-policies.hook /etc/pacman.d/hooks/librewolf-policies.hook
	sudo /usr/local/libexec/librewolf-policies || warn "could not write LibreWolf's policies"
	# Links opened from other programs (todo, chat apps) go to LibreWolf, not another installed browser.
	{ xdg-settings set default-web-browser librewolf.desktop && xdg-mime default librewolf.desktop text/html; } \
		|| warn "could not make LibreWolf the default browser; run: xdg-settings set default-web-browser librewolf.desktop"
	echo "Violentmonkey will auto-install; if the userscript is not in it yet, open this in LibreWolf:"
	echo "  file://$PWD/librewolf/always-visible.user.js   (Violentmonkey shows an install page)"
else
	warn "librewolf is not installed; skipping its settings"
fi
# On a text console (the login screen, Ctrl+Alt+F2) nothing else turns the monitors off.
# console-idle keeps them off while it is blanked (a DisplayPort monitor's hotplug on going to sleep
# would light the console again).
say "Console: monitors off after 10 minutes idle"
# Element's tray icon fills its whole square, so it looked bigger than the others in the tray.
sudo_place usr/local/libexec/element-tray-icon /usr/local/libexec/element-tray-icon
sudo_place etc/pacman.d/hooks/element-tray-icon.hook /etc/pacman.d/hooks/element-tray-icon.hook
[ -e /usr/lib/element/build/icon.png ] && { sudo /usr/local/libexec/element-tray-icon || warn "could not shrink Element's tray icon"; }

sudo_place etc/systemd/system/console-blank.service /etc/systemd/system/console-blank.service
sudo_place usr/local/libexec/console-idle /usr/local/libexec/console-idle
sudo_place etc/systemd/system/console-idle.service /etc/systemd/system/console-idle.service
# The udev rule before it turned the monitor off again on each hotplug, which with the login screen
# on the console made a DisplayPort monitor wake every ~30 s.
if [ -e /etc/udev/rules.d/90-console-reblank.rules ]; then
	sudo rm -f /etc/udev/rules.d/90-console-reblank.rules /usr/local/libexec/console-reblank
	sudo udevadm control --reload || true
fi
sudo systemctl daemon-reload
sudo systemctl enable console-blank.service console-idle.service >/dev/null 2>&1 || warn "could not enable console-blank.service and console-idle.service"
sudo systemctl restart console-blank.service || warn "could not start console-blank.service; it runs at the next boot"
sudo systemctl restart console-idle.service || warn "could not start console-idle.service; it runs at the next boot"

# ---------------------------------------------------------------- old site blocklist
# the-script used to block sites in /etc/hosts with a daily timer; undo that where it was installed.
if [ -e /etc/systemd/system/the-script-blocklist.timer ] || grep -q '^# >>> the-script blocklist' /etc/hosts; then
	say "Removing the old site blocklist"
	sudo systemctl disable --now the-script-blocklist.timer >/dev/null 2>&1 || true
	sudo rm -f /etc/systemd/system/the-script-blocklist.service /etc/systemd/system/the-script-blocklist.timer \
		/usr/local/libexec/the-script-blocklist /usr/local/share/the-script/blocked-hosts \
		/usr/local/share/the-script/allowed-hosts /var/lib/the-script/blocklist-hosts
	sudo systemctl daemon-reload
	sudo sed -i '/^# >>> the-script blocklist/,/^# <<< the-script blocklist/d' /etc/hosts
	sudo sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' /etc/hosts
fi

# ---------------------------------------------------------------- local hostnames (mDNS)
# Avahi announces this machine as <hostname>.local, and nss-mdns lets ssh, ping, etc.
# look up other machines' .local names. Adds mdns_minimal to the hosts: line only once.
say "mDNS: .local hostnames"
if [ -e /usr/lib/libnss_mdns_minimal.so.2 ]; then
	if ! grep -q '^hosts:.*mdns' /etc/nsswitch.conf; then
		sudo cp -a /etc/nsswitch.conf "/etc/nsswitch.conf.bak-$(date +%Y%m%d-%H%M%S)"
		sudo sed -Ei '/^hosts:/s/ (resolve|files)/ mdns_minimal [NOTFOUND=return] \1/' /etc/nsswitch.conf
	fi
	sudo systemctl enable --now avahi-daemon \
		|| warn "could not start avahi; run: sudo systemctl enable --now avahi-daemon"
else
	warn "nss-mdns is not installed; skipping .local hostnames"
fi

# ---------------------------------------------------------------- printing (HP DeskJet 2800, Canon MX920)
# Each printer is reached by its mDNS name, so a new IP from the router does not break it, and is
# added only if its queue is missing. Each queue takes the name CUPS gives the discovered printer,
# which hides CUPS's own auto-made entry from print dialogs: that entry can fail (for the HP:
# 'Bad device URI "://"'), and a dialog that remembered it sent jobs nowhere.
# HP DeskJet 2800 (the default): driverless (IPP Everywhere). CUPS reads the printer's attributes
# while adding it, so it must be on; if it is off, run install.sh again once it is.
# Canon MX920: its driverless setup fails (its firmware leaves out the attributes CUPS needs, "PPD
# creation failed"), so it uses Gutenprint's driver, which needs no printer to add.
say "Printing: CUPS, the HP DeskJet 2800 and the Canon MX920"
if command -v lpadmin >/dev/null; then
	sudo systemctl enable --now cups || warn "could not start CUPS; run: sudo systemctl enable --now cups"
	# Only real queues: "lpstat -p NAME" also succeeds for a printer CUPS has merely discovered.
	has_queue() { lpstat -v 2>/dev/null | grep -q "^device for $1:"; }
	if ! has_queue HP_DeskJet_2800_series_E2CA90; then
		sudo lpadmin -p HP_DeskJet_2800_series_E2CA90 -E -v ipp://HP28C5C8E2CA90.local/ipp/print -m everywhere \
			&& lpoptions -d HP_DeskJet_2800_series_E2CA90 >/dev/null \
			|| warn "could not add the HP DeskJet 2800 (is it on and on this Wi-Fi?); run install.sh again once it is"
	fi
	if ! has_queue Canon_MX920_series; then
		sudo lpadmin -p Canon_MX920_series -E -v ipp://488E78000000.local/ipp/print -m gutenprint.5.3://bjc-MX920-series/expert \
			|| warn "could not add the MX920 printer; run the lpadmin line above by hand to see why"
	fi
else
	warn "cups is not installed; skipping the printer"
fi

# ---------------------------------------------------------------- Tailscale + ssh arch-server
say "Tailscale and ssh arch-server"
# ~/.ssh/config stays this machine's own file; the repo's host entries come in through an Include.
SSH_INCLUDE='Include ~/.ssh/config.d/*.conf'
touch "$HOME/.ssh/config" && chmod 600 "$HOME/.ssh/config"
if ! grep -qxF "$SSH_INCLUDE" "$HOME/.ssh/config"; then
	if [ -s "$HOME/.ssh/config" ]; then sed -i "1i $SSH_INCLUDE" "$HOME/.ssh/config"; else echo "$SSH_INCLUDE" > "$HOME/.ssh/config"; fi
fi
if command -v tailscale >/dev/null; then
	sudo systemctl enable --now tailscaled || warn "could not start tailscaled; run: sudo systemctl enable --now tailscaled"
	tailscale status >/dev/null 2>&1 || warn "Tailscale is not logged in yet; run once: sudo tailscale up"
fi

# ---------------------------------------------------------------- Syncthing (KeePassXC sync)
# Only the service is set up here. Device keys and the folder/device pairing live in
# ~/.local/state/syncthing and are never in this repo; pair devices at http://127.0.0.1:8384.
say "Syncthing: start now and at every login"
if command -v syncthing >/dev/null; then
	systemctl --user enable --now syncthing \
		|| warn "could not start syncthing; after logging in run: systemctl --user enable --now syncthing"
	# The todo folder (ID dwm-school) still pointed at ~/.local/share/dwm-school on machines from before
	# the rename to dwm-todo, so their todo state stopped syncing. Wait for Syncthing's API, then repoint it.
	for _ in 1 2 3 4 5 6 7 8 9 10; do folders=$(syncthing cli config folders list 2>/dev/null) && break; sleep 1; done
	if grep -qx dwm-school <<<"${folders:-}" \
		&& [ "$(syncthing cli config folders dwm-school path get)" != "$HOME/.local/share/dwm-todo" ]; then
		syncthing cli config folders dwm-school path set "$HOME/.local/share/dwm-todo" \
			|| warn "could not point Syncthing's dwm-school folder at ~/.local/share/dwm-todo"
	fi
else
	warn "syncthing is not installed; skipping"
fi

# ---------------------------------------------------------------- auto-update
# the-script-update.timer pulls this clone every 5 minutes and re-runs this installer on new commits.
say "Auto-update: pull and reinstall on new commits"
ln -sfn "$PWD" "$HOME/.local/share/the-script"
systemctl --user enable --now the-script-update.timer \
	|| warn "could not start the auto-update timer; after logging in run: systemctl --user enable --now the-script-update.timer"

# ---------------------------------------------------------------- bedtime
# Computers are off from 9:30 PM to 6:30 AM: warnings at 15, 5 and 1 minute, then a shutdown, and one
# turned on in those hours shuts down after a minute's warning.
# Not on arch-server: a server stays on.
if [ "$(cat /etc/hostname)" = arch-server ]; then
	systemctl --user disable --now bedtime.service >/dev/null 2>&1 || true
else
	say "Bedtime: computers off from 9:30 PM to 6:30 AM"
	systemctl --user enable bedtime.service >/dev/null 2>&1 || warn "could not enable bedtime.service"
	if [ -n "${WAYLAND_DISPLAY:-}" ] || systemctl --user -q is-active graphical-session.target 2>/dev/null; then
		systemctl --user restart bedtime.service || warn "could not start bedtime; run: systemctl --user restart bedtime"
	fi
fi

# presence told arch-server when this computer was in use, for working out a sleep schedule. Done now.
systemctl --user disable --now presence.service >/dev/null 2>&1 || true
retire "$HOME/.local/bin/presence" "$HOME/.config/systemd/user/presence.service"
rm -rf "$HOME/.local/state/presence"
if pacman -Qq swayidle >/dev/null 2>&1; then   # only presence used it
	sudo pacman -Rs --noconfirm swayidle >/dev/null || warn "could not remove swayidle; run: sudo pacman -Rs swayidle"
fi

# ---------------------------------------------------------------- history cleaner
# Deletes porn sites from LibreWolf's history, cookies and closed tabs each time it closes (it
# locks its files while open), and at login. Nothing is blocked.
say "History cleaner: porn sites removed from LibreWolf's history when it closes"
systemctl --user enable history-cleaner.service >/dev/null 2>&1 || warn "could not enable history-cleaner.service"
if [ -n "${WAYLAND_DISPLAY:-}" ] || systemctl --user -q is-active graphical-session.target 2>/dev/null; then
	systemctl --user restart history-cleaner.service || warn "could not start history-cleaner; run: systemctl --user restart history-cleaner"
fi

# ---------------------------------------------------------------- cc-bench (Claude Code)
# Benchmarks which Claude Code model + effort works best: `ccb` starts sessions on rotating settings,
# the status line records plan-limit use, and cc-bench.timer grades finished sessions with Haiku
# (see ~/.local/bin/ccbench). Only where Claude Code is installed. The status line and SessionStart
# hook are merged into ~/.claude/settings.json; a status line you set yourself is left alone.
if [ -x "$HOME/.local/bin/claude" ] || command -v claude >/dev/null; then
	say "cc-bench: Claude Code model/effort benchmark"
	mkdir -p "$HOME/.claude"
	python3 - "$HOME/.claude/settings.json" <<'EOF' || warn "could not add cc-bench to ~/.claude/settings.json"
import json, os, sys
p = sys.argv[1]
d = json.load(open(p)) if os.path.exists(p) else {}
before = json.dumps(d, sort_keys=True)
sl = d.get("statusLine")
if not sl or "ccbench" in sl.get("command", ""):
    d["statusLine"] = {"type": "command", "command": "ccbench statusline", "padding": 0}
hooks = d.setdefault("hooks", {}).setdefault("SessionStart", [])
if not any("ccbench" in h.get("command", "") for e in hooks for h in e.get("hooks", [])):
    hooks.append({"hooks": [{"type": "command", "command": "ccbench hook-session-start", "timeout": 5}]})
if json.dumps(d, sort_keys=True) != before:
    with open(p + ".tmp", "w") as f:
        json.dump(d, f, indent=2)
        f.write("\n")
    os.replace(p + ".tmp", p)
    print("Added the cc-bench status line and hook to " + p)
EOF
	systemctl --user enable --now cc-bench.timer >/dev/null 2>&1 \
		|| warn "could not start cc-bench.timer; run: systemctl --user enable --now cc-bench.timer"
fi

# ---------------------------------------------------------------- Steam overlay scale
# Steam's in-game overlay ignores the display scale (tiny at 4K); steam-overlay-scale fixes that at
# login, and the .path unit re-applies it whenever a Steam update replaces the patched library.
say "Steam overlay: follow the display scale"
systemctl --user enable --now steam-overlay-scale.path \
	|| warn "could not start steam-overlay-scale.path; after logging in run: systemctl --user enable --now steam-overlay-scale.path"
if [ "${XDG_CURRENT_DESKTOP:-}" = GNOME ]; then   # the scale can only be read inside GNOME
	"$HOME/.local/bin/steam-overlay-scale" || warn "could not patch Steam's overlay scale; run steam-overlay-scale to see why"
fi

# ---------------------------------------------------------------- OBS replay buffer (removed)
# Desktops used to start OBS hidden at login with a replay buffer, saved by Alt+F10 (obs-clip). That
# is gone: its autostart, shortcut and script are retired, and a running replay OBS is closed. OBS
# itself and its settings stay.
retire "$HOME/.config/autostart/obs-replay.desktop" "$HOME/.local/share/applications/obs-clip.desktop" "$HOME/.local/bin/obs-clip"
pkill -f '^/usr/bin/obs --profile Discord --collection Discord --startreplaybuffer' 2>/dev/null || true

# ---------------------------------------------------------------- git identity
# GitHub noreply address, so commits work and push without exposing an email.
say "git: commit name and email"
git config --global user.name 5TN1rcZRS79VAEFuUCRB
git config --global user.email 327155685+5TN1rcZRS79VAEFuUCRB@users.noreply.github.com

# ---------------------------------------------------------------- Steam (optional)
if [ "$WITH_STEAM" -eq 1 ]; then
	say "Steam"
	if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
		warn "[multilib] is not enabled in /etc/pacman.conf. Uncomment the [multilib] section"
		warn "(and its Include line), run 'sudo pacman -Sy', then rerun with --steam."
	else
		gpu="$(lspci 2>/dev/null | grep -Ei 'vga|3d' || true)"
		libs=()
		case "$gpu" in
		*[Nn][Vv][Ii][Dd][Ii][Aa]*) libs+=(lib32-nvidia-utils) ;;
		*AMD*|*ATI*|*Radeon*)      libs+=(lib32-vulkan-radeon) ;;
		*Intel*)                   libs+=(lib32-vulkan-intel) ;;
		esac
		[ ${#libs[@]} -gt 0 ] || warn "unrecognised GPU; you may be asked to pick a 32-bit Vulkan driver"
		sudo pacman -S --needed --noconfirm "${libs[@]}" steam
	fi
fi

# ---------------------------------------------------------------- done
say "Done"
# the-script-update compares this with the pulled commit to know whether to install again.
mkdir -p "$HOME/.local/state"
git rev-parse HEAD > "$HOME/.local/state/the-script-installed"
# Hand edits to these files are gone from the live copies; copy back into the repo any worth keeping.
if [ ${#REPLACED[@]} -gt 0 ]; then
	warn "these files differed from the repo and were replaced or removed (old copies in $BACKUP):"
	printf '  ~/%s\n' "${REPLACED[@]}" >&2
fi
# Installed by the-script-update from an older desktop: say that a restart switches over.
if { [ "$MIGRATED" -eq 1 ] || [ "$AERO" -eq 1 ] || [ -e "$HYPR_PENDING" ] || [ -e "$KDE_PENDING" ] || [ -e "$LXQT_PENDING" ]; } \
	&& [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ "${XDG_CURRENT_DESKTOP:-}" != GNOME ]; then
	notify-send -u critical "the-script is installed" "Restart to switch to GNOME." 2>/dev/null || true
fi
cat <<EOF

Next steps:
  1. Restart. GDM (GNOME's login screen) comes up; log in and you are in GNOME. Coming from Hyprland,
     LXQt or Plasma, the first login removes it in the background (a notification says if that fails).
  2. Tap Super for the overview (type to search, every open window), Alt+Tab to switch windows,
     Super+T the to-do list. Drag a window to the top edge to maximize it, to a side for half the screen.
  3. NVIDIA card? Install the driver yourself first (e.g. 'sudo pacman -S nvidia-open'),
     since the right package depends on your GPU and kernel. It is not part of this repo.
  4. Display scale: games see the screen's real pixels only at 100% or 200% (Settings > Displays);
     make text bigger in Settings > Accessibility > Large Text instead of 125%/150%.
EOF
