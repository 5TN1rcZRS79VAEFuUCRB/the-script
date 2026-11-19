#!/usr/bin/env bash
# TEMPORARY (2026-11-18): SSH to arch-server authenticates but hangs opening the session (PAM).
# Collects read-only diagnostics into the Syncthing folder so they reach the laptop. Remove after.
out="$HOME/.local/share/dwm-todo/.arch-server-diag.txt"
t() { echo; echo "### $*"; timeout 15 "$@" 2>&1 | tail -n 80; echo "[exit ${PIPESTATUS[0]}]"; }
{
	date; t uptime; t free -h; t df -h / /home; t cat /proc/pressure/io /proc/pressure/memory
	t sudo -n systemctl --failed --no-pager
	t sudo -n systemctl status systemd-logind dbus-broker dbus user@1000 sshd --no-pager -n 15
	t sudo -n loginctl list-sessions --no-pager
	t sudo -n systemctl list-jobs --no-pager
	t sudo -n journalctl -b -u sshd -n 40 --no-pager
	t sudo -n journalctl -b -u systemd-logind -n 40 --no-pager
	t sudo -n journalctl -b -p warning --since "-12h" -n 120 --no-pager
	t sudo -n journalctl --list-boots --no-pager
	t ps -eo pid,stat,etime,wchan:24,cmd --sort=-pid -q "$(pgrep -d, -f 'sshd|logind|systemd --user|dbus' || echo 1)"
	t sh -c "ps -eo pid,stat,wchan:24,cmd | awk '\$2 ~ /D/'"
	t sudo -n tail -n 30 /var/log/pacman.log
} > "$out.tmp" 2>&1
mv "$out.tmp" "$out"
