#!/bin/sh
# One-line install for sb, the terminal web browser:
#
#   curl -fsSL https://github.com/2982136527/shell-browser-releases/raw/main/install.sh | sh
#
# The source is chosen by asking the sources, not by guessing where you are.
# Measured from a Nanjing China Telecom box: github.com and
# raw.githubusercontent.com never answered at all (a release asset returned zero
# bytes after 25 seconds) while cnb.cool answered in 0.2s; from outside the
# mainland it is the other way round. api.github.com does answer from the
# mainland, which is precisely why nothing here probes it - trusting that would
# choose GitHub and then hang on the download.
#
# Environment:
#   SB_HOST=github|cnb|auto   force one source (default auto: whichever answers)
#   SB_VERSION=v0.1.0         a specific release instead of the newest
#   SB_INSTALL_DIR=DIR        where to put it (default ~/.local/bin, then /usr/local/bin)
#   SB_REPO=owner/name        the release repository, named the same on both
set -e

REPO=${SB_REPO:-2982136527/shell-browser-releases}
WANT=${SB_HOST:-auto}
BIN=${SB_BIN:-sb}
BUDGET=${SB_PROBE_TIMEOUT:-5}
DLTIMEOUT=${SB_DOWNLOAD_TIMEOUT:-300}

say() { printf '%s\n' "$*" >&2; }
die() { say "sb install: $*"; exit 1; }

case $WANT in github | cnb | auto) ;; *) die "SB_HOST must be github, cnb or auto (got $WANT)" ;; esac

# --- what we are installing onto ---------------------------------------------
os=$(uname -s)
case $os in
Darwin) os=darwin ;;
Linux) os=linux ;;
*) die "no build for $os: the releases carry darwin and linux only" ;;
esac
arch=$(uname -m)
case $arch in
arm64 | aarch64) arch=arm64 ;;
x86_64 | amd64) arch=amd64 ;;
*) die "no build for $arch: the releases carry arm64 and amd64 only" ;;
esac

have() { command -v "$1" >/dev/null 2>&1; }
have curl || have wget || die "needs curl or wget to fetch a build"

get() { # get URL FILE
	if have curl; then
		curl -fsSL --max-time "$DLTIMEOUT" -o "$2" "$1"
	else
		wget -q -T "$DLTIMEOUT" -O "$2" "$1"
	fi
}

sha256_of() { # three spellings, in the order they tend to be present
	if have sha256sum; then
		sha256sum "$1" | cut -d' ' -f1
	elif have shasum; then
		shasum -a 256 "$1" | cut -d' ' -f1
	elif have openssl; then
		openssl dgst -sha256 "$1" | cut -d' ' -f2
	else
		die "no sha256sum, shasum or openssl: refusing to install a build we cannot verify"
	fi
}

asset_for() { printf 'shell-browser-%s-%s-%s\n' "${1#v}" "$os" "$arch"; }

# --- GitHub: releases and assets live on github.com ---------------------------
# /releases/latest redirects to /releases/tag/vX.Y.Z, so the newest tag comes
# out of a header and nothing has to be parsed out of JSON.
gh_tag() {
	if have curl; then
		curl -Is --max-time "$BUDGET" "https://github.com/$REPO/releases/latest" 2>/dev/null |
			tr -d '\r' | sed -n 's#^Location:.*/releases/tag/##p' | head -1
	else
		wget -S --max-redirect=0 -T "$BUDGET" -t 1 -O /dev/null \
			"https://github.com/$REPO/releases/latest" 2>&1 |
			sed -n 's/.*Location: *https:\/\/github.com\/[^ ]*\/releases\/tag\///p' | head -1
	fi
}

gh_fetch() { # gh_fetch TAG DIR -> prints the asset name it put in DIR
	name=$(asset_for "$1")
	get "https://github.com/$REPO/releases/download/$1/$name" "$2/$name" &&
		get "https://github.com/$REPO/releases/download/$1/checksums.txt" "$2/checksums.txt" &&
		printf '%s\n' "$name"
}

# --- CNB: no anonymous file over HTTP, but anonymous git read of a public repo --
# The six raw URL shapes that look plausible all return the web app's HTML, and
# the Open API and npm registry both want a token, so the release binaries ride
# on one branch that is replaced wholesale every release. A blobless sparse
# clone asks the server for the one file we need, not all four platforms.
cnb_fetch() { # cnb_fetch DIR -> prints "TAG NAME"; a stale SB_VERSION is not honoured here
	have git || return 1
	git ls-remote --heads "https://cnb.cool/$REPO.git" dist >/dev/null 2>&1 || return 1
	git clone -q --depth 1 --filter=blob:none --sparse --branch dist \
		"https://cnb.cool/$REPO.git" "$1/repo" || return 1
	tag=$(sed -n '1p' "$1/repo/VERSION" 2>/dev/null)
	[ -n "$tag" ] || return 1
	name=$(asset_for "$tag")
	git -C "$1/repo" sparse-checkout set "$name" checksums.txt >/dev/null 2>&1 || return 1
	mv "$1/repo/$name" "$1/$name" && mv "$1/repo/checksums.txt" "$1/checksums.txt" || return 1
	printf '%s %s\n' "$tag" "$name"
}

