# the-script

A one-command setup for my Arch Linux desktop: LXQt on the labwc window manager (Wayland), made to
look like an old-style dark desktop (gray bevelled buttons, navy title bars, a Start button), light
enough for an old laptop, with a to-do list for school on the taskbar, and LibreWolf/KeePassXC/Syncthing/Tailscale/printing set up. Desktop only: nothing from the media server is in here.

## Quick start

On an Arch machine with a normal user that has `sudo`, and a network connection:

```sh
sudo pacman -S --needed git        # if you don't have it yet
git clone https://github.com/5TN1rcZRS79VAEFuUCRB/the-script.git
cd the-script
./install.sh
```

Then restart: a text login (greetd with tuigreet) comes up on the first console. It remembers the last
user, so you just type your password, and LXQt starts. On a machine that had Plasma (or GNOME), the
first LXQt login also removes it in the background (a notification says if it fails), and the one after
the next restart removes SDDM, Plasma's old login screen. Their settings in `~/.config` are left alone.
niri and AeroThemePlasma leftovers from earlier versions of this repo go too.

Why greetd and not SDDM or LightDM: SDDM is KDE's and pulls in an X server for its own screen, and
LightDM's greeters are X11 programs as well. greetd is a small login daemon that just starts the
Wayland session, with no X server and nothing to theme.

### Options

| Option | What it does |
| --- | --- |
| `--steam` | Also install Steam plus the matching 32-bit graphics libraries. Needs `[multilib]` enabled in `/etc/pacman.conf`. |
| `--no-packages` | Skip the pacman step. |

Re-running the installer is safe. Anything it would overwrite is copied to
`~/.desktop-backup/<timestamp>/` first.

Screens are set up at each login by `the-script-displays`: every screen at its largest resolution and
fastest refresh rate, at the scale and position Plasma last used (`~/.config/kwinoutputconfig.json`), or
on a new machine 150% at 4K, 125% on a laptop's own screen and 100% otherwise. To change the scale for
a session, LXQt's Monitor Settings (or `wlr-randr --output NAME --scale 1.5`); to keep it, edit the
numbers in `the-script-displays`. On a desktop (no battery) labwc's variable refresh rate
(G-SYNC/FreeSync) and tearing are on for fullscreen games; the laptop leaves both off.

## What gets installed

