#!/usr/bin/env bash
# ship-checks.sh: the live checks for %trunk on a fleet ship, after
# scripts/fleet-deploy.sh. See TESTING.md.
#
#   scripts/ship-checks.sh <pier> <url>
#   scripts/ship-checks.sh ~/fleet/piers/rud http://localhost:8136
#
#   version  /~/scry/trunk/version.json answers the worktree's wire
#   gens     +trunk!test-push, test-guest and test-mnemonym, built from
#            the ship's %trunk desk as the dojo would, answer %ok
#   allow    another agent (spider, from a thread) may open, use and
#            close its own app room, which then shows in /x/guests as
#            spider/<name>, switched off; it may not change a setting
#            (AGENTS.md, "Security invariants")
#   marc     grubbery's kernel marc for %trunk-action on the ship is
#            docs/grubbery-trunk-action.hoon (needs hoon-development's
#            bridge/u; tests/lib/grubbery-marc.hoon checks the file
#            nests in action:trunk)
#
# The allow check leaves an app (spider/probe) on the trunk page with
# no rooms, so run it on a ship you reset afterwards (fleet reset <set>
# compiled). Each read is guarded by a %cu scry first: a .^ that misses
# on vere 4.6 cancels every thread on the ship. Exit 0 all passed, 1 a
# check failed, 2 the ship did not answer.
set -uo pipefail
cd "$(dirname "$0")/.."
(($# == 2)) || { sed -n '2,26p' "$0"; exit 2; }
pier=${1%/} url=${2%/}
[[ "$(cd "$pier" 2>/dev/null && pwd -P)" == "$HOME"/fleet/piers/* ]] || { echo "$pier is not a fleet pier" >&2; exit 2; }
[[ "$url" =~ ^http://(localhost|127\.0\.0\.1):[0-9]+$ ]] || { echo "$url is not localhost" >&2; exit 2; }
[[ -S "$pier/.urb/conn.sock" ]] || { echo "the ship at $pier is not running" >&2; exit 2; }
VERE=${VERE:-$(ls -d "$HOME"/software/vere-*-linux-x86_64 | sort -V | tail -1)}
U=${U:-$HOME/software/personal/hoon-development/bridge/u}
export VERE
fails=0 n=0
ok() { n=$((n + 1)); echo "ok    $*"; }
bad() { n=$((n + 1)); fails=$((fails + 1)); echo "FAIL  $*"; }

khan() { # one-line thread -> its result line, as vere prints it
  printf '%s\n' "[0 %fyrd [%base %khan-eval %noun [%ted-eval '$1']]]" |
    "$VERE" eval --jam -n 2>/dev/null |
    socat -T 120 -,ignoreeof UNIX-CONNECT:"$pier/.urb/conn.sock" 2>/dev/null |
    "$VERE" eval --cue -n 2>/dev/null | tail -1
}
HEAD='=/  m  (strand ,vase)  ;<  =bowl  bind:m  get-bowl  =/  b=path  /(scot %p our.bowl)/trunk/(scot %da now.bowl)  '
# a file of %trunk built to a vase, as the dojo builds +trunk!x: %cu first
built() { # var path
  echo "=/  p=path  (weld b $2)  ?.  .^(? %cu p)  (pure:m !>(%missing))  =/  $1  .^(vase %ca p)  "
}
# poke %trunk from this thread with an action typed by the ship's sur/trunk
poke() { # action (no quotes)
  khan "$HEAD$(built s /sur/trunk/hoon)=/  v  (slap s (ream (crip \"\`action\`$1\")))  ;<  ~  bind:m  (poke [our.bowl %trunk] [%trunk-action v])  (pure:m !>(%acked))"
}
scry() { # /x/<name> as JSON text, through the owner's session
  local jar; jar=$(mktemp); trap 'rm -f "$jar"' RETURN
  scripts/hoon-test-kit/ship-cookie.sh "$pier" "$url" "$jar" >/dev/null 2>&1 || return 0
  curl -s -m 10 -b "$jar" "$url/~/scry/trunk/$1.json"
}

# version
want=$(grep -oE '^\+\+  wire-version  [0-9]+' app/trunk.hoon | grep -oE '[0-9]+$')
got=$(scry version | python3 -I -c 'import sys,json; print(json.load(sys.stdin)["wire"])' 2>/dev/null)
[[ -n "$got" ]] || { echo "trunk did not answer /~/scry/trunk/version.json at $url" >&2; exit 2; }
[[ "$got" == "$want" ]] && ok "version: wire $got" || bad "version: wire $got, the worktree is $want"

# gens
for g in push guest mnemonym; do
  out=$(khan "$HEAD$(built g /gen/test-$g/hoon)=/  r  (slot 3 (slam (slot 3 g) !>(~)))  (pure:m !>(=(%ok q.r)))")
  if [[ "$out" == *'%noun 0]' ]]; then ok "gens: +trunk!test-$g %ok"
  else
    bad "gens: +trunk!test-$g: ${out:0:200}"
    khan "$HEAD$(built g /gen/test-$g/hoon)(pure:m !>((crip ~(ram re (sell (slot 3 (slam (slot 3 g) !>(~))))))))" | cut -c1-2000
  fi
done

# allow
acked() { [[ "$1" == '[0 %avow 0 %noun'* && "$1" != *poke-fail* ]]; }
refused() { [[ "$1" == *poke-fail* ]]; }
owner() { # one trunk action as JSON, through the owner's page route
  local jar; jar=$(mktemp); trap 'rm -f "$jar"' RETURN
  scripts/hoon-test-kit/ship-cookie.sh "$pier" "$url" "$jar" >/dev/null 2>&1 || return 1
  curl -s -m 10 -o /dev/null -w '%{http_code}' -b "$jar" -H 'Content-Type: application/json' \
    -X POST --data "$1" "$url/apps/trunk/action"
}
probe() { # spider/probe in /x/guests: "<allowed> <rooms>", or none
  scry guests | python3 -I -c '
import sys, json
for a in json.load(sys.stdin)["apps"]:
    if a["agent"] == "spider/probe":
        print(str(a["allowed"]).lower(), ",".join(a["rooms"]) or "-")
        break
else:
    print("none")' 2>/dev/null
}
is() { # what want check
  [[ "$1" == "$2" ]] && ok "allow: $3" || bad "allow: $3: spider/probe is '$1', not '$2'"
}
out=$(poke '[%set-call-mode %allow]')
refused "$out" && ok "allow: another agent may not set the call mode" ||
  bad "allow: %set-call-mode from another agent: ${out:0:200}"
out=$(poke '[%app-hosting `@t`(rap 3 ~[%spider 47 %probe]) &]')
refused "$out" && ok "allow: another agent may not switch an app on" ||
  bad "allow: %app-hosting from another agent: ${out:0:200}"
is "$(probe)" none "no app before the first open"
out=$(poke '[%app-room-open-as %probe %party]')
acked "$out" && ok "allow: another agent's first open is taken" ||
  bad "allow: %app-room-open-as from another agent: ${out:0:200}"
is "$(probe)" "false -" "the first open shows spider/probe switched off, with no room"
code=$(owner '{"app-hosting":{"agent":"spider/probe","allow":true}}')
[[ "$code" == 2* ]] && ok "allow: the owner switches spider/probe on ($code)" ||
  bad "allow: the owner's app-hosting answered ${code:-nothing}"
out=$(poke '[%app-room-open-as %probe %party]')
acked "$out" || bad "allow: the second open: ${out:0:200}"
is "$(probe)" "true party" "switched on, the open makes room party"
out=$(poke '[%app-room-close-as %probe %party]')
acked "$out" || bad "allow: the close: ${out:0:200}"
is "$(probe)" "true -" "the close removes it"

# marc (the header comment may differ: it says where the copy came from)
code_of() { grep -v '^ *::' | sed '/^$/d'; }
if [[ -x "$U" ]]; then
  set_of=$(python3 -I -c '
import os, sys
pier = os.path.realpath(sys.argv[1]); home = os.path.expanduser("~")
for line in open(sys.argv[2]):
    f = line.split()
    if not f or f[0].startswith("#") or len(f) < 4: continue
    for s in f[3:]:
        if "=" in s: continue
        if os.path.realpath(os.path.join(home, "fleet/piers", s)) == pier:
            print(f"{f[0]}:{s}"); sys.exit()' "$pier" "$(dirname "$U")/../fleet/sets.conf")
  p=/code/mar/clay/trunk/trunk-action.hoon
  if have=$("$U" "$set_of" file "$p" 2>&1); then
    if [[ "$(code_of <<<"$have")" == "$(code_of < docs/grubbery-trunk-action.hoon)" ]]; then
      ok "marc: grubbery's $p is docs/grubbery-trunk-action.hoon"
    else bad "marc: grubbery's $p differs from docs/grubbery-trunk-action.hoon"; fi
  else
    echo "skip  marc: $p: ${have:0:200}"
  fi
else
  echo "skip  marc: no bridge/u at $U"
fi

echo "ship-checks: $((n - fails)) of $n passed"
((fails == 0))
