#!/usr/bin/env bash
# fleet-deploy.sh: install or update %trunk on a fake ship of a fleet set
# (hoon-development's fleet: ships in tmux session `fleet`, piers under
# ~/fleet/piers). See TESTING.md.
#
#   scripts/fleet-deploy.sh <pier> <url> [--test-desk]
#   scripts/fleet-deploy.sh ~/fleet/piers/rud http://localhost:8136 --test-desk
#
# First run on a ship (no %trunk desk): the README's "The desk" steps,
# typed into the ship's dojo. |mount %base and %landscape, |new-desk and
# |mount %trunk, copy the desk's files and the ones it borrows from
# %base and %landscape, take sys.kelvin from the ship's %base, |commit
# %trunk and |install our %trunk, then wait for /~/scry/trunk/version.json.
# Later runs copy the desk's own files again and |commit %trunk. |commit
# does not delete: remove a file from the mount with |rm.
#   --test-desk  make and mount %trunk-test, then hoon-test.sh setup
#
# Refuses a pier outside ~/fleet/piers and a URL that is not localhost,
# so it never writes to ~ricsul-bilwyt or the older trunk ships.
set -euo pipefail
cd "$(dirname "$0")/.."
die() { echo "fleet-deploy: $*" >&2; exit 1; }
(($# >= 2)) || { sed -n '2,19p' "$0"; exit 2; }
pier=${1%/} url=${2%/}; shift 2
testdesk=''
for a in "$@"; do
  case "$a" in
    --test-desk) testdesk=1 ;;
    *) die "unknown option $a" ;;
  esac
