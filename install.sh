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
	# --speed-limit is what makes two sources usable from a machine that can only
	# reach one of them: without it a host that accepts the connection and then
	# sends nothing - which is what github.com does from the mainland - holds the
	# script for the whole 300-second budget before we are allowed to give up and
	# ask cnb.cool. Under 2 KB/s for 20 seconds means it is not downloading.
	if have curl; then
		curl -fsSL --connect-timeout "$BUDGET" --speed-limit 2048 --speed-time 20 \
			--max-time "$DLTIMEOUT" -o "$2" "$1"
	else
		wget -q --timeout=20 -T "$DLTIMEOUT" -O "$2" "$1"
	fi
}

alive() { # alive URL - can this host actually start delivering this file?
	#
	# Asking "is the site up" is not enough and neither is "is the version
	# readable": from the mainland github.com answers the redirect that names the
	# newest release, and then the asset itself trickles in at just over any
	# low-speed limit you care to set, or sends nothing at all - measured as 0
	# bytes after 12 seconds, against 0.8 seconds for the same file on cnb.cool.
	# One byte is the only question that predicts whether a download will finish.
	if have curl; then
		curl -fsSL --connect-timeout "$BUDGET" --max-time 12 --range 0-0 -o /dev/null "$1" 2>/dev/null
	else
		wget -q --timeout=12 -O /dev/null "$1" 2>/dev/null
	fi
}

probe() { # probe URL FILE - a short budget and silence: this only asks a
	# question, it is not how the build gets here
	if have curl; then
		curl -fsSL --max-time "$BUDGET" -o "$2" "$1" 2>/dev/null
	else
		wget -q -T "$BUDGET" -t 1 -O "$2" "$1" 2>/dev/null
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
	# HTTP/2 folds every response header name to lowercase, so this cannot match
	# "Location:" literally - doing that reports "github.com did not answer" from
	# a machine that is reaching it perfectly well.
	if have curl; then
		curl -Is --max-time "$BUDGET" "https://github.com/$REPO/releases/latest" 2>/dev/null |
			tr -d '\r' | grep -i '^location:' | head -1 | sed 's#.*/releases/tag/##'
	else
		wget -S --max-redirect=0 -T "$BUDGET" -t 1 -O /dev/null \
			"https://github.com/$REPO/releases/latest" 2>&1 |
			grep -i 'location:' | head -1 | sed 's#.*/releases/tag/##'
	fi
}

gh_asset_url() { printf 'https://github.com/%s/releases/download/%s/%s\n' "$REPO" "$1" "$(asset_for "$1")"; }

gh_fetch() { # gh_fetch TAG DIR -> prints the asset name it put in DIR
	name=$(asset_for "$1")
	get "https://github.com/$REPO/releases/download/$1/$name" "$2/$name" &&
		get "https://github.com/$REPO/releases/download/$1/checksums.txt" "$2/checksums.txt" &&
		printf '%s\n' "$name"
}

# --- CNB: release assets, over plain HTTPS -----------------------------------
# CNB serves a public repository's release assets to an anonymous caller -
# measured: 8786104 bytes, byte-identical, 2.3s from a Nanjing China Telecom
# box, no token and no git. It has no /releases/latest/download/... form and its
# /-/releases/latest redirects to the list page rather than the newest tag, so a
# permanent release tagged "latest" carries VERSION and this script; the tag
# that names is then used for the real files.
cnb_tag() { # the newest tag, from the permanent "latest" release
	t=$(mktemp) || return 1
	probe "https://cnb.cool/$REPO/-/releases/download/latest/VERSION" "$t" && sed -n '1p' "$t"
	rm -f "$t"
}

cnb_asset_url() { printf 'https://cnb.cool/%s/-/releases/download/%s/%s\n' "$REPO" "$1" "$(asset_for "$1")"; }

cnb_fetch() { # cnb_fetch TAG DIR -> prints the asset name it put in DIR
	name=$(asset_for "$1")
	get "https://cnb.cool/$REPO/-/releases/download/$1/$name" "$2/$name" &&
		get "https://cnb.cool/$REPO/-/releases/download/$1/checksums.txt" "$2/checksums.txt" &&
		printf '%s\n' "$name"
}

# --- choose and fetch ---------------------------------------------------------
# Run from a checkout and the files are already here, which still works and is
# handy when you have cloned the release repository for some other reason.
tmp=$(mktemp -d 2>/dev/null || echo "/tmp/sb-install.$$")
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT INT TERM

tag=""
asset=""
from=""
why=""
# which source answered the version question: the same one gets first call for
# the bytes, so a reader who had to ask cnb.cool does not then sit through a
# stalled github.com download before falling back to it anyway.
asked=""

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

# Which version is newest, asked of the source we are allowed to use. GitHub's
# answer comes from a redirect on github.com; CNB's from a VERSION file it
# serves as a release asset. Either one failing just means we ask the other.
ask_tag() { # ask_tag github|cnb
	case $1 in
	github) gh_tag ;;
	cnb) cnb_tag ;;
	esac
}

if [ -z "$asset" ] && [ -z "$SB_VERSION" ]; then
	for src in github cnb; do
		[ "$WANT" = "$src" ] || [ "$WANT" = auto ] || continue
		t=$(ask_tag "$src" 2>/dev/null)
		if [ -n "$t" ]; then
			tag=$t
			asked=$src
			break
		fi
		why="$src could not say which release is newest${why:+; $why}"
	done
elif [ -z "$asset" ]; then
	tag=$SB_VERSION
fi

if [ -z "$asset" ] && [ -n "$tag" ]; then
	# Order the sources by whether they can actually start sending this file.
	# "Is the site up" is not the question: from the mainland github.com answers
	# the redirect that names the newest release just fine, and then delivers the
	# asset at a trickle or not at all, so a one-byte range request against the
	# real asset URL is what predicts whether a download will finish.
	fast=""
	slow=""
	for src in github cnb; do
		[ "$WANT" = "$src" ] || [ "$WANT" = auto ] || continue
		case $src in
		github) u=$(gh_asset_url "$tag") ;;
		cnb) u=$(cnb_asset_url "$tag") ;;
		esac
		if alive "$u"; then
			fast="$fast $src"
		else
			slow="$slow $src"
		fi
	done
	for src in $fast $slow; do
		[ -n "$src" ] || continue
		case $src in
		github) asset=$(gh_fetch "$tag" "$tmp" 2>/dev/null) ;;
		cnb) asset=$(cnb_fetch "$tag" "$tmp" 2>/dev/null) ;;
		esac
		if [ -n "$asset" ]; then
			from=$src
			break
		fi
		why="$src did not give the build for $os/$arch of $tag${why:+; $why}"
	done
fi

if [ -z "$asset" ]; then
	[ -n "$why" ] && say "$why"
	die "no build for $os/$arch from github.com or cnb.cool${tag:+ ($tag)}"
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
