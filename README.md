# niri-script

A one-command setup for my Arch Linux desktop: the niri window manager (Wayland) with waybar, the
foot terminal and dmenu-style menus, a status bar with CPU/GPU/RAM/volume/mic, mouse-clickable audio
device pickers, dark mode everywhere, and Firefox/KeePassXC settings. Desktop only: nothing from the media server is in here.

## Quick start

On an Arch machine with a normal user that has `sudo`, and a network connection:

```sh
sudo pacman -S --needed git        # if you don't have it yet
git clone https://github.com/5TN1rcZRS79VAEFuUCRB/niri-script.git
cd niri-script
./install.sh
```

Then log in on the first **text console** (Ctrl+Alt+F1). niri starts automatically after login. If it
doesn't (other console, or you quit niri), run `niri-session`.

### Options

| Option | What it does |
| --- | --- |
| `--scale N` | Display scaling for every monitor connected now: `1`, `1.25`, `1.5`, `2`... Written to `~/.config/niri/local.kdl`. By default a re-run leaves that file alone, so scaling you picked stays put; a first install converts `Xft.dpi` from an old `~/.Xresources` (`144` becomes `1.5`), else uses 1. |
| `--steam` | Also install Steam plus the matching 32-bit graphics libraries. Needs `[multilib]` enabled in `/etc/pacman.conf`. |
| `--no-packages` | Skip the pacman step. |

Re-running the installer is safe. Anything it would overwrite is copied to
`~/.desktop-backup/<timestamp>/` first.

Text too small (e.g. a 4K or laptop screen)? Edit `scale` in `~/.config/niri/local.kdl`: niri applies it
the moment you save, per monitor. That file is this machine's own (the installer writes it once and then
leaves it alone), so it is also the place for a monitor's `mode`, `variable-refresh-rate` (G-SYNC/FreeSync)
or `position`; `niri msg outputs` lists the names and modes. Each monitor starts at its native resolution
with niri picking the fastest refresh rate for it. On a desktop (no battery) the installer also turns on
`variable-refresh-rate` for every monitor, for all windows and fullscreen.

## What gets installed

