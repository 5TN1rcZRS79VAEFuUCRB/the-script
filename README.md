# the-script

A one-command setup for my Arch Linux desktop: the Hyprland window manager (Wayland) with no desktop
environment: Noctalia as the bar and shell, plus its own Super overview built in Quickshell, set up like
GNOME without the dock, workspaces or app grid: every window maximized, tap Super to search and see all
open windows, Alt+Tab to switch. Dark, good for games (sharp at any display scale, variable refresh rate and
tearing on desktops), with a to-do list for school on the bar, and LibreWolf/KeePassXC/Syncthing/Tailscale/printing set up. Desktop only: nothing from the media server is in here.

## Quick start

On an Arch machine with a normal user that has `sudo`, and a network connection:

```sh
sudo pacman -S --needed git        # if you don't have it yet
git clone https://github.com/5TN1rcZRS79VAEFuUCRB/the-script.git
cd the-script
./install.sh
```

Then log out or restart: a text login (greetd with tuigreet) comes up on the first console. It
remembers the last user, so you just type your password, and Hyprland starts. On a machine that had
LXQt or Plasma (or GNOME), the first Hyprland login also removes it in the background (a notification
says if it fails); coming from Plasma, the one after the next restart removes SDDM, its login screen.
niri and AeroThemePlasma leftovers from earlier versions of this repo go too.

Why greetd and not SDDM or LightDM: SDDM is KDE's and pulls in an X server for its own screen, and
LightDM's greeters are X11 programs as well. greetd is a small login daemon that just starts the
Wayland session, with no X server and nothing to theme.

Why Hyprland, Noctalia and a home-made overview instead of a desktop: GNOME's layout (bar on top, Super to search
and see every window) without its dock, workspaces and app grid, and without its weak spots for games
on Wayland (fractional scaling of X11 games, no tearing). Hyprland renders X11 games at the screen's
real resolution (`xwayland.force_zero_scaling`) and lets fullscreen games tear and use VRR. Its config
is Lua, so the "everything maximized" layout is a few lines in `hyprland.lua`. Ready-made shells for
it either show windows by workspace or stack them where they really are, which with maximized windows
means one on top of the other, so the overview here lays them out side by side like GNOME's. Noctalia
(a native shell, not Quickshell) does the rest: the bar, notifications, lock screen, idle and Alt+Tab.

### Options

| Option | What it does |
| --- | --- |
| `--steam` | Also install Steam plus the matching 32-bit graphics libraries. Needs `[multilib]` enabled in `/etc/pacman.conf`. |
| `--no-packages` | Skip the pacman step. |

Re-running the installer is safe. Anything it would overwrite is copied to
`~/.desktop-backup/<timestamp>/` first.

Screens are set up at each login (and when one is plugged in) by `the-script-displays`: every screen
at its largest resolution and fastest refresh rate, at the scale and position Plasma last used
(`~/.config/kwinoutputconfig.json`), or on a new machine 150% at 4K, 125% on a laptop's own screen and
100% otherwise. It writes them to `~/.config/hypr/monitors.lua`. To keep a different scale, add a line
like `hl.monitor({ output = "DP-1", mode = "highrr", position = "auto", scale = 1.25 })` to
`~/.config/hypr/local.lua` (yours, loaded last; `hyprctl monitors` lists the names). On a desktop (no
battery) variable refresh rate (G-SYNC/FreeSync), tearing and direct scanout are on for fullscreen
games; the laptop leaves them off. X11 apps aren't scaled by Hyprland, so games stay sharp; Steam
scales its own window to match (`STEAM_FORCE_DESKTOPUI_SCALING`).

## What gets installed