| Piece | Where it goes |
| --- | --- |
| LXQt (panel, settings, notifications, power management), labwc, PCManFM-Qt (files), QTerminal, FeatherPad (text), LXImage-Qt, pavucontrol-qt, the network and Bluetooth tray icons, swaylock | packages (`packages.txt`) |
| The ClassicDark look: labwc's window theme (3 px frame, navy gradient title bars, bevelled buttons), the panel theme (raised buttons that sink when pressed), the MATE icons, gray Qt colors (also in `kdeglobals`, which Qt reads for buttons and notifications) and GNOME's black Adwaita cursor; GTK apps in their dark theme | `~/.local/share/themes/ClassicDark/`, `~/.local/share/lxqt/themes/ClassicDark/`, `~/.config/lxqt/lxqt.conf`, `~/.config/kdeglobals`, `~/.config/gtk-{3,4}.0/settings.ini` |
| The panel along the bottom: Start (searchable app menu), the open windows, the tray, then text buttons for the to-do list, the battery (laptops only) and the sound, and the clock. The sound button's menu picks the output and input, mutes and sets the volume; scroll on it to change the volume | `~/.config/lxqt/panel.conf`, `~/.local/bin/{todo-count,todo-menu,battery-text,audio-status,audio-menu}`, labwc's `menu.xml` |
| labwc's keys, menus and session start (`autostart`: the screens, the wallpaper, the session's services, one click on Start so the Super key works) | `~/.config/labwc/` |
| A patched lxqt-panel (the Start menu opens above the panel instead of over it, with no delay, and arrow keys move through search results) and labwc (a submenu's highlight clears when the pointer leaves it), built from Arch's own recipes plus `pkg/*/*.patch` by `pkg/build-patched.sh`, and again whenever an Arch update replaces them (the-script-update checks every 5 minutes); `wlrctl` from the AUR for the Start click at login | `pkg/` (needs `base-devel`) |
| `the-script-lxqt`, at every LXQt login: copies your Firefox profile into LibreWolf if that had to wait, and once, removes Plasma (by running the installer again) | `~/.config/autostart/the-script-lxqt.desktop` |
| Wallpaper: star trails over La Hague lighthouse at sunset, by Antoine Lamielle ([Wikimedia Commons](https://commons.wikimedia.org/wiki/File:2017-04_Circumpolar_trails_sunset_at_La_Hague_lighthouse.jpg), CC BY-SA 4.0), cropped to 3840x2160 | `~/.local/share/wallpapers/the-script.jpg` |
| The login screen: greetd running tuigreet on the first console (time shown, last user remembered), which starts `startlxqtwayland` | `systemctl enable greetd`, `/etc/greetd/config.toml` (needs sudo) |
| `mouse-dpi`: measures a mouse's real DPI as you slide it 10 cm along a ruler, next to the DPI it is set to (read from a Razer or Endgame Gear mouse), to compare two mice set alike (needs sudo to read the mouse) | `~/.local/bin/mouse-dpi` |
| School assignments and to-dos on the taskbar (`todo`, shown by `todo-count`, its list in `todo-menu`) | `~/.local/bin/`, `~/.config/autostart/todo.desktop` |
| LibreWolf (Firefox with privacy defaults) settings: dark everywhere (LXQt doesn't tell apps it is dark), labwc's title bar above the tabs, no AI or sponsored content, fingerprinting protection that still lets sites see dark mode, and cookies kept when it closes so you stay logged in (`user.js`) | your LibreWolf profile directory |
| Your Firefox profile (bookmarks, history, site logins, open tabs, extensions) copied into LibreWolf once, by `librewolf-import-firefox`; if a browser is open, at the next login instead. The LibreWolf profile it replaces goes to the backup folder. Firefox stays installed until you remove it (`sudo pacman -Rs firefox`) | `~/.config/librewolf/librewolf/` |
| LibreWolf as the default browser, so links from other programs open there | `~/.config/mimeapps.list` |
| LibreWolf extensions: uBlock Origin (comes with LibreWolf) and Violentmonkey, installed by a policy (`policies.json`), which also makes Brave Search the default search engine (Startpage stays available as `@sp`). A policy file in /etc replaces LibreWolf's own, so `librewolf-policies` merges the two, again after each LibreWolf update (a pacman hook) | `/etc/librewolf/policies/`, `/usr/local/libexec/librewolf-policies`, `/etc/pacman.d/hooks/librewolf-policies.hook` (needs sudo) |
| `history-cleaner`: each time LibreWolf closes, and at login, deletes sites on a domain list (refreshed daily) from its history, cookies, site data, search-box entries and recently closed tabs; nothing is blocked. Run `history-cleaner` to clean right away (LibreWolf must be closed) | `~/.local/bin/history-cleaner`, `history-cleaner.service` |
| Always-visible userscript (`librewolf/always-visible.user.js`) — makes pages act focused/visible in the background. Imported into Violentmonkey by hand once (a policy can't seed its scripts) | Violentmonkey |
| The text console (Ctrl+Alt+F2) powers the monitors off after 10 minutes without a key press, and keeps them off when a DisplayPort monitor's sleep hotplug would light the console again | `/etc/systemd/system/console-blank.service`, `/etc/udev/rules.d/90-console-reblank.rules`, `/usr/local/libexec/console-reblank` (needs sudo) |
| `.local` hostnames over mDNS (`ssh user@machine.local`): Avahi enabled, `mdns_minimal` added to the `hosts:` line | `/etc/nsswitch.conf` (needs sudo) |
| Printing: CUPS with the HP DeskJet 2800 as the default printer (driverless, reached as `HP28C5C8E2CA90.local`; added once it is on) and the Canon MX920 (Gutenprint driver, since its own driverless mode fails, reached as `488E78000000.local`) | CUPS, `systemctl enable cups` (needs sudo) |
| Syncthing (keeps the KeePassXC database in sync), started now and at every login | `systemctl --user enable syncthing`. Pair devices and share the folder yourself at http://127.0.0.1:8384; keys are never in this repo |
| Auto-update: every 5 minutes `the-script-update.timer` pulls this clone and, on a new commit, re-runs `install.sh`. "Update the-script" in the launcher does the same check right away. Failures show a notification (`journalctl --user -u the-script-update`). Needs passwordless sudo, which the installer sets up: anything running as you, and anyone who can push here, gets root | `~/.local/share/applications/the-script-update.desktop`, `~/.local/share/the-script` (link to the clone), `/etc/sudoers.d/10-the-script` (undo: delete it and `systemctl --user disable --now the-script-update.timer`) |
| Steam's in-game overlay follows the display scale (below) | `~/.local/bin/steam-overlay-scale`, `steam-overlay-scale.path` |
| Bedtime (started with the session through `the-script-session.target`, which labwc's autostart starts since LXQt doesn't): the computer is off from 9:30 PM to 6:30 AM every day (an hour without screens before a 10:30 PM bedtime). Warnings 15, 5 and 1 minute before, then it shuts down; turned on before 6:30 AM it shuts down again after a minute's warning. Not on arch-server | `~/.local/bin/bedtime`, `bedtime.service` |
| `screenshot [file.png]`: saves a screenshot of the whole screen with no dialog (grim) | `~/.local/bin/` |
| cc-bench: finds which Claude Code model and effort work best for you (only where Claude Code is installed; see below) | `~/.local/bin/ccb`, `~/.local/bin/ccbench`, `cc-bench.timer`, the status line and a SessionStart hook in `~/.claude/settings.json` |
| `discord-compress video.mp4 [MB]`: re-encodes a video under Discord's upload limit (10 MB by default) | `~/.local/bin/` |
| git commit name and email (GitHub noreply address) | `~/.gitconfig` (only `user.name` and `user.email`) |
| Tailscale, and `ssh arch-server` over it (no browser login; run `sudo tailscale up` once per machine) | `~/.ssh/config.d/`, `~/.ssh/known_hosts.d/`, plus an `Include` line at the top of your own `~/.ssh/config` |

## Keys

labwc's keys are in `~/.config/labwc/rc.xml` (`Ctrl+Shift+R` reloads it). The ones worth knowing:

| Action | Keys |
| --- | --- |
| Start menu; type to search, arrows and Enter to pick | `Super` (the Windows key) |
| Run a command | `Alt+F2` |
| To-do list | `Super+T`, or click its button on the panel |
| Sound menu | click the sound button; volume keys work too |
| Switch windows | `Alt+Tab` |
| Snap a window to a half of the screen (two in a row, like Up then Left: a quarter) | `Super+Left`, `Right`, `Up`, `Down`; `Super+A` maximizes |
| Show the desktop | `Super+D` |
| Lock the screen | `Super+L` (swaylock; also before sleep) |
| Screenshot | `Print` saves the screen to `~/Pictures`, `Super+Shift+S` copies an area |
| Window menu | `Alt+Space` |

## School assignments and to-dos

The `todo` daemon puts the next Canvas or Schoology assignment, `todo.txt` task or today's workout on
the panel, right of the tray (title and time left, points and a streak of days in a row with
something turned in on time or a finished focus session, where every 7 active days earn a streak
freeze that saves a missed day; never a count of late work), and sends reminders 3 days, 1 day and 3
hours before each due date, plus a summary every morning. Click the button or press `Super+T` for the
list: start a 10-minute focus session (it opens the assignment and counts down on the taskbar with
the task's name; when it ends, a notification says so and the list offers 10 more minutes, a 5-minute
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
the taskbar shows a break (`free until Sun 10/11`) instead; it ends when the next 3-day reminder fires.

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
`home/` or `librewolf/` and commit it. Files under `seed/home/` (the panel, labwc's keys and menus,
LXQt's settings) are different: they are put in place only when the repo's copy changes, so changes
made in LXQt's settings windows stay until then (the old file goes to the backup folder).

History: commit `a8ea1cd` is the last dwm version of this setup, and the repo was `niri-script` (the
niri window manager) before it became `the-script`. Installing the-script over niri-script retires
the niri helper scripts and services into the backup folder; niri's own settings in `~/.config` are
left in place, unused. After that it was a Windows 7-style Plasma desktop (AeroThemePlasma), then plain
GNOME for a few days (from `cf21cfb`), then plain Plasma, and now LXQt. The to-do data folder keeps its old name, `~/.local/share/dwm-todo`, because
Syncthing points at it on every machine.

## License

The scripts, configuration and installer in this repository are under the GNU General Public License v3.0 or later (see `LICENSE`).
The wallpaper (`home/.local/share/wallpapers/the-script.jpg`) is Antoine Lamielle's photo, under CC BY-SA 4.0,
cropped and scaled to 3840x2160.
