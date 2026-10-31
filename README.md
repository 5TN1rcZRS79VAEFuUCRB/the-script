# the-script

A one-command setup for my Arch Linux desktop: plain KDE Plasma in Breeze Dark, with a to-do list for
school on the taskbar, and LibreWolf/KeePassXC/Syncthing/Tailscale/printing set up. Desktop only: nothing from the media server is in here.

## Quick start

On an Arch machine with a normal user that has `sudo`, and a network connection:

```sh
sudo pacman -S --needed git        # if you don't have it yet
git clone https://github.com/5TN1rcZRS79VAEFuUCRB/the-script.git
cd the-script
./install.sh
```

Then restart: SDDM, Plasma's login screen, comes up. On a machine that had GNOME, the first Plasma
login also removes GNOME in the background (a notification says if it fails); its settings are left
alone. A machine still on the Windows 7 desktop loses AeroThemePlasma and keeps Plasma. niri, left over
from niri-script, is removed too, so Plasma is the only session at the login screen.

### Options

| Option | What it does |
| --- | --- |
| `--steam` | Also install Steam plus the matching 32-bit graphics libraries. Needs `[multilib]` enabled in `/etc/pacman.conf`. |
| `--no-packages` | Skip the pacman step. |

Re-running the installer is safe. Anything it would overwrite is copied to
`~/.desktop-backup/<timestamp>/` first.

Text too small (e.g. a 4K or laptop screen)? System Settings > Display & Monitor > Scale (fractional
scales like 125% are there too). Variable refresh rate (G-SYNC/FreeSync) is in the same place, per
monitor; on a desktop the first login turns it on always, games included. Games through Proton (X11
apps) see the monitor's real resolution and refresh rate at any scale, as long as System Settings >
Display & Monitor > Legacy Applications (X11) stays on "Apply scaling themselves".

## What gets installed