| Piece | Where it goes |
| --- | --- |
| Hyprland, Noctalia (the bar, notifications, lock screen, idle, wallpaper, volume/brightness popups, password prompts, Alt+Tab), Quickshell (the Super overview), foot (terminal), Thunar (files), Mousepad (text), imv (images), pavucontrol | packages (`packages.txt`) |
| Hyprland's settings: keys, window rules, the "maxi" layout (every window maximized under the bar, the focused one on top; Super+Left/Right put one on half the screen), square corners, no gaps or blur, VRR/tearing on desktops | `~/.config/hypr/hyprland.lua` (saving it applies it); your own additions in `~/.config/hypr/local.lua` |
| Noctalia, with its own look (change it in its Settings window, from the bar's control center): the bar with the launcher button (click: the overview; right-click: Noctalia's launcher), the window's title, a 12-hour clock, the to-do count, media, tray, notifications, clipboard, network, Bluetooth, volume, brightness, battery and the session menu; no workspaces. Idle: locked after 10 minutes, screens off 30 seconds later, locked before sleep; a fullscreen game or video keeps the screen on. Settings window changes go to `~/.local/state/noctalia/settings.toml` and win over the-script's file | `~/.config/noctalia/the-script.toml` (saving it applies it) |
| The to-do count on the bar (due today · due this week, or a focus session's countdown): a Noctalia plugin. Click it, or Super+T, for the list in Noctalia's launcher (`todo-pick`) | `~/.local/share/the-script-plugins/todo/`, `~/.local/bin/todo-pick` |
| The overview (tap Super, or click the launcher button): the wallpaper dimmed, a search box and every open window side by side, live. Type to find apps and windows; Enter opens the first (or the one picked with the arrow keys/Tab); click a window to go to it, or its x (or middle-click) to close it; it takes its colors from Noctalia's theme | `~/.config/quickshell/OverviewWindow.qml` |
| Alt+Tab (Alt+Shift+Tab backwards): Noctalia's window switcher, most recently used first; let go of Alt to switch | the Alt+Tab binds in `hyprland.lua`, `[shell.window_switcher]` in Noctalia's config |
| The rest of the look: square windows, Adwaita icons, cursor and font; GTK apps dark (Adwaita-dark), Qt apps dark (Fusion via qt6ct); foot at size 11 | `~/.config/gtk-{3,4}.0/settings.ini`, `~/.config/qt6ct/`, `~/.config/foot/foot.ini` |
| `the-script-session`, at every Hyprland login: the screens, then Noctalia, the overview, the to-do daemon, the services that wait for a desktop session (bedtime, history-cleaner) and `the-script-login` (copies your Firefox profile into LibreWolf if that had to wait, and once, removes the desktop this machine had before) | `~/.local/bin/the-script-session`, `the-script-login` |
| Wallpaper: star trails over La Hague lighthouse at sunset, by Antoine Lamielle ([Wikimedia Commons](https://commons.wikimedia.org/wiki/File:2017-04_Circumpolar_trails_sunset_at_La_Hague_lighthouse.jpg), CC BY-SA 4.0), cropped to 3840x2160 | `~/.local/share/wallpapers/the-script.jpg` |
| The login screen: greetd running tuigreet on the first console (time shown, last user remembered), which starts Hyprland (`start-hyprland`) through a login shell, so `~/.bash_profile` puts `~/.local/bin` on PATH. Hyprland's output goes to `~/.cache/hyprland-session.log` | `systemctl enable greetd`, `/etc/greetd/config.toml`, `/etc/greetd/session` (needs sudo) |
| `mouse-dpi`: measures a mouse's real DPI as you slide it 10 cm along a ruler, next to the DPI it is set to (read from a Razer or Endgame Gear mouse), to compare two mice set alike (needs sudo to read the mouse) | `~/.local/bin/mouse-dpi` |
| School assignments and to-dos on the bar (`todo`, shown by the Noctalia plugin above) | `~/.local/bin/todo` |
| LibreWolf (Firefox with privacy defaults) settings: dark everywhere, tabs in the title bar, no AI or sponsored content, fingerprinting protection that still lets sites see dark mode, and cookies kept when it closes so you stay logged in (`user.js`) | your LibreWolf profile directory |
| Your Firefox profile (bookmarks, history, site logins, open tabs, extensions) copied into LibreWolf once, by `librewolf-import-firefox`; if a browser is open, at the next login instead. The LibreWolf profile it replaces goes to the backup folder. Firefox stays installed until you remove it (`sudo pacman -Rs firefox`) | `~/.config/librewolf/librewolf/` |
| LibreWolf as the default browser, so links from other programs open there | `~/.config/mimeapps.list` |
| LibreWolf extensions: uBlock Origin (comes with LibreWolf) and Violentmonkey, installed by a policy (`policies.json`), which also makes Brave Search the default search engine (Startpage stays available as `@sp`). A policy file in /etc replaces LibreWolf's own, so `librewolf-policies` merges the two, again after each LibreWolf update (a pacman hook) | `/etc/librewolf/policies/`, `/usr/local/libexec/librewolf-policies`, `/etc/pacman.d/hooks/librewolf-policies.hook` (needs sudo) |
| `history-cleaner`: each time LibreWolf closes, and at login, deletes sites on a domain list (refreshed daily) from its history, cookies, site data, search-box entries and recently closed tabs; nothing is blocked. Run `history-cleaner` to clean right away (LibreWolf must be closed) | `~/.local/bin/history-cleaner`, `history-cleaner.service` |
| Always-visible userscript (`librewolf/always-visible.user.js`) — makes pages act focused/visible in the background. Imported into Violentmonkey by hand once (a policy can't seed its scripts) | Violentmonkey |
| The text console (the login screen, Ctrl+Alt+F2) powers the monitors off after 10 minutes without a key press; `console-idle` then switches the outputs off in the kernel until a key is pressed, so a DisplayPort monitor that drops off and comes back as it goes to sleep doesn't wake up again | `/etc/systemd/system/console-blank.service`, `console-idle.service`, `/usr/local/libexec/console-idle` (needs sudo) |
| `.local` hostnames over mDNS (`ssh user@machine.local`): Avahi enabled, `mdns_minimal` added to the `hosts:` line | `/etc/nsswitch.conf` (needs sudo) |
| Printing: CUPS with the HP DeskJet 2800 as the default printer (driverless, reached as `HP28C5C8E2CA90.local`; added once it is on) and the Canon MX920 (Gutenprint driver, since its own driverless mode fails, reached as `488E78000000.local`) | CUPS, `systemctl enable cups` (needs sudo) |
| Syncthing (keeps the KeePassXC database in sync), started now and at every login | `systemctl --user enable syncthing`. Pair devices and share the folder yourself at http://127.0.0.1:8384; keys are never in this repo |
| Auto-update: every 5 minutes `the-script-update.timer` pulls this clone and, on a new commit, re-runs `install.sh`. "Update the-script" in the launcher does the same check right away. Failures show a notification (`journalctl --user -u the-script-update`). Needs passwordless sudo, which the installer sets up: anything running as you, and anyone who can push here, gets root | `~/.local/share/applications/the-script-update.desktop`, `~/.local/share/the-script` (link to the clone), `/etc/sudoers.d/10-the-script` (undo: delete it and `systemctl --user disable --now the-script-update.timer`) |
| Steam's in-game overlay follows the display scale (below) | `~/.local/bin/steam-overlay-scale`, `steam-overlay-scale.path` |
| Bedtime (started with the session through `the-script-session.target`, which `the-script-session` starts): the computer is off from 9:30 PM to 6:30 AM every day (an hour without screens before a 10:30 PM bedtime). Warnings 15, 5 and 1 minute before, then it shuts down; turned on before 6:30 AM it shuts down again after a minute's warning. Not on arch-server | `~/.local/bin/bedtime`, `bedtime.service` |
| `screenshot [file.png]`: saves a screenshot of the whole screen with no dialog (grim) | `~/.local/bin/` |
| cc-bench: finds which Claude Code model and effort work best for you (only where Claude Code is installed; see below) | `~/.local/bin/ccb`, `~/.local/bin/ccbench`, `cc-bench.timer`, the status line and a SessionStart hook in `~/.claude/settings.json` |
| `discord-compress video.mp4 [MB]`: re-encodes a video under Discord's upload limit (10 MB by default) | `~/.local/bin/` |
| git commit name and email (GitHub noreply address) | `~/.gitconfig` (only `user.name` and `user.email`) |
| Tailscale, and `ssh arch-server` over it (no browser login; run `sudo tailscale up` once per machine) | `~/.ssh/config.d/`, `~/.ssh/known_hosts.d/`, plus an `Include` line at the top of your own `~/.ssh/config` |

## Keys

Hyprland's keys are in `~/.config/hypr/hyprland.lua` (saving it applies it). The ones worth knowing:

| Action | Keys |
| --- | --- |
| Overview: search apps and windows, see every open window | tap `Super` (also `Super+Space`, `Super+A`, or click the launcher button at the top left) |
| Switch windows | `Alt+Tab`, `Alt+Shift+Tab` (hold Alt, let go to switch) |
| To-do list | `Super+T`, or click its button on the bar |
| Close a window | `Super+Q` or `Alt+F4` |
| Put a window on the left/right half; maximize it again | `Super+Left`, `Super+Right`; `Super+Up` |
| Float a window (or put it back) | `Super+V` or `Super+Down`; move/resize with `Super` + left/right mouse drag |
| Fullscreen | `Super+F` |
| Terminal, files, browser | `Super+Enter`, `Super+E`, `Super+B` |
| Lock the screen | `Super+L` (also before sleep, and after 10 minutes idle) |
| Screenshot | `Print` the whole screen, `Super+Shift+S` an area (Noctalia's) |
| Volume, brightness, media | their keys; Noctalia shows the volume and brightness |

## School assignments and to-dos

The `todo` daemon keeps the Canvas and Schoology assignments, `todo.txt` tasks and today's workout,
and the bar shows how many are due today and in the next 7 days, left of the tray. Its list has the
points and a streak of days in a row with something turned in on time or a finished focus session
(every 7 active days earn a streak freeze that saves a missed day; never a count of late work). It sends reminders 3 days, 1 day and 3
hours before each due date, plus a summary every morning. Click the button or press `Super+T` for the
list: start a 10-minute focus session (it opens the assignment and counts down on the bar; when it ends, a notification says so and the list offers 10 more minutes, a 5-minute
break, or stopping for now without finishing; **Finished it** ends a session early and checks the
task off), open an assignment in the browser, or mark Schoology work done. Click a task for its
actions.

Your own tasks go in `~/.local/share/dwm-todo/todo.txt`, one per line (`2026-10-13 21:00 Poster board`; with
no time, due at 11:59 pm) and are marked done from the list like Schoology work. A workout is a task every
Monday, Wednesday and Friday, named for that day's Hevy routine: pick it and **Finished** to score it. It can only be checked off that day: not ahead, not late.

Points: on time +10, late +3, missing 0 (no penalties); +5 more for turning work in 24 hours or more early;
about 1 in 4 completions pays double (decided per task, so every machine agrees); every 100 points is a level.
Canvas reports status itself. Schoology's feed has no
submission status, so you mark that work done yourself (on time +10, late +3, no penalty); late Schoology
work stays listed for a week unless you mark it done (on time or late: you say which) or hide it; work
due before the first sync just gets **Done**, with no points either way. A finished
focus session is +2. Upcoming work comes first, and on the same day Canvas, then Schoology, then the workout, then Anki; when nothing is
due within 2 days, late work moves to the top. When nothing is late and nothing is due within 3 days,
the list shows a break (`free until Sun 10/11`) instead; it ends when the next 3-day reminder fires.

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
the count drops the moment you answer a card: a small Anki add-on (`~/.local/share/Anki2/addons21/todo`,
loaded the next time Anki starts) counts inside Anki and wakes the daemon, and it re-checks every 5 seconds
as a backup. A second add-on (`~/.local/share/Anki2/addons21/pass_fail`) hides the Hard and Easy buttons
and ignores the `2` and `4` keys, so reviews are just Again (`1`) or Good (`3`/Space).

Then run `todo sync` to check it. `todo selftest` checks the parser and scoring.

To keep points, marked-done work, the token and the config the same on several machines, share
`~/.local/share/dwm-todo` with Syncthing (folder ID `dwm-school`, kept from before the rename so existing machines still match) and put a `.stignore` in it with
`tasks.json`, `lock`, `daemon.lock` and `*.tmp`, so each machine fetches its own assignment list. Before
sharing to a machine that already ran `todo`, delete its `state.json` so the empty one doesn't win.

## Steam overlay scale

Steam's in-game overlay (Shift+Tab) ignores the display scale, so on a scaled 4K monitor it is drawn
tiny. `steam-overlay-scale` patches one value in Steam's 64-bit overlay library so the overlay uses
the largest monitor's scale. It runs at login, and `steam-overlay-scale.path` runs it again whenever a
Steam update replaces the library. Restart a running game to see the change. 32-bit games are not covered.

## cc-bench (Claude Code model and effort)

Compares Claude Code settings on your own sessions: how good the result was against how much of
your plan it used.

- `ccb` starts Claude Code on the next setting in an even rotation (Sonnet 5.5 high, Opus 5.5 medium,
  high and xhigh). Plain `claude` stays as it is; those sessions are graded too but kept apart from
  the fair comparison. The list is `ARMS` in `ccbench`.
- Usage comes from Claude Code's logs (exact tokens, priced at API rates). The status line shows the
  5-hour and weekly limits and records them, which turns usage into "% of your plan".
- Every 2 hours `cc-bench.timer` has Haiku 5.5 grade each finished session (idle 2 hours) from a
  condensed transcript, without telling it the model or effort: task type, difficulty, outcome,
  quality, efficiency and corrections. Grading costs well under a cent per session.
- `ccbench status` prints a summary; `ccbench report --open` opens the report
  (`~/.local/share/cc-bench/report.html`). Each machine grades its own sessions, then
  `cc-bench.timer` swaps data through arch-server over Tailscale ssh (`ccbench sync` does it by
  hand), so every machine's report, status and rotation cover all machines. A machine that's
  offline just shows the last copy it got.

## Not included on purpose

* **NVIDIA drivers.** The right package depends on your GPU and kernel: install it yourself
  (for example `sudo pacman -S nvidia-open`).
* **GPU/RGB lighting control** (hardware specific).
* **All server software** (Jellyfin, Radarr/Sonarr, Docker, Cloudflare and so on) and any
  passwords or API keys, including the Canvas token and Schoology feed link for `todo`.

## Updating this repo

The installer copies files *from* this repo *to* your home directory. To keep the repo current
after changing your live setup, copy the changed file back into the matching path under
`home/` or `librewolf/` and commit it. Your own Hyprland additions belong in `~/.config/hypr/local.lua`,
which the-script never touches. Noctalia applies `~/.config/noctalia/*.toml` as soon as it is saved, and Quickshell reloads the
overview when a `.qml` file is saved.

History: commit `a8ea1cd` is the last dwm version of this setup, and the repo was `niri-script` (the
niri window manager) before it became `the-script`. Installing the-script over niri-script retires
the niri helper scripts and services into the backup folder; niri's own settings in `~/.config` are
left in place, unused. After that it was a Windows 7-style Plasma desktop (AeroThemePlasma), then plain
GNOME for a few days (from `cf21cfb`), then plain Plasma, then LXQt on labwc (a classic Windows
2000-style look, `6b3af9a` to `433eff4`), then Hyprland with its own Quickshell bar (`34882ed`), and now Hyprland with Noctalia. The to-do data folder keeps its old name, `~/.local/share/dwm-todo`, because
Syncthing points at it on every machine.

## License

The scripts, configuration and installer in this repository are under the GNU General Public License v3.0 or later (see `LICENSE`).
The wallpaper (`home/.local/share/wallpapers/the-script.jpg`) is Antoine Lamielle's photo, under CC BY-SA 4.0,
cropped and scaled to 3840x2160.
