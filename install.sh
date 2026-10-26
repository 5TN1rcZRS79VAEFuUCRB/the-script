#!/usr/bin/env bash
#
# the-script: recreates this Windows 7-style KDE Plasma desktop (AeroThemePlasma) on an Arch Linux
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
  --no-packages   skip the pacman and AUR steps
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
	cmp -s "$1" "$2" 2>/dev/null && return
	[ -e "$2" ] && sudo cp -a "$2" "$2.bak-$(date +%Y%m%d-%H%M%S)"
	sudo install -Dm644 "$1" "$2"
	echo "Installed $2"
}

kset() { kwriteconfig6 "$@"; }

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

	# AeroThemePlasma from the AUR, built with yay (installed first if missing). Building takes a while
	# the first time. aeroshell-libplasma-git replaces libplasma, and pacman's question about that
	# defaults to no under --noconfirm, so the answers come from `yes` instead.
	mapfile -t AUR < <(listed aur.txt)
	mapfile -t MISSING < <(pacman -T "${AUR[@]}" || true)
	if [ ${#MISSING[@]} -gt 0 ]; then
		say "Building AeroThemePlasma from the AUR: ${MISSING[*]}"
		if ! command -v yay >/dev/null; then
			tmp="$(mktemp -d)"
			git clone -q https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
			(cd "$tmp/yay-bin" && makepkg -si --noconfirm)
			rm -rf "$tmp"
		fi
		(set +o pipefail; yes y | yay -S --needed --answerclean All --answerdiff None --answeredit None --removemake "${MISSING[@]}")
		mapfile -t MISSING < <(pacman -T "${AUR[@]}" || true)
		[ ${#MISSING[@]} -eq 0 ] || die "these AUR packages did not install: ${MISSING[*]} (run: yay -S ${MISSING[*]})"
	fi
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
	retire "$HOME"/.config/systemd/user/niri-{update.service,update.timer,steam-overlay.path,steam-overlay.service}
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
# From trying Plasma before the-script: the todo widget and daemon under their old names.
retire "$HOME/.local/share/plasma/plasmoids/local.niritodo" "$HOME/.config/autostart/niri-todo.desktop"
# A generic portals.conf choosing GTK's portal (niri's) would override KDE's under Plasma too, and apps
# would then miss Plasma's dark mode.
if grep -qsx 'default=gtk' "$HOME/.config/xdg-desktop-portal/portals.conf"; then
	retire "$HOME/.config/xdg-desktop-portal/portals.conf"
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

# ---------------------------------------------------------------- Windows 7 look (AeroThemePlasma)
# What AeroThemePlasma's first-run wizard would set, plus fixes found while trying it. Settings that
# need a running session (theme, wallpaper, the Windows key, the todo widget) are applied at login by
# the-script-plasma.
say "Windows 7 look: effects, theme variants, icons, wallpaper"
if [ -d /usr/share/plasma/look-and-feel/authui7 ]; then
	# Effects. KDE's own blur runs next to ATP's glass blur (a fork of it) and makes it flicker.
	for e in aeroglassblur aeroglide dimscreenaero libkwin_effect_smodsnap smodglow smodpeekeffect; do
		kset --file kwinrc --group Plugins --key "${e}Enabled" true
	done
	for e in blur dialogparent fadingpopups login logout maximize scale squash windowaperture; do
		kset --file kwinrc --group Plugins --key "${e}Enabled" false
	done
	for k in font menuFont toolBarFont; do
		kset --file kdeglobals --group General --key "$k" "Segoe UI,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0"
	done
	kset --file kdeglobals --group General --key smallestReadableFont "Segoe UI,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0"

	# A dark variant of the Windows 7 theme: the shell stays Windows 7 light, apps go dark (and the
	# portal tells Firefox and Electron apps so). The tray's light/dark switch flips between the two.
	# Copies, not links: Plasma refuses packages that link outside themselves. Remade on every run so
	# they follow ATP updates.
	lnf="$HOME/.local/share/plasma/look-and-feel/authui7-dark"
	rm -rf "$lnf" && cp -r /usr/share/plasma/look-and-feel/authui7 "$lnf"
	sed -i -e 's/"Id": "authui7"/"Id": "authui7-dark"/' -e 's/"Name": "Windows 7 style"/"Name": "Windows 7 style (dark)"/' "$lnf/metadata.json"
	sed -i -e 's/^ColorScheme=Aero$/ColorScheme=KvArcDark/' -e 's/^widgetStyle=kvantum$/widgetStyle=kvantum-dark/' "$lnf/contents/defaults"
	# kvantum-dark loads the Kvantum theme "<theme>Dark": Windows7AeroDark, made from KvArcDark.
	kv="$HOME/.config/Kvantum/Windows7AeroDark"
	mkdir -p "$kv"
	cp /usr/share/Kvantum/KvArcDark/KvArcDark.kvconfig "$kv/Windows7AeroDark.kvconfig"
	cp /usr/share/Kvantum/KvArcDark/KvArcDark.svg "$kv/Windows7AeroDark.svg"
	# Context menus stay Windows 7 (light, blue hover) like the shell: Windows7Aero's menu elements and
	# the gradients they use are copied into the dark theme's SVG as w7*, and [Menu] / [MenuItem] point
	# at them.
	python3 - /usr/share/Kvantum/Windows7Aero "$kv/Windows7AeroDark.kvconfig" "$kv/Windows7AeroDark.svg" <<-'EOF' \
		|| warn "could not give the dark theme Windows 7 menus; they stay dark"
	import copy, re, sys
	import xml.etree.ElementTree as ET

	w7dir, kv, svg = sys.argv[1:4]
	SVG, XL = "http://www.w3.org/2000/svg", "http://www.w3.org/1999/xlink"
	for p, u in {"": SVG, "xlink": XL, "inkscape": "http://www.inkscape.org/namespaces/inkscape",
	             "sodipodi": "http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"}.items():
	    ET.register_namespace(p, u)
	src = ET.parse(f"{w7dir}/Windows7Aero.svg").getroot()
	dst_tree = ET.parse(svg)
	dst = dst_tree.getroot()
	byid = {e.get("id"): e for e in src.iter() if e.get("id")}
	parent = {c: p for p in src.iter() for c in p}
	REF = re.compile(r"url\(#([^)]+)\)")
	HREF = f"{{{XL}}}href"

	# Menu frame, menu items (hover, submenu arrows, separators), and checkboxes/radios as menu-*.
	rename = {}
	for i in byid:
	    if re.match(r"(mnu|menuitem|arrow)-", i):   # Kvantum draws menu separators as <indicator>-separator
	        rename[i] = "w7" + i
	    elif re.match(r"(checkbox|radio)-", i):
	        rename[i] = "menu-" + i
	assert any(k.startswith("mnu-") for k in rename), "Windows7Aero.svg has no menu elements"


	def refs(e):
	    out = set()
	    for n in e.iter():
	        for k, v in n.attrib.items():
	            out.update(REF.findall(v))
	            if k == HREF and v.startswith("#"):
	                out.add(v[1:])
	    return out


	# Gradients and other defs the copied elements use, followed through href chains.
	need, todo = set(), set().union(*(refs(byid[i]) for i in rename))
	while todo:
	    i = todo.pop()
	    if i in need or i not in byid:
	        continue
	    need.add(i)
	    todo |= refs(byid[i])


	def fix(e):
	    for n in e.iter():
	        if n.get("id"):
	            n.set("id", rename.get(n.get("id"), "w7-" + n.get("id")))
	        for k, v in list(n.attrib.items()):
	            v = REF.sub(lambda m: f"url(#w7-{m.group(1)})", v)
	            if k == HREF and v.startswith("#"):
	                v = "#w7-" + v[1:]
	            n.set(k, v)
	    return e


	# Elements whose renamed id the dark theme already has (its menu-checkbox-*) are replaced.
	gone = set(rename.values())
	for p in list(dst.iter()):
	    for c in list(p):
	        if c.get("id") in gone:
	            p.remove(c)
	defs = ET.SubElement(dst, f"{{{SVG}}}defs")
	for i in need:
	    defs.append(fix(copy.deepcopy(byid[i])))
	for i in rename:
	    e = byid[i]
	    # Keep the transforms of the layers the element sits in.
	    t, p = [], parent.get(e)
	    while p is not None and p is not src:
	        if p.get("transform"):
	            t.insert(0, p.get("transform"))
	        p = parent.get(p)
	    g = ET.SubElement(dst, f"{{{SVG}}}g", {"transform": " ".join(t)} if t else {})
	    g.append(fix(copy.deepcopy(e)))
	dst_tree.write(svg, xml_declaration=True, encoding="UTF-8")

	# Config: Windows7Aero's [Menu] and [MenuItem] sections and menu settings, on the new elements.
	def sections(text):
	    out, name = {}, None
	    for line in text.splitlines():
	        m = re.match(r"\[(.+)\]$", line)
	        if m:
	            name = m.group(1)
	            out.setdefault(name, [])
	        elif name and line.strip():
	            out[name].append(line)
	    return out


	w7 = sections(open(f"{w7dir}/Windows7Aero.kvconfig").read())
	text = open(kv).read()
	el = {"mnu": "w7mnu", "menuitem": "w7menuitem", "arrow": "w7arrow"}
	for name, extra in (("Menu", ["text.normal.color=black"]), ("MenuItem", [])):
	    lines = [re.sub(r"(element)=(\w+)$", lambda m: f"{m.group(1)}={el.get(m.group(2), m.group(2))}", l)
	             for l in w7[name]] + extra
	    text, n = re.subn(rf"(?ms)^\[{name}\]\n.*?(?=^\[|\Z)", f"[{name}]\n" + "\n".join(lines) + "\n\n", text)
	    assert n == 1, name
	general = dict(l.split("=", 1) for l in w7["%General"] if "=" in l)
	for k in ("menu_shadow_depth", "submenu_overlap", "menu_separator_height", "menu_blur_radius",
	          "reduce_menu_opacity", "scrollable_menu", "submenu_delay"):
	    if k in general:
	        text, n = re.subn(rf"(?m)^{k}=.*$", f"{k}={general[k]}", text)
	        if not n:
	            text = text.replace("[%General]\n", f"[%General]\n{k}={general[k]}\n", 1)
	open(kv, "w").write(text)
	EOF
	kset --file Kvantum/kvantum.kvconfig --group General --key theme Windows7Aero
	kset --file kdeglobals --group KDE --key DefaultLightLookAndFeel authui7
	kset --file kdeglobals --group KDE --key DefaultDarkLookAndFeel authui7-dark
	kset --file kdeglobals --group KDE --key AutomaticLookAndFeel false

	# Pinned taskbar apps stay where they are when opened: the taskbar hard-codes separateLaunchers
	# off, and Plasma only keeps launchers in place with it on.
	tasks="$HOME/.local/share/plasma/plasmoids/io.gitgud.wackyideas.seventasks"
	rm -rf "$tasks" && cp -r /usr/share/plasma/plasmoids/io.gitgud.wackyideas.seventasks "$tasks"
	sed -i 's/separateLaunchers: false/separateLaunchers: true/' "$tasks/contents/ui/main.qml"
	grep -q 'separateLaunchers: true' "$tasks/contents/ui/main.qml" \
		|| warn "the taskbar changed; pinned apps may jump to the end when opened"

	# Windows 7-era icons for apps the theme has none for, layered over it. The Firefox logo is the
	# 2009 one; Element gets Windows Live Messenger's. Others keep their own logos.
	icons="$HOME/.local/share/icons/Windows 7 Aero"
	theme="/usr/share/icons/Windows 7 Aero"
	mkdir -p "$icons/apps"/{16,32,48,256}
	ln -sfn "$theme/index.theme" "$icons/index.theme"
	link_icon() { # app icon name, Windows 7 icon
		local s p
		for s in 16 32 48 256; do
			p=$(find "$theme" -path "*/$s/$2.png" -print -quit)
			[ -n "$p" ] || p=$(find "$theme" -name "$2.png" | sort -V | tail -n1)
			[ -n "$p" ] && ln -sfn "$p" "$icons/apps/$s/$1.png"
		done
	}
	link_icon foot utilities-terminal
	link_icon org.gnome.Nautilus system-file-manager
	link_icon mpv multimedia-video-player
	link_icon nvidia-settings preferences-desktop-display
	link_icon kvantum preferences-desktop-theme
	link_icon kmenuedit application-menu
	link_icon preferences-desktop-emoticons accessories-character-map
	link_icon java21-openjdk application-x-java
	link_icon java25-openjdk application-x-java
	link_icon hwloc utilities-system-monitor
	link_icon qv4l2 camera-web
	link_icon qvidcap camera-video
	link_icon assistant help-browser
	for n in io.element.Element element Element; do   # only drawn at 16 and 32 px
		for s in 16 32; do ln -sfn "$theme/actions/32/im-msn.png" "$icons/apps/$s/$n.png"; done
	done
	# Element's window and tray icon come from its own file instead; the hook redoes this on updates.
	sudo_place etc/pacman.d/hooks/element-msn-icon.hook /etc/pacman.d/hooks/element-msn-icon.hook
	if [ -d /usr/lib/element/build ] && ! cmp -s "$theme/actions/32/im-msn.png" /usr/lib/element/build/icon.png; then
		sudo cp "$theme/actions/32/im-msn.png" /usr/lib/element/build/icon.png
	fi
	if [ ! -e "$icons/apps/256/firefox.png" ]; then
		tmp="$(mktemp)"
		if curl -fsSL -A "the-script" -o "$tmp" https://commons.wikimedia.org/wiki/Special:FilePath/Mozilla_Firefox_3.5_logo.png; then
			for s in 16 32 48 256; do
				ffmpeg -loglevel error -y -i "$tmp" -vf "scale=$s:$s:flags=lanczos" "$icons/apps/$s/firefox.png" \
					|| warn "could not scale the Firefox logo (is ffmpeg installed?)"
			done
		else
			warn "could not download the 2009 Firefox logo; Firefox keeps its own icon"
		fi
		rm -f "$tmp"
	fi
	rm -f "$HOME/.cache/icon-cache.kcache"

	# Wallpaper: Windows 7's own "Harmony" (img0), applied at the first login.
	wp="$HOME/.local/share/wallpapers/windows7-harmony.jpg"
	if [ ! -e "$wp" ]; then
		mkdir -p "${wp%/*}"
		curl -fsSL -o "$wp.tmp" "https://archive.org/download/Windows-wallcollection/Img0_(Windows_7).jpg" \
			&& mv "$wp.tmp" "$wp" || { rm -f "$wp.tmp"; warn "could not download the Windows 7 wallpaper"; }
	fi

	# Dolphin is the file manager, and stays light like Explorer while other apps are dark.
	kset --file kde-mimeapps.list --group "Default Applications" --key inode/directory "org.kde.dolphin.desktop;"
	kset --file dolphinrc --group KDE --key widgetStyle kvantum
	kset --file dolphinrc --group UiSettings --key ColorScheme Aero
	# Open/save dialogs of other apps (KDE's portal) match Dolphin, not the dark apps.
	kset --file xdg-desktop-portal-kderc --group KDE --key widgetStyle kvantum
	kset --file xdg-desktop-portal-kderc --group UiSettings --key ColorScheme Aero

	# A running KWin picks up the effect changes now; otherwise they apply at the next login.
	qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
else
	warn "AeroThemePlasma is not installed; skipping the Windows 7 look (rerun without --no-packages)"
fi

# The Windows 7 logon screen. SDDM starts at the next boot; until then nothing changes.
say "Login: SDDM with the Windows 7 logon screen"
sudo_place etc/sddm.conf.d/10-win7.conf /etc/sddm.conf.d/10-win7.conf
if ! systemctl is-enabled -q sddm 2>/dev/null; then
	sudo systemctl enable sddm || warn "could not enable SDDM; run: sudo systemctl enable sddm"
fi

# ---------------------------------------------------------------- Firefox
find_ff_profile() {
	local base d
	for base in "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox"; do
		for d in "$base"/*.default-release; do
			[ -d "$d" ] && { printf '%s\n' "$d"; return 0; }
		done
	done
	return 1
}

say "Firefox settings"
if command -v firefox >/dev/null; then
	FF_PROFILE="$(find_ff_profile || true)"
	if [ -z "$FF_PROFILE" ]; then
		echo "No Firefox profile yet; starting Firefox headless once to create it..."
		timeout 20 firefox --headless --no-remote about:blank >/dev/null 2>&1 || true
		FF_PROFILE="$(find_ff_profile || true)"
	fi
	if [ -n "$FF_PROFILE" ]; then
		place firefox/user.js "$FF_PROFILE/user.js"
		echo "Installed user.js into $FF_PROFILE (restart Firefox to apply)"
	else
		warn "could not find/create a Firefox profile. Start Firefox once, close it, then run:"
		warn "  ./install.sh --no-packages"
	fi
	# Extensions (uBlock Origin, Violentmonkey) come from a system-wide Firefox policy, so they are
	# installed automatically the next time Firefox starts. Needs root because it lives in /etc.
	# The Always-visible userscript ships in this repo, but Violentmonkey keeps its scripts in its
	# own storage, which a policy cannot seed, so it is imported by hand once (see the line printed).
	sudo_place firefox/policies.json /etc/firefox/policies/policies.json
	# Links opened from other programs (todo, chat apps) go to Firefox, not another installed browser.
	{ xdg-settings set default-web-browser firefox.desktop && xdg-mime default firefox.desktop text/html; } \
		|| warn "could not make Firefox the default browser; run: xdg-settings set default-web-browser firefox.desktop"
	echo "Violentmonkey will auto-install; import the userscript once by opening this in Firefox:"
	echo "  file://$PWD/firefox/always-visible.user.js   (Violentmonkey shows an install page)"
else
	warn "firefox is not installed; skipping its settings"
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
else
	warn "syncthing is not installed; skipping"
fi

# ---------------------------------------------------------------- auto-update
# the-script-update.timer pulls this clone every 5 minutes and re-runs this installer on new commits.
say "Auto-update: pull and reinstall on new commits"
ln -sfn "$PWD" "$HOME/.local/share/the-script"
systemctl --user enable --now the-script-update.timer \
	|| warn "could not start the auto-update timer; after logging in run: systemctl --user enable --now the-script-update.timer"

# ---------------------------------------------------------------- Steam overlay scale
# Steam's in-game overlay ignores the display scale (tiny at 4K); steam-overlay-scale fixes that at
# login, and the .path unit re-applies it whenever a Steam update replaces the patched library.
say "Steam overlay: follow the display scale"
systemctl --user enable --now steam-overlay-scale.path \
	|| warn "could not start steam-overlay-scale.path; after logging in run: systemctl --user enable --now steam-overlay-scale.path"
if [ -n "${WAYLAND_DISPLAY:-}" ]; then   # the scale can only be read inside the desktop
	"$HOME/.local/bin/steam-overlay-scale" || warn "could not patch Steam's overlay scale; run steam-overlay-scale to see why"
fi

# ---------------------------------------------------------------- OBS replay buffer (removed)
# Desktops used to start OBS hidden at login with a replay buffer, saved by Alt+F10 (obs-clip). That
# is gone: its autostart, shortcut and script are retired, and a running replay OBS is closed. OBS
# itself and its settings stay.
retire "$HOME/.config/autostart/obs-replay.desktop" "$HOME/.local/share/applications/obs-clip.desktop" "$HOME/.local/bin/obs-clip"
kset --file kglobalshortcutsrc --group services --group obs-clip.desktop --key _launch --delete
pkill -f '^/usr/bin/obs --profile Discord --collection Discord --startreplaybuffer' 2>/dev/null || true

# ---------------------------------------------------------------- git identity
# GitHub noreply address, so commits work and push without exposing an email.
say "git: commit name and email"
git config --global user.name 5TN1rcZRS79VAEFuUCRB
git config --global user.email 327155685+5TN1rcZRS79VAEFuUCRB@users.noreply.github.com

# ---------------------------------------------------------------- Claude Code add-ons
# ponytail + caveman plugins and caveman's hooks. `caveman enable claude` also routes Claude
# Code through its local proxy (ANTHROPIC_BASE_URL), which turns off Remote Control, so that
# route is taken back out and Claude Code talks to api.anthropic.com directly. Enable runs only
# while its hooks are missing: without the route it calls the setup degraded and exits 1. Undo: caveman disable claude
say "Claude Code: ponytail and caveman plugins, caveman hooks"
if command -v claude >/dev/null; then
	{
		claude plugin marketplace add DietrichGebert/ponytail \
			&& claude plugin install ponytail@ponytail \
			&& claude plugin marketplace add JuliusBrussee/caveman \
			&& claude plugin install caveman@caveman \
			&& npm install -g --prefix "$HOME/.local" @caveman-ai/cli \
			&& "$HOME/.local/bin/caveman" setup --install \
			&& { grep -qs caveman-proxy "$HOME/.claude/settings.json" || "$HOME/.local/bin/caveman" enable claude; } \
			&& python3 -c 'import json, sys
p = sys.argv[1]; s = json.load(open(p))
for k in ("ANTHROPIC_BASE_URL", "_CLAUDE_CODE_ASSUME_FIRST_PARTY_BASE_URL"): s.get("env", {}).pop(k, None)
json.dump(s, open(p, "w"), indent=2)' "$HOME/.claude/settings.json"
	} || warn "Claude add-ons failed (often a download hiccup); rerun: ./install.sh --no-packages"
else
	warn "Claude Code is not installed; skipping. Install it (curl -fsSL https://claude.ai/install.sh | bash), then rerun"
fi

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
# Installed by the-script-update from a niri desktop: say that a restart switches over.
if [ "$MIGRATED" -eq 1 ] && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
	notify-send -u critical "the-script is installed" "Restart to switch to the Windows 7 desktop: pick AeroThemePlasma on the logon screen." 2>/dev/null || true
fi
cat <<EOF

Next steps:
  1. Restart. The Windows 7 logon screen comes up; pick the AeroThemePlasma session (bottom left)
     the first time, and it is remembered after that.
  2. The Windows key opens the Start menu, Meta+T the to-do list. See README.md.
  3. NVIDIA card? Install the driver yourself first (e.g. 'sudo pacman -S nvidia-open'),
     since the right package depends on your GPU and kernel. It is not part of this repo.
  4. Display too big/small? System Settings > Display & Monitor > Scale.
EOF