# --- choose and fetch ---------------------------------------------------------
# Run from a checkout and the files are already here. This matters more than it
# looks: raw.githubusercontent.com is unreachable from the mainland too, so a
# reader there cannot curl this script in the first place and has to arrive
# through git instead -
#
#   git clone --depth 1 -b dist https://cnb.cool/2982136527/shell-browser-releases.git
#   cd shell-browser-releases && sh install.sh
#
# which needs no GitHub reachability at any point.
tmp=$(mktemp -d 2>/dev/null || echo "/tmp/sb-install.$$")
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT INT TERM

tag=""
asset=""
from=""
why=""

here=$(dirname "$0")
if [ -f "$here/checksums.txt" ] && [ -f "$here/VERSION" ]; then
	tag=$(sed -n '1p' "$here/VERSION")
	asset=$(asset_for "$tag")
	if [ -f "$here/$asset" ] &&
		cp "$here/$asset" "$tmp/$asset" && cp "$here/checksums.txt" "$tmp/checksums.txt"; then
		from=local
	else
		tag=""
		asset=""
	fi
fi

if [ -z "$asset" ] && { [ "$WANT" = github ] || [ "$WANT" = auto ]; }; then
	if [ -n "$SB_VERSION" ]; then
		tag=$SB_VERSION
	else
		tag=$(gh_tag || true)
	fi
	if [ -n "$tag" ]; then
		asset=$(gh_fetch "$tag" "$tmp" 2>/dev/null) && from=github || why="github.com did not give the build for $os/$arch"
	else
		why="github.com did not answer within ${BUDGET}s"
	fi
fi

if [ -z "$asset" ] && [ "$WANT" != github ]; then
	[ -n "$why" ] && say "trying cnb.cool instead: $why"
	line=$(cnb_fetch "$tmp" 2>/dev/null) || line=""
	if [ -n "$line" ]; then
		tag=${line%% *}
		asset=${line##* }
		from=cnb
		[ -n "$SB_VERSION" ] && [ "$SB_VERSION" != "$tag" ] &&
			die "cnb.cool only offers $tag, not $SB_VERSION - rerun with SB_HOST=github"
	elif [ -z "$why" ]; then
		why="asked for cnb.cool only"
	fi
fi

if [ -z "$asset" ]; then
	[ -n "$why" ] && say "$why"
	have git || say "note: cnb.cool's channel needs git, which is not installed here"
	die "no build for $os/$arch from github.com or cnb.cool"
fi

# --- verify, then put it down --------------------------------------------------
want=$(sed -n "s#^\([0-9a-f]\{64\}\) *\**$asset\$#\\1#p" "$tmp/checksums.txt" | head -1)
[ -n "$want" ] || die "checksums.txt says nothing about $asset - not installing it"
got=$(sha256_of "$tmp/$asset")
[ "$got" = "$want" ] ||
	die "$asset does not match its published checksum (got $got, want $want) - refusing to run it"

dir=${SB_INSTALL_DIR:-}
if [ -z "$dir" ]; then
	if mkdir -p "$HOME/.local/bin" 2>/dev/null && [ -w "$HOME/.local/bin" ]; then
		dir=$HOME/.local/bin
	elif [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
		dir=/usr/local/bin
	else
		die "neither ~/.local/bin nor /usr/local/bin is writable by you - rerun with SB_INSTALL_DIR somewhere you own"
	fi
fi
mkdir -p "$dir" 2>/dev/null || true
[ -w "$dir" ] || die "$dir is not writable by you - rerun with SB_INSTALL_DIR=~/.local/bin"

test -e "$dir/$BIN" && say "replacing the $BIN already at $dir/$BIN"
mv "$tmp/$asset" "$dir/$BIN"
chmod 755 "$dir/$BIN"

say ""
say "installed $dir/$BIN ($tag, $os/$arch, from $from, sha256 verified)"
case ":$PATH:" in
*":$dir:"*) ;;
*) say "  $dir is not on your PATH yet:  export PATH=\"$dir:\$PATH\"" ;;
esac
say "  then:  sb https://example.com    and    sb update"
