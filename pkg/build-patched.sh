#!/usr/bin/env bash
#
# pkg/build-patched.sh: build and install the-script's patched lxqt-panel and labwc, and wlrctl (AUR).
#
#   pkg/build-patched.sh          build whatever is out of date
#   pkg/build-patched.sh --check  exit 1 if something needs building (the-script-update runs this)
#
# The patches are in pkg/<package>/*.patch. Each build starts from Arch's own recipe for the version in
# the repos (fetched from gitlab.archlinux.org), adds the patches and a ".1"-style pkgrel, so pacman sees
# it as newer than Arch's. When Arch moves to a newer version, `pacman -Syu` installs the stock one and
# the next check builds the patched one again. A recipe that doesn't match the repo version yet (the
# gitlab copy is updated before the mirrors, or after) is skipped until the next run.

set -euo pipefail
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
STATE="$HOME/.local/state/the-script-patched"
CHECK=0; [ "${1:-}" = --check ] && CHECK=1
warn() { printf 'WARNING: %s\n' "$*" >&2; }
stale=0

local_rel() { # Arch's pkgrel -> ours: 1 -> 1.1, 2.1 -> 2.51
	case $1 in *.*) echo "${1%%.*}.$(( ${1#*.} + 50 ))" ;; *) echo "$1.1" ;; esac
}

build_patched() { # package
	local p=$1 repo rel ours inst hash want work dir
	repo=$(pacman -Si "$p" 2>/dev/null | awk '/^Version/ {print $3; exit}') || return 0
	[ -n "$repo" ] || return 0
	rel=${repo##*-}
	ours="${repo%-*}-$(local_rel "$rel")"
	inst=$(pacman -Q "$p" 2>/dev/null | cut -d' ' -f2) || inst=
	hash=$(cat "$p"/*.patch | sha256sum | cut -c1-16)
	# Up to date: what's installed is the build made here with these patches, not older than the repos'.
	if [ -n "$inst" ] && [ "$(cat "$STATE/$p" 2>/dev/null)" = "$inst $hash" ] && [ "$(vercmp "$inst" "$ours")" -ge 0 ]; then
		return 0
	fi
	stale=1
	[ "$CHECK" -eq 1 ] && return 0

	echo "Building $p $ours with the-script's patches (a few minutes)..."
	work=$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/the-script-build-$p.XXXX")
	if ! curl -sfL --max-time 120 "https://gitlab.archlinux.org/archlinux/packaging/packages/$p/-/archive/main/$p-main.tar.gz" \
		| tar -xz -C "$work" --strip-components=1; then
		warn "could not download Arch's recipe for $p; trying again next time"; rm -rf "$work"; return 0
	fi
	if [ "$(cd "$work" && bash -c 'source ./PKGBUILD >/dev/null 2>&1; echo "$pkgver-$pkgrel"')" != "$repo" ]; then
		warn "Arch's recipe for $p is not at the repo's version $repo yet; trying again next time"; rm -rf "$work"; return 0
	fi
	cp "$p"/*.patch "$work/"
	dir=$(cat "$p/srcdir")
	{
		echo
		echo "# ---- added by the-script (pkg/build-patched.sh) ----"
		echo "pkgrel=$(local_rel "$rel")"
		for f in "$p"/*.patch; do
			f=${f##*/}
			echo "source+=('$f')"
			echo 'for _a in md5sums sha1sums sha256sums sha512sums b2sums; do declare -p "$_a" >/dev/null 2>&1 && eval "$_a+=(SKIP)"; done'
		done
		echo 'if declare -f prepare >/dev/null; then eval "_the_script_prepare()$(declare -f prepare | tail -n +2)"; fi'
		echo 'prepare() {'
		echo '	declare -f _the_script_prepare >/dev/null && _the_script_prepare'
		echo '	cd "$srcdir"'
		for f in "$p"/*.patch; do echo "	patch -d \"$dir\" -p1 < \"\$srcdir/${f##*/}\""; done
		echo '}'
	} >> "$work/PKGBUILD"
	# Signature keys of upstream release tarballs aren't in this user's keyring; checksums are still checked.
	if (cd "$work" && makepkg -sirC --noconfirm --needed --skippgpcheck >"$work/build.log" 2>&1); then
		mkdir -p "$STATE" && echo "$(pacman -Q "$p" | cut -d' ' -f2) $hash" > "$STATE/$p"
		echo "Installed $p $ours"
		rm -rf "$work"
	else
		warn "building patched $p failed; the stock one stays. Log: $work/build.log"
	fi
}

build_aur() { # package: pkg/<package>/PKGBUILD, a copy of its AUR recipe
	local p=$1 work
	pacman -Q "$p" >/dev/null 2>&1 && return 0
	stale=1
	[ "$CHECK" -eq 1 ] && return 0
	echo "Building $p from the AUR recipe in pkg/$p..."
	work=$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/the-script-build-$p.XXXX")
	cp "$p/PKGBUILD" "$work/"
	if (cd "$work" && makepkg -sirC --noconfirm --needed >"$work/build.log" 2>&1); then
		rm -rf "$work"
	else
		warn "building $p failed. Log: $work/build.log"
	fi
}

build_patched lxqt-panel
build_patched labwc
build_aur wlrctl
[ "$CHECK" -eq 0 ] || exit "$stale"