| Piece | Where it goes |
| --- | --- |
| KDE Plasma (Plasma, System Settings, Dolphin, Konsole, Kate, Gwenview, Spectacle) | packages (`packages.txt`) |
| Settings applied at every login by `the-script-plasma` (they need the running session): Breeze Dark and, on a desktop, variable refresh rate always on (first login only), the wallpaper on the desktop and lock screen and the classic Vanilla-DMZ cursor (once each), and the to-do widget on the taskbar left of the tray, opened by `Meta+T` | `~/.config/autostart/the-script-plasma.desktop` |
| Wallpaper: a black hole, the first frame of NASA Goddard's accretion disk visualization ([svs.gsfc.nasa.gov/13326](https://svs.gsfc.nasa.gov/13326), public domain) cropped to 3840x2160 | `~/.local/share/wallpapers/nasa-black-hole.png` |
| The login screen (SDDM) | `systemctl enable sddm` (needs sudo) |
| `mouse-dpi`: measures a mouse's real DPI as you slide it 10 cm along a ruler, next to the DPI it is set to (read from a Razer or Endgame Gear mouse), to compare two mice set alike (needs sudo to read the mouse) | `~/.local/bin/mouse-dpi` |
| School assignments and to-dos on the taskbar (`todo`, `todo-bar`, the `local.todo` Plasma widget) | `~/.local/bin/`, `~/.local/share/plasma/plasmoids/local.todo/`, `~/.config/autostart/todo.desktop` |
| LibreWolf (Firefox with privacy defaults) settings: follows the desktop's dark mode, tabs in the title bar, no AI or sponsored content, fingerprinting protection that still lets sites see dark mode, and cookies kept when it closes so you stay logged in (`user.js`) | your LibreWolf profile directory |
| Your Firefox profile (bookmarks, history, site logins, open tabs, extensions) copied into LibreWolf once, by `librewolf-import-firefox`; if a browser is open, at the next login instead. The LibreWolf profile it replaces goes to the backup folder. Firefox stays installed until you remove it (`sudo pacman -Rs firefox`) | `~/.config/librewolf/librewolf/` |
| LibreWolf as the default browser, so links from other programs open there | `~/.config/mimeapps.list` |
| LibreWolf extensions: uBlock Origin (comes with LibreWolf) and Violentmonkey, installed by a policy (`policies.json`), which also makes Startpage (Google's results without the tracking) the default search engine. A policy file in /etc replaces LibreWolf's own, so `librewolf-policies` merges the two, again after each LibreWolf update (a pacman hook) | `/etc/librewolf/policies/`, `/usr/local/libexec/librewolf-policies`, `/etc/pacman.d/hooks/librewolf-policies.hook` (needs sudo) |
| Always-visible userscript (`librewolf/always-visible.user.js`) — makes pages act focused/visible in the background. Imported into Violentmonkey by hand once (a policy can't seed its scripts) | Violentmonkey |
| The text console (Ctrl+Alt+F2) powers the monitors off after 10 minutes without a key press, and keeps them off when a DisplayPort monitor's sleep hotplug would light the console again | `/etc/systemd/system/console-blank.service`, `/etc/udev/rules.d/90-console-reblank.rules`, `/usr/local/libexec/console-reblank` (needs sudo) |
| `.local` hostnames over mDNS (`ssh user@machine.local`): Avahi enabled, `mdns_minimal` added to the `hosts:` line | `/etc/nsswitch.conf` (needs sudo) |
| Printing: CUPS with the Canon MX920 as the default printer (Gutenprint driver; the printer's own driverless mode fails), reached as `488E78000000.local` | CUPS, `systemctl enable cups` (needs sudo) |
| Syncthing (keeps the KeePassXC database in sync), started now and at every login | `systemctl --user enable syncthing`. Pair devices and share the folder yourself at http://127.0.0.1:8384; keys are never in this repo |
| Auto-update: every 5 minutes `the-script-update.timer` pulls this clone and, on a new commit, re-runs `install.sh`. "Update the-script" in the launcher does the same check right away. Failures show a notification (`journalctl --user -u the-script-update`). Needs passwordless sudo, which the installer sets up: anything running as you, and anyone who can push here, gets root | `~/.local/share/applications/the-script-update.desktop`, `~/.local/share/the-script` (link to the clone), `/etc/sudoers.d/10-the-script` (undo: delete it and `systemctl --user disable --now the-script-update.timer`) |
| Steam's in-game overlay follows the display scale (below) | `~/.local/bin/steam-overlay-scale`, `steam-overlay-scale.path` |
| `screenshot [file.png]`: saves a screenshot of the whole screen with no dialog, through Spectacle | `~/.local/bin/` |
| `discord-compress video.mp4 [MB]`: re-encodes a video under Discord's upload limit (10 MB by default) | `~/.local/bin/` |
| git commit name and email (GitHub noreply address) | `~/.gitconfig` (only `user.name` and `user.email`) |
| Tailscale, and `ssh arch-server` over it (no browser login; run `sudo tailscale up` once per machine) | `~/.ssh/config.d/`, `~/.ssh/known_hosts.d/`, plus an `Include` line at the top of your own `~/.ssh/config` |

## Keys

Plasma's usual keys apply (System Settings > Keyboard > Shortcuts). The ones worth knowing:

| Action | Keys |
| --- | --- |
| Launcher: search and start apps | `Meta` (the Windows key) |
| To-do list | `Meta+T`, or click its text on the taskbar (KWin's tile editor gives up `Meta+T` for it) |
| Screenshot | `Print` (Spectacle), `Meta+Shift+S` for an area |

## School assignments and to-dos

The `todo` daemon puts the next Canvas or Schoology assignment, `todo.txt` task or today's workout on
the taskbar, left of the tray (title and time left, points and a streak of days in a row with
something turned in on time or a finished focus session, where every 7 active days earn a streak
freeze that saves a missed day; never a count of late work), and sends reminders 3 days, 1 day and 3
hours before each due date, plus a summary every morning. Click the text or press `Meta+T` for the
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

## Not included on purpose

* **NVIDIA drivers.** The right package depends on your GPU and kernel: install it yourself
  (for example `sudo pacman -S nvidia-open`).
* **GPU/RGB lighting control** (hardware specific).
* **All server software** (Jellyfin, Radarr/Sonarr, Docker, Cloudflare and so on) and any
  passwords or API keys, including the Canvas token and Schoology feed link for `todo`.

## Updating this repo

The installer copies files *from* this repo *to* your home directory. To keep the repo current
after changing your live setup, copy the changed file back into the matching path under
`home/` or `librewolf/` and commit it.

History: commit `a8ea1cd` is the last dwm version of this setup, and the repo was `niri-script` (the
niri window manager) before it became `the-script`. Installing the-script over niri-script retires
the niri helper scripts and services into the backup folder; niri's own settings in `~/.config` are
left in place, unused. After that it was a Windows 7-style Plasma desktop (AeroThemePlasma), then plain
GNOME for a few days (from `cf21cfb`), and now plain Plasma. The to-do data folder keeps its old name, `~/.local/share/dwm-todo`, because
Syncthing points at it on every machine.

## License

The scripts, configuration and installer in this repository are under the GNU General Public License v3.0 or later (see `LICENSE`).
