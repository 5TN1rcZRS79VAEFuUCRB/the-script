#!/usr/bin/env bash
#
# the-script: recreates this KDE Plasma desktop on an Arch Linux machine. Run as your normal user (it
# calls sudo where it needs root):  ./install.sh
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
# niri itself and the packages only its session used, so Plasma is the one session left at the login
# screen. Not while a niri session is running.
NIRI_PKGS=(niri xwayland-satellite waybar dunst bemenu-wayland bemenu)
mapfile -t NIRI_HAVE < <(pacman -Qq "${NIRI_PKGS[@]}" 2>/dev/null || true)
if [ ${#NIRI_HAVE[@]} -gt 0 ] && ! pgrep -x niri >/dev/null; then
	say "Removing niri"
	sudo pacman -Rs --noconfirm "${NIRI_HAVE[@]}" || warn "could not remove niri; run: sudo pacman -Rs ${NIRI_HAVE[*]}"
fi

# ---------------------------------------------------------------- leftovers from AeroThemePlasma
# the-script was a Windows 7-style KDE Plasma desktop (AeroThemePlasma) before GNOME, and is plain Plasma
# now. A machine that never left the Windows 7 desktop loses its add-ons here; Plasma itself stays.
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
	# Plasma's own look comes back at the next login (the-script-plasma).
	kwriteconfig6 --file kdeglobals --group KDE --key DefaultLightLookAndFeel --delete 2>/dev/null || true
	kwriteconfig6 --file kdeglobals --group KDE --key DefaultDarkLookAndFeel --delete 2>/dev/null || true
	if printf '%s\n' "${AERO_HAVE[@]}" | grep -qx aeroshell-libplasma-git; then
		sudo pacman -S --noconfirm --ask=4 libplasma || warn "could not put libplasma back in place of aeroshell-libplasma-git"
	fi
	mapfile -t AERO_HAVE < <(pacman -Qq "${AERO_PKGS[@]}" 2>/dev/null || true)
	if [ ${#AERO_HAVE[@]} -gt 0 ] && ! sudo pacman -Rs --noconfirm "${AERO_HAVE[@]}"; then
		warn "could not remove AeroThemePlasma; run: sudo pacman -Rs ${AERO_HAVE[*]}"
	fi
fi

# ---------------------------------------------------------------- leftovers from GNOME
# the-script was GNOME before it went back to Plasma. Its scripts, extensions and the ThinkPad look are
# retired now (a running GNOME keeps what it loaded until you log out). Removing GNOME itself with GNOME
# running would pull the session out from under you, so that waits for a run from Plasma:
# the-script-plasma starts one at the first Plasma login. GNOME's own settings (dconf) stay, unused.
retire "$HOME/.local/bin/the-script-gnome" "$HOME/.config/autostart/the-script-gnome.desktop" \
	"$HOME"/.local/share/gnome-shell/extensions/{todo,volume-percent}@the-script \
	"$HOME/.local/share/dbus-1/services/org.gnome.Settings.service" \
	"$HOME"/.local/share/applications/{org.keepassxc.KeePassXC,com.obsproject.Studio}.desktop \
	"$HOME"/.local/share/backgrounds/{arch.svg,thinkpad.svg,thinkpad-20-dark.png,thinkpad-20-light.png}
rm -rf "$HOME/.local/share/icons/Adwaita-ThinkPad"   # made by install.sh, not yours
# Only the ThinkPad gtk.css: Plasma writes its own there (@import 'colors.css') for GTK apps' colors.
for f in "$HOME"/.config/gtk-{3,4}.0/gtk.css; do
	grep -q 'ThinkPad' "$f" 2>/dev/null && retire "$f"
done
rm -f "$HOME"/.local/state/the-script-{gnome-first-run,gnome-librewolf-dash,gnome-app-folders,gnome-app-folders-3,kde-pending}
sudo rm -f /usr/local/libexec/settings-pointer-speed /etc/udev/rules.d/{70-mouse-dpi,70-dwm-mouse-dpi}.rules
# display-wake brought a DisplayPort monitor's picture back after a long GNOME sleep; niri and Plasma
# never needed it.
systemctl --user disable --now display-wake.service >/dev/null 2>&1 || true
retire "$HOME/.local/bin/display-wake" "$HOME/.config/systemd/user/display-wake.service"

GNOME_PKGS=(gnome-shell gdm gnome-control-center gnome-bluetooth-3.0 gnome-shell-extension-appindicator
	xdg-desktop-portal-gnome nautilus loupe gnome-text-editor gnome-console)
mapfile -t GNOME_HAVE < <(pacman -Qq "${GNOME_PKGS[@]}" 2>/dev/null || true)
GNOME_PENDING="$HOME/.local/state/the-script-remove-gnome"
if [ ${#GNOME_HAVE[@]} -gt 0 ] && pgrep -x gnome-shell >/dev/null; then
	say "GNOME is running: it is removed after you log into Plasma"
	mkdir -p "${GNOME_PENDING%/*}" && touch "$GNOME_PENDING"
elif [ ${#GNOME_HAVE[@]} -gt 0 ]; then
	say "Removing GNOME"
	# What packages.txt lists stays even where GNOME pulled it in first.
	mapfile -t keep < <(pacman -Qq $(listed packages.txt) 2>/dev/null || true)
	[ ${#keep[@]} -eq 0 ] || sudo pacman -D -q --asexplicit "${keep[@]}" >/dev/null
	rm -f "$GNOME_PENDING"   # not retried at every login; the notification says how
	if ! sudo pacman -Rs --noconfirm "${GNOME_HAVE[@]}"; then
		warn "could not remove GNOME; run: sudo pacman -Rs ${GNOME_HAVE[*]}"
		notify-send -u critical "the-script: GNOME was not removed" "Run: sudo pacman -Rs ${GNOME_HAVE[*]}" 2>/dev/null || true
	fi
fi

# foot was the terminal before Console and Konsole; its settings are retired. The package stays until you
# remove it (sudo pacman -Rs foot), as a terminal may still be running in it.
retire "$HOME/.config/foot/foot.ini"

# ---------------------------------------------------------------- dotfiles + scripts
say "Installing config files and scripts into $HOME"
while IFS= read -r -d '' f; do
	place "$f" "$HOME/${f#home/}"
done < <(find home -type f -print0)
systemctl --user daemon-reload 2>/dev/null || true
# The Adwaita cursors Plasma can list (~/.icons/Adwaita-cursors/index.theme says why).
ln -sfn /usr/share/icons/Adwaita/cursors "$HOME/.icons/Adwaita-cursors/cursors"

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

# ---------------------------------------------------------------- Plasma
# The settings that need a running session (Breeze Dark, the todo widget on the taskbar) are in
# the-script-plasma, run at every login.

# Black hole wallpapers the-script set for a few minutes.
rm -f "$HOME"/.local/share/wallpapers/{black-hole,nasa-black-hole}.png

say "Plasma: settings and the login screen"
if command -v plasmashell >/dev/null && pgrep -x plasmashell >/dev/null; then
	"$HOME/.local/bin/the-script-plasma" || warn "could not apply the Plasma settings; they apply at the next login"
fi
# SDDM takes over at the next boot; a running session is left alone. --force replaces the
# display-manager link another one (GDM) holds.
if ! systemctl is-enabled -q sddm 2>/dev/null; then
	sudo systemctl enable --force sddm || warn "could not enable SDDM; run: sudo systemctl enable --force sddm"
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
		place librewolf/userChrome.css "$LW_PROFILE/chrome/userChrome.css"
		echo "Installed user.js and userChrome.css into $LW_PROFILE (restart LibreWolf to apply)"
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
# On a text console (Ctrl+Alt+F2) nothing turns the monitors off. The udev rule keeps
# them off when a DisplayPort monitor's hotplug on going to sleep lights the console again.
say "Console: monitors off after 10 minutes idle"
sudo_place etc/systemd/system/console-blank.service /etc/systemd/system/console-blank.service
sudo_place usr/local/libexec/console-reblank /usr/local/libexec/console-reblank
sudo_place etc/udev/rules.d/90-console-reblank.rules /etc/udev/rules.d/90-console-reblank.rules
sudo udevadm control --reload || warn "could not reload udev rules; they take effect after a reboot"
sudo systemctl daemon-reload
sudo systemctl enable console-blank.service >/dev/null 2>&1 || warn "could not enable console-blank.service"
sudo systemctl restart console-blank.service || warn "could not start console-blank.service; it runs at the next boot"

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

# ---------------------------------------------------------------- printing (Canon MX920)
# The MX920's driverless (IPP Everywhere) setup fails: its firmware leaves out the attributes CUPS
# needs ("PPD creation failed"), so the queue uses Gutenprint's driver instead. The printer is reached
# by its mDNS name, so a new IP from the router does not break it. Added only if the queue is missing.
# The queue takes the name CUPS gives the discovered printer, which hides that broken driverless
# entry from print dialogs (Firefox had remembered it, so its jobs went nowhere).
say "Printing: CUPS and the Canon MX920"
if command -v lpadmin >/dev/null; then
	sudo systemctl enable --now cups || warn "could not start CUPS; run: sudo systemctl enable --now cups"
	if ! lpstat -p Canon_MX920_series >/dev/null 2>&1; then
		sudo lpadmin -p Canon_MX920_series -E -v ipp://488E78000000.local/ipp/print -m gutenprint.5.3://bjc-MX920-series/expert \
			&& lpoptions -d Canon_MX920_series >/dev/null \
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

# ---------------------------------------------------------------- presence
# Tells arch-server once a minute whether this computer is in use; its presence-collector works out
# your bed and wake times from that (run there: presence-collector report).
say "Presence: report when this computer is in use to arch-server"
systemctl --user enable presence.service >/dev/null 2>&1 || warn "could not enable presence.service"
if [ "${XDG_CURRENT_DESKTOP:-}" = KDE ] || systemctl --user -q is-active graphical-session.target 2>/dev/null; then
	systemctl --user restart presence.service || warn "could not start presence; run: systemctl --user restart presence"
fi

# ---------------------------------------------------------------- Steam overlay scale
# Steam's in-game overlay ignores the display scale (tiny at 4K); steam-overlay-scale fixes that at
# login, and the .path unit re-applies it whenever a Steam update replaces the patched library.
say "Steam overlay: follow the display scale"
systemctl --user enable --now steam-overlay-scale.path \
	|| warn "could not start steam-overlay-scale.path; after logging in run: systemctl --user enable --now steam-overlay-scale.path"
if [ "${XDG_CURRENT_DESKTOP:-}" = KDE ]; then   # the scale can only be read inside the desktop
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
if { [ "$MIGRATED" -eq 1 ] || [ "$AERO" -eq 1 ] || [ -e "$GNOME_PENDING" ]; } && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
	notify-send -u critical "the-script is installed" "Restart to switch to KDE Plasma." 2>/dev/null || true
fi
cat <<EOF

Next steps:
  1. Restart. SDDM comes up; log in and you are in KDE Plasma. Coming from GNOME, the first login
     also removes GNOME in the background (a notification says if it fails).
  2. Meta opens the launcher, Meta+T the to-do list. See README.md.
  3. NVIDIA card? Install the driver yourself first (e.g. 'sudo pacman -S nvidia-open'),
     since the right package depends on your GPU and kernel. It is not part of this repo.
  4. Display too big/small? System Settings > Display & Monitor > Scale.
EOF