done
[[ "$(cd "$pier" 2>/dev/null && pwd -P)" == "$HOME"/fleet/piers/* ]] || die "$pier is not a fleet pier"
[[ "$url" =~ ^http://(localhost|127\.0\.0\.1):[0-9]+$ ]] || die "$url is not localhost"
[[ -S "$pier/.urb/conn.sock" ]] || die "the ship at $pier is not running (fleet up <set>)"
ship=$(basename "$pier")
session=${FLEET_SESSION:-fleet}
VERE=${VERE:-$(ls -d "$HOME"/software/vere-*-linux-x86_64 | sort -V | tail -1)}
export VERE

dojo() { # type one line into the ship's dojo
  tmux list-windows -t "=$session" -F '#W' | grep -qx "$ship" || die "no tmux window $session:$ship"
  tmux send-keys -t "=$session:$ship" -l "$1"
  tmux send-keys -t "=$session:$ship" Enter
}
mounted() { # desk [new]: mount it (|new-desk first if new) unless it is
  local i
  [[ -f "$pier/$1/sys.kelvin" ]] && return 0
  [[ -n "${2:-}" ]] && dojo "|new-desk %$1"
  for ((i = 0; i < 120; i++)); do
    # |mount answers an error until the desk exists: ask again every 10 s
    ((i % 10 == 2 || i == 0)) && dojo "|mount %$1"
    [[ -f "$pier/$1/sys.kelvin" ]] && { echo "  %$1 mounted"; return 0; }
    sleep 1
  done
  die "%$1 did not appear at $pier/$1"
}
khan() { # one-line thread -> its result line
  printf '%s\n' "[0 %fyrd [%base %khan-eval %noun [%ted-eval '$1']]]" |
    "$VERE" eval --jam -n 2>/dev/null |
    socat -T 60 -,ignoreeof UNIX-CONNECT:"$pier/.urb/conn.sock" 2>/dev/null |
    "$VERE" eval --cue -n 2>/dev/null | tail -1
}
# 0 once clay's %trunk has this file with these bytes: its sha-256,
# compared on the ship (a %cx read guarded by %cu, which always
# answers, so a missing file never blocks)
landed() {
  local f=$1 want
  want=$(python3 -I -c '
import hashlib, sys
h = format(int.from_bytes(hashlib.sha256(open(sys.argv[1], "rb").read()).digest(), "little"), "x")
h = h.lstrip("0") or "0"
g = []
while h:
    g.insert(0, h[-4:]); h = h[:-4]
print("0x" + ".".join(g))' "$f")
  local p="/${f%.*}/${f##*.}"
  khan "=/  m  (strand ,vase)  ;<  =bowl  bind:m  get-bowl  =/  b=path  /(scot %p our.bowl)/trunk/(scot %da now.bowl)  =/  p=path  (weld b (stab (crip \"$p\")))  ?.  .^(? %cu p)  (pure:m !>(%missing))  (pure:m !>(=((shax .^(@ %cx p)) $want)))" |
    grep -q '%noun 0\]$'
}
version() { # the wire trunk answers, or nothing
  local jar; jar=$(mktemp); trap 'rm -f "$jar"' RETURN
  scripts/hoon-test-kit/ship-cookie.sh "$pier" "$url" "$jar" >/dev/null 2>&1 || return 0
  curl -s -m 10 -b "$jar" "$url/~/scry/trunk/version.json" 2>/dev/null |
    python3 -I -c 'import sys,json; print(json.load(sys.stdin)["wire"])' 2>/dev/null || true
}
copy() { # the desk's own files, as the README's cp line; prints those that changed
  rsync -ai app lib mar sur gen desk.bill desk.docket-0 "$pier/trunk/" | awk '$1 ~ /^>f/ {print $2}'
}
# 0 when clay builds the agent as the desk now stands. A file can land
# and still fail to compile, and the old agent would then answer every
# check after this one.
builds() {
  khan "=/  m  (strand ,vase)  ;<  =bowl  bind:m  get-bowl  =/  p=path  /(scot %p our.bowl)/trunk/(scot %da now.bowl)/app/trunk/hoon  =/  v  .^(vase %ca p)  (pure:m !>(&))" |
    grep -q '%noun 0\]$'
}

if [[ -f "$pier/trunk/app/trunk.hoon" ]]; then
  echo "== update %trunk on ~$ship"
  changed=$(copy)
  dojo "|commit %trunk"
  # every changed file, not just the agent: a change to lib/ or a page
  # alone leaves app/trunk.hoon landed before the commit does
  for f in ${changed:-app/trunk.hoon}; do
    for ((i = 0; i < 60; i++)); do landed "$f" && break; sleep 2; done
    landed "$f" || die "|commit %trunk did not land $f; read the dojo (tmux attach -t $session)"
  done
  builds || die "app/trunk.hoon does not build on ~$ship; read the dojo (tmux attach -t $session)"
  echo "  committed"
  # a first run stopped before |install leaves the desk without the agent
  [[ -n "$(version)" ]] || dojo "|install our %trunk"
else
  echo "== first install of %trunk on ~$ship"
  mounted base
  mounted landscape
  mounted trunk new
  copy >/dev/null
  install -m 644 "$pier"/base/lib/{default-agent,skeleton}.hoon "$pier/trunk/lib/"
  for m in bill css hoon html js kelvin mime noun svg txt; do
    install -m 644 "$pier/base/mar/$m.hoon" "$pier/trunk/mar/"
  done
  install -m 644 "$pier/landscape/mar/docket-0.hoon" "$pier/trunk/mar/"
  install -m 644 "$pier/landscape/lib/docket.hoon" "$pier/trunk/lib/"
  install -m 644 "$pier/landscape/sur/docket.hoon" "$pier/trunk/sur/"
  # the ship's own kelvin, not the checked-in one
  install -m 644 "$pier/base/sys.kelvin" "$pier/trunk/sys.kelvin"
  dojo "|commit %trunk"
  for ((i = 0; i < 60; i++)); do landed app/trunk.hoon && break; sleep 2; done
  landed app/trunk.hoon || die "|commit %trunk did not land; read the dojo (tmux attach -t $session)"
  builds || die "app/trunk.hoon does not build on ~$ship; read the dojo (tmux attach -t $session)"
  echo "  committed"
  dojo "|install our %trunk"
fi
# a compile that hangs needs a person at the dojo: report it, never retry
want=$(grep -oE '\+\+  wire-version  [0-9]+' app/trunk.hoon | grep -oE '[0-9]+$' || true)
for ((i = 0; i < 60; i++)); do
  v=$(version); [[ -n "$v" && ( -z "$want" || "$v" == "$want" ) ]] && break; sleep 5
done
[[ -n "$v" ]] || die "/~/scry/trunk/version.json did not answer in 5 min; read the dojo (tmux attach -t $session)"
[[ -z "$want" || "$v" == "$want" ]] || die "trunk answers wire $v, the worktree is $want"
echo "  trunk answers wire $v"

if [[ -n "$testdesk" ]]; then
  echo "== test desk %trunk-test"
  mounted trunk-test new
  scripts/hoon-test-kit/hoon-test.sh "$pier" setup
fi
