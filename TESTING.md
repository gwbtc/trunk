# Testing trunk on the dev platform

Trunk's Hoon is tested on its own fleet set from [hoon-development](https://github.com/nisfeb/hoon-development): a fake ship built from the dev platform, never ~ricsul-bilwyt or the older trunk ships (~hec, ~nym). AGENTS.md's "Testing" section still holds; this file is how to do it on the fleet.

| | |
|---|---|
| set | `trunk` (in hoon-development's `fleet/sets.conf`) |
| ship | `~rud`, fake, pier `~/fleet/piers/rud` |
| HTTP | http://localhost:8136 |
| dojo | `tmux attach -t fleet`, window `rud` |
| platform | grubbery and `%unix`, on the stock vere 4.6 pill, which also ships `%groups` and `%landscape`. The marc check needs nisfeb/grubbery dist/single-release b126c50 or later, whose kernel marc for `%trunk-action` types the wire 19 actions. The `compiled` snapshot was built on eed73a6 (wire 18), so refresh it first. |
| `%trunk` | installed from this worktree by `scripts/fleet-deploy.sh`, wire 19 |
| test desk | `%trunk-test`, mounted, set up for the kit |

Below, `F=~/software/personal/hoon-development/fleet/fleet` and `U=~/software/personal/hoon-development/bridge/u`. Set `FLEET_WHO` to your session's name so claims know who is asking.

```sh
export PIER=~/fleet/piers/rud URL=http://localhost:8136
```

## Reset

```sh
$F reset trunk compiled   # %trunk installed, %trunk-test set up: start every test here
$F reset trunk            # golden: the platform only, no %trunk
$F ls                     # is ~rud up?
$F up trunk               # restart from the event log (vere 4.6 sometimes segfaults)
$F down trunk             # stop it when you are done
```

Refresh `compiled` after a deploy that tests should start from: `$F snap trunk compiled` (about 15 s). For a throwaway point, `$F --fast snap trunk before-x`.

## Offline tests (no ship)

```sh
scripts/offline-tests.sh                 # 6 suites, 15 tests, about 15 s
scripts/offline-tests.sh trunk-json      # one suite
python3 scripts/hoon-test-kit/offline-test.py tests/lib/trunk-jwt.hoon test-speaker   # one arm
```

The suites in `tests/lib/` run through `vere eval` with the kit's `offline-test.py`:

| suite | covers |
|---|---|
| `trunk-push`, `trunk-guest`, `mnemonym` | `gen/test-push`, `gen/test-guest` and `gen/test-mnemonym` as one test each. A failure prints the cases the generator names. The generators stay the checks of record. |
| `trunk-jwt` | two Galène tokens (speaker and listener) pinned byte for byte. Both were checked outside Hoon with Python's `hmac`: the signature verifies and the claims decode. Also `+unix-secs`. |
| `trunk-json` | `+roster-from-json`: both schema generations, the admin rules, bad keys and values skipped, unknown shapes giving `~`. |
| `grubbery-marc` | `docs/grubbery-trunk-action.hoon` nests in `action:trunk` (what trunk's `!<` needs), a case trunk lacks fails that check, and each of the six actions comes through unchanged. |

The ship run is the verdict.

## Ship tests

```sh
$F reset trunk compiled
scripts/hoon-test-kit/hoon-test.sh $PIER          # the same 15 tests on %trunk-test, about 5 s
scripts/ship-checks.sh $PIER $URL                 # 13 live checks, about 7 s
$F reset trunk compiled                           # ship-checks leaves an app on the trunk page
```

`ship-checks.sh` checks:

- `version`: `/~/scry/trunk/version.json` answers the worktree's `+wire-version`.
- `gens`: `+trunk!test-push`, `test-guest` and `test-mnemonym`, built from the ship's own `%trunk` desk as the dojo builds them, answer `%ok`. A failure prints the generator's answer.
- `allow`: from a thread (gall's `%spider`, so "another agent"): `%set-call-mode` and `%app-hosting` are refused (the nack's trace is the allowlist's `?>` in `+on-poke`), a first `%app-room-open-as` registers `spider/probe` switched off with no room, the owner switches it on through `/apps/trunk/action`, then an open makes the room and a close removes it. Each step is read back from `/x/guests`.
- `marc`: grubbery's `/code/mar/clay/trunk/trunk-action.hoon` on the ship is `docs/grubbery-trunk-action.hoon`, header comment aside. It reads the file with hoon-development's `bridge/u` and skips without it.

Every read is guarded by a `%cu` scry first: on vere 4.6 a `.^` that misses cancels every thread on the ship. The owner's cookie comes from the kit's `ship-cookie.sh` over `conn.sock` and is never printed.

## Deploying a change

```sh
scripts/fleet-deploy.sh $PIER $URL                # copy app lib mar sur gen and |commit %trunk
scripts/fleet-deploy.sh $PIER $URL --test-desk    # also make %trunk-test and run the kit's setup
```

The first run on a ship does the main README's "The desk" in the ship's dojo: it mounts `%base` and `%landscape`, makes and mounts `%trunk`, copies the desk and the files it borrows, takes `sys.kelvin` from the ship's `%base`, commits, installs and waits for `version.json` to answer the worktree's wire. Later runs copy and commit, and wait the same way. `|commit` does not delete a file: remove one from the mount with `|rm`. The script refuses a pier outside `~/fleet/piers` and a URL that is not localhost.

To test an upgrade (AGENTS.md, "Test the upgrade"), check out the released commit in a scratch worktree, deploy it from there onto `golden`, give it state, then deploy this branch and check the state came through.

## Inspecting the ship

```sh
$U trunk 'our'                                         # ~rud
$U trunk kids /code/mar/clay/trunk                     # grubbery's trunk marcs
$U trunk file /code/mar/clay/trunk/trunk-action.hoon   # the marc itself
$U trunk '.^(? %gu /(scot %p our)/trunk/(scot %da now)/$)'   # is %trunk running
```

Over HTTP with the owner's cookie: `/~/scry/trunk/version.json`, `debug.json`, `guests.json`, `policy.json`, and the page at `/apps/trunk`. Check a path with `%cu` or `%gu` before any `.^` of your own.

## Not on this set

- The browser checks (`test/browser/`) need a local Galène 1.1, which this machine does not have. Build one as `test/browser/README.md` says, point `~rud` at it with `%set-sfu`, and add `http://localhost:8136` to its `allowOrigin`.
- Push end to end (DMs and channel posts between two ships, `%activity` reads, rings) needs a second ship in the set and a local HTTP listener as the device's endpoint.
- A real grubbery app calling trunk through the kernel. `grubbery-marc` and the `marc` check cover the marc, and the `allow` check covers trunk's side of the `-as` actions from another agent. A grubbery nexus that pokes `%trunk` and watches `/app/grubbery/<name>` would close the gap.
- App guest tickets: they need an SFU (`%set-sfu`), which the set has none of.
