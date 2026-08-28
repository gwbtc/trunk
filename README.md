# Trunk

Voice calls and party lines over Urbit.

`%trunk` is a Gall agent that does signalling and nothing else. It
routes opaque SDP between ships for 1:1 calls, and for party lines it
mints short-lived, room-scoped tokens for an SFU. It never sees media
and never parses SDP. Its whole job is the trust boundary: local-only
actions, and a signal's sender is the cryptographic ames source, never
a claim in the payload.

The client is separate. [Talon](https://github.com/nisfeb/talon) is one;
the agent knows nothing about it, or about Tlon groups, or about
anything above the wire.

## What's here

```
app/ lib/ mar/ sur/ gen/   the %trunk desk, laid out for a clay mount
sidecar/                   coturn + Galène, and the listen page
docs/design.md             how it works and why
```

## The desk

**It is not self-contained.** Installing needs `default-agent`, `dbug`
and `skeleton` from `%base`, plus the `bill`, `hoon`, `kelvin`, `mime`,
`noun` and `txt` marks. That list is from a working install, not from
memory; a missing mark fails the commit with a mark error rather than
anything helpful.

```dojo
|mount %base
|new-desk %trunk
|mount %trunk
```

```bash
PIER=/path/to/your/pier
cp -r app lib mar sur gen desk.bill "$PIER/trunk/"
cp "$PIER"/base/lib/{dbug,default-agent,skeleton}.hoon      "$PIER/trunk/lib/"
cp "$PIER"/base/mar/{bill,hoon,kelvin,mime,noun,txt}.hoon   "$PIER/trunk/mar/"
# Take the kelvin from YOUR ship. The checked-in one matches whatever
# it was last developed against; a ship on a different one refuses.
cp "$PIER/base/sys.kelvin" "$PIER/trunk/sys.kelvin"
```

```dojo
|commit %trunk
|install our %trunk
```

Both ends of a call need the desk. Read the current settings with
`=dir /=trunk=` then `+trunk/policy`, or over HTTP at
`/~/scry/trunk/policy.json` (eyre supplies the `%x` care itself — do
not put it in the path).

## Who may ring you

```
+$  call-mode  ?(%open %allow)
+$  policy  [mode=call-mode allow=(set ship) block=(set ship)]
```

Enforced in the agent, deliberately. A filter in the client still lets
the poke land, still rings the ship's other clients, and does nothing
at all for a second app sharing the agent.

```dojo
:trunk &trunk-action [%set-call-mode %allow]
:trunk &trunk-action [%allow ~zod]
:trunk &trunk-action [%block ~bus]
```

A refused caller gets **silence**, not a rejection: a rejection would
confirm the ship is live and filtering, and tell a blocked caller they
were blocked. Their ring watchdog gives up on its own, which is what
an offline ship looks like.

The mode gates rings only. Offer, accept and hangup pass even from a
ship the mode would refuse, because *you* may have called *them* — a
client ignores any signal whose call id it doesn't recognise. A block
is total.

## Party lines

One line per group, hosted by one ship, running on an SFU. The host
mints a per-member, per-room token; membership is the whole check.

Rooms carry the two things their admins decide:

```
+$ room  [title=@t members=(set ship) admins=(set ship)
          listen=? sfu=(unit sfu-config)]
```

`admins` is just "ships that may reconfigure this room" — the agent has
no idea what a group is. A client seeds it from whatever roster it has.
`sfu` overrides the ship's own sidecar, so a group needn't route its
audio through the host's server.

**Anonymous listening** mints a token with no `present` permission —
Galène's listener, receives and cannot publish. It is off unless asked
for: a party line is otherwise gated by the host's membership list, and
a public link deliberately punches through that. The link cannot be
revoked (Galène's tokens are stateless), so its TTL is the entire
security model and the agent caps it at an hour.

## The sidecar

See [`sidecar/`](sidecar/). Galène for party lines, coturn for the
hostile-NAT fallback on 1:1 calls, and `sidecar/listen/index.html` —
Trunk's own one-button listen page.

That page exists because Galène's own client is a video-conferencing
UI: it only displays a remote stream when a track is `kind === 'video'`,
so an audio-only line renders no tile at all, and a tab nobody clicked
cannot autoplay. Getting sound out of it took a settings panel and a
play button. The listen page instead takes the click as both the
autoplay gesture and the connect, and offers nothing a listener can't
use.

## History

Trunk was developed inside the Talon repository and split out once it
worked. Commits before this repo's first are in
[nisfeb/talon](https://github.com/nisfeb/talon), under `urbit/trunk`
and `sidecar`.