| Piece | Where it goes |
| --- | --- |
| niri (window manager), waybar (bar and tray), foot (terminal), bemenu (behind a `dmenu` wrapper, drawn to match the bar) | packages, configured in `~/.config/niri/`, `~/.config/waybar/`, `~/.config/foot/` |
| `.bash_profile` (starts niri when you log in on tty1) | `~/` |
| Bar text, audio, tray menu, network (`niri-net`), battery (`niri-power`), mouse speed (`niri-mouse`), school assignments and to-dos (`niri-todo`), and the `dmenu` wrapper | `~/.local/bin/` |
| GTK 3/4 and Qt 5/6 dark-mode config, minimal dunst notifications in the bar's colors | `~/.config/` |
| Firefox settings: dark mode, privacy, no AI or sponsored content (`user.js`) | your Firefox profile directory |
| Firefox as the default browser, so links from other programs open there | `~/.config/mimeapps.list` |
| Firefox extensions: uBlock Origin and Violentmonkey, installed by a policy (`policies.json`) | `/etc/firefox/policies/` (needs sudo) |
| Always-visible userscript (`firefox/always-visible.user.js`) — makes pages act focused/visible in the background. Imported into Violentmonkey by hand once (a policy can't seed its scripts) | Violentmonkey |
| A udev rule letting `niri-mouse` read a Razer or Endgame Gear mouse's DPI | `/etc/udev/rules.d/` (needs sudo) |
| The text console (login prompt after a reboot) powers the monitors off after 10 minutes without a key press, and keeps them off when a DisplayPort monitor's sleep hotplug would light the console again | `/etc/systemd/system/console-blank.service`, `/etc/udev/rules.d/90-console-reblank.rules`, `/usr/local/libexec/console-reblank` (needs sudo) |
| `.local` hostnames over mDNS (`ssh user@machine.local`): Avahi enabled, `mdns_minimal` added to the `hosts:` line | `/etc/nsswitch.conf` (needs sudo) |
| Printing: CUPS with the Canon MX920 as the default printer (Gutenprint driver; the printer's own driverless mode fails), reached as `488E78000000.local` | CUPS, `systemctl enable cups` (needs sudo) |
| Syncthing (keeps the KeePassXC database in sync), started now and at every login | `systemctl --user enable syncthing`. Pair devices and share the folder yourself at http://127.0.0.1:8384; keys are never in this repo |
| Auto-update: every 5 minutes `niri-update.timer` pulls this clone and, on a new commit, re-runs `install.sh` and restarts niri once you are idle (10 minutes without input); the monitors stay off through the restart. Failures show a notification (`journalctl --user -u niri-update`). Needs passwordless sudo, which the installer sets up: anything running as you, and anyone who can push here, gets root | `~/.local/share/niri-script` (link to the clone), `/etc/sudoers.d/10-niri-update` (undo: delete it and `systemctl --user disable --now niri-update.timer`) |
| Desktop-wide "prefer dark" | dconf (`org.gnome.desktop.interface`) |
| Desktops only (no battery): OBS starts hidden in the tray at login with a 30-second replay buffer, and `Alt+F10` saves a clip plus a copy under Discord's 10 MB limit (`obs-clip`, `discord-compress`). Recordings go to `~/Videos/OBS/` as 1080p60 H.264 MP4 | packages `obs-studio`, `python-websockets`; OBS's `Discord` profile in `~/.config/obs-studio/` (written once), the key and autostart in `~/.config/niri/local.kdl` |
| git commit name and email (GitHub noreply address) | `~/.gitconfig` (only `user.name` and `user.email`) |
| Tailscale, and `ssh arch-server` over it (no browser login; run `sudo tailscale up` once per machine) | `~/.ssh/config.d/`, `~/.ssh/known_hosts.d/`, plus an `Include` line at the top of your own `~/.ssh/config` |
| Claude Code: ponytail + caveman plugins and caveman hooks; requests go straight to Anthropic, not through the caveman proxy, so Remote Control works (only if `claude` is installed; undo with `caveman disable claude`) | `~/.claude/settings.json`, `~/.claude.json`, `~/.caveman/` |

Packages are listed in `packages.txt`.

## Keys and mouse

`Mod` is the Super (Windows) key. `Mod+Shift+/` shows every key on screen.

There are no numbered workspaces. Each window opens full width as a column on a strip that scrolls
sideways, so nothing gets squeezed when you open more; `Mod+R` narrows one to fit two or three side by side. Workspaces stack vertically, and there is always an
empty one at the bottom: move a window down to it to start a new workspace, and an emptied
workspace disappears. The dots on the left of the bar show them. Click one to go there.

Some apps have their own spot: Firefox, Discord, then the terminal, left to right, on the top
workspace, and Steam, then the game, on the one below (Proton games, Garry's Mod, Roblox, and Prism Launcher then Minecraft; add a
native game's app-id in `niri-place`), and Anki below that. Opening one takes you there; the workspace is made when the
first of them opens and goes away like any other once they are all closed. Everything else opens
where you are, as before.

| Action | Keys |
| --- | --- |
| Terminal / launcher | `Mod+Shift+Enter` / `Mod+P` |
| Previous / next window | `Mod+A` / `Mod+D` (or `Mod+H` / `Mod+L`) |
| Firefox-Discord-terminal / Steam-games / Anki workspace | `Mod+1` / `Mod+2` / `Mod+3` |
| Workspace above / below | `Mod+W` / `Mod+S` (or `Mod+K` / `Mod+J`, or `Mod`+scroll with a wheel or two fingers on the touchpad) |
| Take the window along | add `Ctrl` (`Mod+Ctrl+W/A/S/D`); below the last workspace makes a new one |
| Overview of every workspace (pick a window with the mouse) | `Mod+Tab` |
| Column width: 1/3, 1/2, 2/3 / full / 10% steps | `Mod+R` / `Mod+F` / `Mod+-` and `Mod+=` |
| Fullscreen / float | `Mod+Shift+F` / `Mod+V` |
| Stack a window into the next column, or pull it out | `Mod+[` / `Mod+]` |
| Monitor left / right (take the window along) | `Mod+,` / `Mod+.` (`Mod+Shift+,` / `Mod+Shift+.`) |
| Close window | `Mod+Shift+C` |
| Hide the bar | `Mod+B` |
| Quit niri | `Mod+Shift+Q` |
| **Volume up / down / mute** | `Mod+F12` / `Mod+F11` / `Mod+F10` (or the keyboard's media keys) |
| **Mic up / down / mute** | `Mod+Shift+F12` / `Mod+Shift+F11` / `Mod+Shift+F10` |
| **Laptop screen brightness up / down** | The keyboard's brightness keys (5% steps) |
| **Output device picker / input device picker** | `Mod+O` / `Mod+Shift+O` |
| **Tray apps menu** | `Mod+Shift+T`, or right-click the window title in the bar |
| **Network picker** | `Mod+N` |
| **Battery details / power profile** | `Mod+Shift+P` |
| **Mouse speed / acceleration profile (flat or adaptive), shows a Razer or Endgame Gear mouse's DPI** | `Mod+Shift+M` |
| **School assignments: next task, 10-minute focus timer, open / mark done** | `Mod+T` |
| **Screenshot: whole screen / pick an area or window / the focused window** | `Print` / `Shift+Print` / `Alt+Print` |
| **Save the last 30 seconds as a clip, plus a Discord-sized copy (desktops)** | `Alt+F10` |

All keys are in `~/.config/niri/config.kdl` (copied from `home/.config/niri/` here); niri applies a
saved change at once.

On the status bar text itself:

| Mouse | Action |
| --- | --- |
| Scroll up / down | Output volume up / down |
| Left click | Output device picker |
| Right click | Input device picker |
| Middle click | Mute output |

In a picker, the bottom entry jumps between the output and input pickers.

## System tray

Apps that "minimize to tray" (Discord, Steam, ...) show their icons in the bar, left of the status
text; click one to bring the app back. `Mod+Shift+T` (or right-clicking the window title in the bar)
lists the same apps in dmenu. Every app is also listed as `quit: <app>`: choosing that closes it for
real (an app's window close button usually just hides it back to the tray). It clicks the Quit/Exit
entry in the app's tray menu, or sends the app a normal terminate signal if it has none.

## Steam overlay scale

Steam's in-game overlay (Shift+Tab) ignores the display scale, so on a scaled 4K monitor it is drawn
tiny. `niri-steam-overlay` patches one value in Steam's 64-bit overlay library so the overlay uses
niri's scale. niri runs it at login, and `niri-steam-overlay.path` runs it again whenever a Steam
update replaces the library. Restart a running game to see the change. 32-bit games are not covered.

## Network picker

`Mod+N` opens a dmenu list of the Wi-Fi networks in range (strongest first, with signal, security and
`saved`/`connected` tags), your wired and VPN connections, and a few actions: turn Wi-Fi on or off,
rescan, forget a saved network, and `nmtui` for anything unusual such as a hidden network.
Choose a network to connect. A new network that needs a password opens a small terminal that asks for
it, so the password is never shown on screen. The bar does not show the network name; the picker's
first line says what you are connected to.

This needs **NetworkManager**. When installing Arch with `archinstall`, choose *NetworkManager* under
network configuration (the installer adds the package but does not switch your network setup over).
Turn it on with `sudo systemctl enable --now NetworkManager`; join Wi-Fi the first time with
`nmtui` if you have no other way online.

## Battery (laptops)

On a machine with a battery the bar shows a battery icon and `87%`, with `+` while charging, `=` when the charge
limit is holding it, and `!` when it is at 15% or below. Nothing is shown on a desktop.
`Mod+Shift+P` opens a dmenu list with the time left (or until full), power draw, battery health,
any charge limit and, if `power-profiles-daemon` is installed, the power profile, which you can
switch by choosing one.

## School assignments and to-dos

`niri-todo` puts the next Canvas or Schoology assignment, `todo.txt` task or today's workout in its own block on the bar (title and
time left, points and a streak of days in a row with something turned in on time or a finished focus
session, where every 7 active days earn a streak freeze that saves a missed day; never a count of late work) and sends reminders 3 days, 1 day and 3 hours before
each due date, plus a summary every morning. `Mod+T` opens a dmenu list: start a 10-minute focus session
(it opens the assignment and counts down in the bar with the task's name; when it ends, a notification
says so and `Mod+T` offers 10 more minutes, a 5-minute break, or stopping for now without finishing, so nothing grabs the keyboard while you
type; **Finished it** ends a session early and checks the task off), open an assignment in the browser,
or mark Schoology work done.

Your own tasks go in `~/.local/share/dwm-todo/todo.txt`, one per line (`2026-10-13 21:00 Poster board`; with
no time, due at 11:59 pm) and are marked done from the menu like Schoology work. A workout is a task every
Sunday, Monday, Wednesday and Friday: pick it and **Finished** to score it. It can only be checked off that day: not ahead, not late.

Points: on time +10, late +3, missing 0 (no penalties); +5 more for turning work in 24 hours or more early;
about 1 in 4 completions pays double (decided per task, so every machine agrees); every 100 points is a level.
Canvas reports status itself. Schoology's feed has no
submission status, so you mark that work done yourself (on time +10, late +3, no penalty); late Schoology
work stays listed for a week unless you mark it done (on time or late: you say which) or hide it; work
due before the first sync just gets **Done**, with no points either way. A finished
focus session is +2. Upcoming work comes first, and on the same day Canvas, then Schoology, then Anki; when nothing is
due within 2 days, late work moves to the top. When nothing is late and nothing is due within 3 days,
the bar shows a break (`free until Sun 10/11`) instead; it ends when the next 3-day reminder fires.

It needs two things that are never in this repo, both in `~/.local/share/dwm-todo/`:

* `canvas_token`: Canvas → Account → Settings → **New Access Token** (chmod 600)
* `dwm-todo.conf`:

  ```
  canvas_url=https://yourschool.instructure.com
  canvas_token_expires=2027-01-01
  schoology_ics=webcal://...
  ```

  The Schoology link is Calendar → Export iCal Feed → Share Calendar (turn on the public calendar feed
  in account settings first). `canvas_token_expires` is optional and gives a daily warning in the token's
  last week.

`install.sh` also installs Anki (with `mpv` for card audio). Once you sign in with Anki's Sync button,
today's due cards show up as `Anki: N cards`, due at 11:59 PM; opening it starts Anki, and getting to zero is +10 and a
streak day. The cards are counted on a copy of the collection, so Anki can stay open. While you study,
the count drops the moment you answer a card: a small Anki add-on (`~/.local/share/Anki2/addons21/niri_todo`,
loaded the next time Anki starts) counts inside Anki and wakes niri-todo, and it re-checks every 5 seconds
as a backup. A second add-on (`~/.local/share/Anki2/addons21/pass_fail`) hides the Hard and Easy buttons
and ignores the `2` and `4` keys, so reviews are just Again (`1`) or Good (`3`/Space).

Then run `niri-todo sync` to check it. `niri-todo selftest` checks the parser and scoring.

To keep points, marked-done work, the token and the config the same on several machines, share
`~/.local/share/dwm-todo` with Syncthing (folder ID `dwm-school`, kept from before the rename so existing machines still match) and put a `.stignore` in it with
`tasks.json`, `lock`, `daemon.lock` and `*.tmp`, so each machine fetches its own assignment list. Before
sharing to a machine that already ran `niri-todo`, delete its `state.json` so the empty one doesn't win.

## Screenshots

`Print` takes the whole screen, `Shift+Print` opens niri's selector (drag an area or click a window,
`Space` or `Enter` takes it, `Esc` cancels) and `Alt+Print` takes the focused window. Each is saved as
a PNG in `~/Pictures/Screenshots/` and copied to the clipboard, so you can paste it straight into a chat.

## Idle screen-off

After 10 minutes idle `swayidle` powers the monitors off (real DPMS sleep); any key or mouse movement
wakes them. Video players that ask the desktop to stay awake are honoured. To change the timeout, edit
the `swayidle` line in `~/.config/niri/config.kdl`; `niri msg action power-off-monitors` tries it by hand.

The X11 version of this setup never let the monitors sleep, only dimmed them to black: waking a Samsung
Odyssey G8 at 4K 240 Hz (compressed DSC over DisplayPort) on NVIDIA from X's DPMS sleep could leave it
with no picture until a reboot. Under niri the same monitor and GPU (RTX 4080, `nvidia-open` 615.78)
wakes with the picture back after a 5-minute sleep.

## Not included on purpose

* **NVIDIA drivers.** The right package depends on your GPU and kernel: install it yourself
  (for example `sudo pacman -S nvidia-open`). The bar shows GPU load and temperature by itself once
  `nvidia-smi` works (it uses one long-running `nvidia-smi`, not a new one every second).
* **GPU/RGB lighting control** (hardware specific).
* **All server software** (Jellyfin, Radarr/Sonarr, Docker, Cloudflare and so on) and any
  passwords or API keys, including the Canvas token and Schoology feed link for `niri-todo`.

## Updating this repo

The installer copies files *from* this repo *to* your home directory. To keep the repo current
after changing your live setup, copy the changed file back into the matching path under
`home/` or `firefox/` and commit it.

Commit `a8ea1cd` is the last dwm version of this setup. The helper scripts were called `dwm-*` then and
are `niri-*` now; the to-do data folder keeps its old name, `~/.local/share/dwm-todo`, because Syncthing
points at it on every machine.

## License

The scripts, configuration and installer in this repository are under the GNU General Public License v3.0 or later (see `LICENSE`).
