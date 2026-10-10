# Trunkline — calls and party lines over Urbit

1:1 voice calls and multi-party "party lines" between ships. WebRTC
carries the audio; ames carries the signaling, so a call is addressed
to a `@p` and authenticated by the network rather than by a phone
number or an account. Design rationale lives in the Trunkline design
doc; this file is how it actually fits together and how to run it.

## Architecture

```
===============================================================
 1:1 CALL          signaling rides ames; media never does
===============================================================

  CALLER DEVICE                              CALLEE DEVICE
  +----------------------+           +----------------------+
  | Talon                |           | Talon                |
  |  CallController      |           |  CallController      |
  |  CallEngine(libwebrtc)           |  CallEngine          |
  +----------+-----------+           +-----------+----------+
             |                                   ^
   (0) scry /x/ice                        (3) eyre SSE fact
       -> STUN/TURN this ship                  on /calls
          advertises                        [%recv ~zod sig]
             |                                   |
   (1) eyre poke                                 |
       %trunk-action                             |
       [%send ~nec sig]                          |
             v                                   |
  +----------------------+           +-----------+----------+
  | ~zod   DESK: %trunk  |    (2)    | ~nec   DESK: %trunk  |
  |   app/trunk.hoon     |   ames    |   app/trunk.hoon     |
  |   sur/ lib/ mar/     +---------->+                      |
  +----------------------+  mark:    +----------------------+
                          %trunk-signal
                    [%ring][%offer sdp fpr]
                    [%accept][%reject][%hangup]

  MEDIA - direct, the agent never sees it
     caller <====== DTLS-SRTP (ICE) ======> callee
       Tier 0  host candidates (same LAN, public IPv6)
       Tier 1  reflexive addr via sidecar STUN
       Tier 2  relayed by coturn  <- the relay sees ciphertext
                                     only, so the call stays
                                     end-to-end encrypted
```

```
===============================================================
 PARTY LINE        host's ship authorizes; host's SFU mixes
===============================================================

  HOST DEVICE                                MEMBER DEVICE
  +----------------------+           +----------------------+
  | Talon                |           | Talon                |
  |  PartyLineHost       |           |  PartyLine           |
  +----------+-----------+           +-----------+----------+
        |    |                                   ^
   (1) scry %groups  DESK: groups                 |
       /v2/groups/<flag>                          |
       -> roster = who may join                   |
        |                                         |
   (2) eyre poke %trunk-action            (6) eyre SSE fact
       [%open-room name title members]           /calls
        v                                   [%ticket loc tok]
  +----------------------+           +-----------+----------+
  | ~zod   DESK: %trunk  |    (3)    | ~nec   DESK: %trunk  |
  |  app/trunk.hoon      |   ames    |  app/trunk.hoon      |
  |  lib/trunk-jwt.hoon  +---------->+                      |
  |                      | %trunk-room                      |
  |                      | [%announce name title]           |
  |                      |           |                      |
  |                      +<----------+ (4) [%ask name]      |
  |  checks membership   |           |                      |
  |  mints HS256 JWT     +---------->+ (5) [%grant ticket]  |
  +----------------------+           +----------------------+
     (host joining its own room skips 3-5 entirely)

  MEDIA - a star, not a mesh
     host   --- GET <loc>/.status, then wss ---> +-----------+
     member --- GET <loc>/.status, then wss ---> |  Galene   |
                one outbound conn each,          |  SFU      |
                so NAT never enters              | (sidecar) |
                                                 +-----------+
     ticket = JWT scoped to  talon/<host>-<room>, 6h expiry
     Galene has a public address -> no ICE config
     SFU terminates DTLS -> host's machine hears plaintext,
     the same trust boundary as it already storing the posts
```

**Desks.** `%trunk` is the desk this project adds — agent, types, marks,
and the JWT lib — and it must be installed on **both** ships; a peer
without it nacks the relay and the caller sees "unreachable". `groups`
is Tlon's existing desk, read-only here and only on the host side, to
answer "who is allowed on this line".

**Transports.** Device to its own ship is always eyre: pokes up, SSE
facts down. Ship to ship is always ames, so `src` is cryptographically
the sending ship and a signal cannot lie about who it is from. Galène
and coturn are plain Unix daemons on the ship's host machine — not
desks, not part of Urbit.

**The asymmetry worth remembering.** In 1:1 the agent is a dumb relay
and the two devices negotiate directly, so nothing in the middle can
hear the call. In a party line the host's ship is a real authority: it
decides membership and signs the tickets, and its SFU necessarily hears
the audio in order to mix it.

## What the sidecar is actually for

Two services, needed at different times, both optional:

- **Galène (SFU)** — required to *host* a party line. There is no
  peer-to-peer fallback for group audio; without it, party lines do not
  exist. Joining someone else's line needs nothing locally.
- **coturn (STUN/TURN)** — only for 1:1 calls with no direct path.
  Same-LAN calls never touch it (Tier 0 finds a route). Phone-on-cellular
  to desktop-at-home usually does need it: carrier-grade NAT on one side,
  a home router on the other. Expect roughly 10-20% of real-world pairs,
  disproportionately mobile.

Galène has a public address, which is why party lines need no ICE
configuration at all. It also ships its own TURN server, but the
sidecar runs it with `-turn ''`: that server relays to any address, the
host's loopback included, and hands its password to everyone who
joins, guests too. That raises the obvious question of why coturn exists rather than relaying
1:1 calls through Galène too — the answer is that an SFU terminates
DTLS and re-encrypts per listener, so it would hear the call. A TURN
relay only forwards packets it cannot read. Keeping coturn is what lets
1:1 calls stay end-to-end while party lines are honest about the host
hearing them.

One sidecar anywhere between two callers covers that call, so running
one upgrades every call made *to* you.

## Pieces

- The `%trunk` desk, at this repo's root. `app/trunk.hoon` routes signals, mints room tickets, sends push hints and serves the owner's page (`app/trunk/page.html`, with the tile's `icon.svg`) and the public guest page (`app/trunk/guest.html`). `lib/trunk-jwt.hoon` signs the Galène JWTs. `lib/trunk-push.hoon` decides what wakes a phone and builds the bytes that do it. `lib/trunk-guest.hoon` decides who a guest link seats; [`docs/guest-seats.md`](guest-seats.md) has the design. `lib/trunk-json.hoon` is the wire's source of truth. `mar/trunk/*` are the eyre-facing and ship-to-ship marks. The desk is not self-contained: the README's "The desk" lists what to copy from `%base` and `%landscape`.
- `sidecar/`: compose file and setup for coturn + Galène, and the listen page.
- `gen/trunk/policy.hoon`: a dojo read-out of the call policy, which
  the trunk page does not show.

Talon's side, in nisfeb/talon:

- `call/TrunkWire.kt` — JSON wire, mirrors `lib/trunk-json.hoon`.
- `call/CallController.kt` — 1:1 signaling state machine + metrics.
- `call/CallEngine.kt` + platform engines — the 1:1 media half
  (webrtc-java on desktop, libwebrtc on Android).
- `call/PartyLine.kt` — Galène's WebSocket protocol; `call/PeerLink.kt`
  + platform impls are the per-stream, trickling media primitive.
- `call/PartyLineHost.kt` — maps a channel to `(host, room)` so every
  member derives the same line with no shared state.
- UI: call button and `/call` in a DM, party-line button in a group
  channel, `CallOverlay` (ring / in-call banner) and `PartyLineBar`.

## Who may ring you

`%trunk` carries a ship-level call policy. It is enforced in the agent,
not in Talon, and that placement is the whole point: a client-side
filter still lets the poke land, still rings the ship's *other*
clients, and does nothing at all for a second app sharing the agent.

```
+$  call-mode  ?(%open %allow)
+$  policy  [mode=call-mode allow=(set ship) block=(set ship)]
```

- `%open` — anyone may ring, except ships in `block`.
- `%allow` — only ships in `allow` may ring.
- `block` always applies, and outranks `allow`: blocking a ship also
  drops it from the allow list, so the two can never disagree.
- A block also refuses party-line tickets and drops room announcements
  from that ship.

The mode gates **rings only**. Offer, accept and hangup pass even from
a ship the mode would refuse, because you may have called *them* —
gating every inbound signal on the allow list would drop your own
callee's answer and break every outgoing call to someone not already
on your list. That is safe because a client ignores any signal whose
call id it doesn't recognise. A **block** is total: nothing from that
ship reaches your clients at all.

A refused caller gets **silence**, not a rejection. A rejection would
confirm to a stranger that the ship is live and filtering, and would
tell a blocked caller they were blocked; instead their ring watchdog
times out, which is what an offline ship looks like.

Both a fresh install and an upgrade start `%open` with empty lists, so
neither installing nor upgrading ever silently starts refusing calls.

Assign `open-policy` explicitly in `on-init` — never lean on the bunt
of `+$ policy`. `?(%open %allow)` bunts to `%allow`, the *last* case,
so a bare `` `this `` in `on-init` brought every newly installed ship
up in allow-mode with an empty allow set: it refused every caller, and
refusal is silent, so neither side saw an error. Every test ship was
an upgrade, so nothing caught it until a real install did.

Deliberately, the agent knows nothing about `%contacts`. Making
"contacts only" work by scrying Tlon's agent would make shared
infrastructure depend on the Tlon suite; a client that wants that
behaviour keeps the allow set in sync itself.

### Reading and editing it

The call policy has no UI in `%trunk`. The trunk page (wire 12) covers push notifications and their debugging, not who may ring. Talon renders the policy under Settings, "Who can call you". Outside Talon:

```dojo
::  read
=dir /=trunk=
+trunk/policy

::  write
:trunk &trunk-action [%set-call-mode %allow]
:trunk &trunk-action [%allow ~zod]
:trunk &trunk-action [%block ~bus]
:trunk &trunk-action [%unblock ~bus]
```

Over HTTP the scry is `/~/scry/trunk/policy.json` (eyre supplies the
`%x` care itself — do not put it in the path).

Every edit echoes the whole policy back on `/calls` as a `%policy`
fact, so a ship's other devices converge without re-scrying.

## Making the phone actually ring

A ring only reaches a sleeping device if three things line up.

1. **`%trunk` emits it.** A `%recv` fact with a `%ring` sig on `/calls`.
   Policy is enforced before this point, so a blocked or unlisted
   caller never produces a fact and never wakes anyone.
2. **`%trunk` pushes a hint.** Since wire 11 the ship does it itself: on the ring it POSTs `{"event":"ring","patp","from","id"}` to each registered UnifiedPush endpoint, and asks the APNs gateway for a VoIP push to each iPhone. Hint-only, like messages: no SDP or fingerprint leaves the ship. Before wire 11 Talon's off-ship relay did this, subscribed to `/calls` with the user's session, and measured 64 to 136 ms from ring to push against live ships. See "Push from the ship" below.
3. **The phone rings.** On Android, `TalonMessagingReceiver` routes `event == "ring"`
   to a `CATEGORY_CALL` notification on its own channel — the system
   ringtone stream, not the notification blip — with a full-screen
   intent so it takes over a locked screen, and `CallStyle` on API 31+.

Answering opens the app rather than answering in place: the media
negotiation lives in `CallController`, which needs the app running and
its channel up. Declining works from the notification alone, because a
decline is one poke and needs no media (`CallActionReceiver`).

The notification is cancelled as soon as the controller leaves
`Incoming` — answered, declined, or the caller gave up.

### What this does not cover yet

- **Process death.** The push wakes the receiver and rings, but
  `CallController` is still created inside the Compose tree, so a cold
  app has no signaling channel until the user opens it. Answering
  therefore costs a launch. Moving the controller into
  `TalonSyncService` is the fix.
- **The distributor leg.** ship to distributor to device depends on which UnifiedPush distributor the user runs, and can only be measured on a real handset.

On iOS a ring arrives as a PushKit VoIP push, which Talon reports to CallKit at once, as Apple requires.

## Push from the ship (wire 11 to 15)

Until wire 11 a suspended phone heard its ship only through Talon's off-ship relay, which logged in with the user's `+code`, kept a session cookie, and decided on its own what was worth a notification. Now `%trunk` does all of that on the ship, and the only thing left off it is the one thing a ship cannot do: sign an iPhone's push with Apple's key. Iris speaks neither HTTP/2 nor ES256, and the key cannot be handed to a ship, since whoever holds it can push to any Talon iPhone. So a small Nisfeb gateway maps a device's handle to its APNs tokens and signs, and nothing more.

- **Where events come from.** The agent watches its own `%activity`, at `/v4` for new posts and the badge count, and at `/v4/reads` for reads, which `%activity` gives only there. Each fact is turned into JSON through `%activity`'s own desk, the conversion eyre ran for the relay, so trunk never casts Tlon's types and rides out their mark bumps. Rings come from trunk itself.
- **What notifies.** A post or reply `%activity` marks notified, then the owner's switches on the trunk page, then Talon's per-chat level from `%settings`. A channel with no level of its own takes its group's (wire 15), and a chat with neither is at "mentions", which is Talon's default, so a channel post with no mention stays quiet unless the user sets that channel, or its group, to "All messages". Posts over five minutes old never notify, and none twice.
- **Who gets what.** Each device declares what it understands in `caps` ("read", "notice", "badge"). An app that never said it understands a kind never gets it, because an older app shows any push it does not know as a new message.
- **Delivery.** One iris request per device. A dead endpoint (404, 410, or 401 from the gateway) drops the device, unless it registered again since the push left. Messages, reads, notices and badges get two more tries on a 5xx, a 429 or no answer. Rings never do, since they are stale in seconds.
- **Other apps.** Any agent on the ship can send a notice (wire 12). Trunk knows the sending agent from gall's `sap.bowl`, and an app behind a shared agent, as every grubbery app is, names itself (wire 14). Each app gets its own switch, one push every five seconds with the rest batched into one, and an hourly limit the owner can set per app (30 to start), so no app on the ship can flood the owner's phones. Another agent may send notices and nothing else: `+by-owner` keeps settings and devices to the owner's web session, Talon and the dojo. That stops a careless app. It cannot stop a hostile one, because gall lets an agent name any origin for its poke, and any page the ship serves posts with the owner's cookie. See `docs/notifications.md`.
- **The page.** The owner sees the switches, the apps, the devices, the `%activity` watches and a log of decisions at `/apps/trunk`, and the same data is one owner-only scry for Talon and for a user's agent. It never holds a secret, an endpoint's path or which chat a message was in.

The README has the wire: the pokes, every body a device or the gateway receives, and the debug report.

## One line per group, and the group's admins own it

A party line belongs to a **group**, not a channel. The room is derived
from the group flag `~host/slug`, so every channel in the group joins
the same line and admins enable it once. `PartyLineHost.roomForGroup`
is that mapping, and it is load-bearing for authorization, not just
naming — the host it names is the ship that mints the tickets.

**No line, no button.** The call icon in a channel is gated on a line
actually existing for its group: the client checks `/x/rooms` (lines we
host) and `/x/lines` (lines we've been invited onto), kept live by
`%open` / `%shut` facts. A group whose admins haven't turned it on
shows no party icon at all, rather than one the ship would refuse.

Turning a line on for a group hosted by *another* ship creates the
room there. There is no admin list to check yet at that point, so
creation reuses the dial that already decides who may make your ship
do work: whoever may ring you (`+may-ring`), capped by `room-cap`. Lock
your ship down and only those ships can open a line on it.

The switches live in group admin, above the member list. Only the host
and the group's admins see them; `%trunk` enforces that itself, but
showing switches that would be refused is worse than showing none.

### The default server

A build can carry a fallback sidecar, injected at build time and never
committed:

```
TALON_DEFAULT_SFU_BASE=https://your-sidecar \
TALON_DEFAULT_SFU_GROUP=talon \
TALON_DEFAULT_SFU_KEY=<secret> ./gradlew ...
```

A ship with no SFU of its own adopts it on first connect, so party
lines work with no setup. A ship that already has one is left alone.

**The key is a shared secret.** Anyone who extracts it from a build can
mint a Galène token for any room on that server, so on *that* server
the host's membership list stops being the gate. It buys "works out of
the box"; the operator's kill switch is rotating the group key, which
locks out every build carrying the old one. Groups that set their own
sidecar are unaffected either way. Per-ship provisioning is the real
fix and is not built.

### Whose server

`%set-sfu` is ship-level and stays the fallback, but a room can name
its own:

```
+$ room  [... listen=? sfu=(unit sfu-config)]
```

`~` means "the host ship's own sidecar", which is the common case. The
host's owner can put a line on another server, with `%configure-room`
from the host itself, and the host then mints the tickets against it.
A remote admin cannot: any ship that opens a line here names itself
its admin, and a server it chose would hear every member, so a remote
`%configure` keeps the line's server as it is. Reading a key back is
not part of the deal either: `/x/rooms` reports `sfu-base` and
`custom-sfu`, never a key. Guest links work only on the host's own
SFU.

## Party lines are opt-in, and so is anonymous listening

Two switches per room, both off unless someone asks for them.

```
+$ room  [title=@t members=(set ship) admins=(set ship) listen=?]
```

`admins` is just "ships that may reconfigure this room". `%trunk` never
learns what a Tlon group is — the host seeds the list from the group's
own roster when it opens the line (`PartyLineHost.startLine` gets
members and admins from one `fetchGroupAdmin` call). A group admin who
doesn't own the host ship sends `%configure-room`, which relays to the
host as a `%configure` room-sig; the host checks its own `admins` set.
So the authority model is the group's, and the enforcement is the
host's.

Enforcement stays where it already was: no open room means
`grant-cards` denies, and `listen=%.n` means no listener token is ever
minted. A client that ignores the switches still can't get a ticket.

### Anonymous listening

Galène's permissions are `op` / `present` / `message` / `caption` /
`token`. A token *without* `present` is a listener: it receives streams
and cannot publish one. `listener:trunk-jwt` grants exactly that.

**Links point at Trunk's own page, not Galène's client.** Galène's UI
is built for video conferencing: `showHideMedia` only displays a remote
stream if one of its tracks is `kind === 'video'`, and `.peer-hidden`
is `display: none` — so an audio-only party line renders *no tile at
all*. Combined with browser autoplay policy on a tab nobody clicked,
getting sound out of it took opening settings, enabling "display
audio-only", and pressing play on a panel. Hopeless for someone handed
a link.

`sidecar/listen/index.html` is a one-button page instead: the click is both the autoplay gesture and the connect, so there is no way to end up connected but silent. It reuses Galène's own `protocol.js` (served by the same server, so the wire protocol can't drift) and offers nothing a listener can't use: no publishing, chat, hand-raising, file transfer or device pickers. Serve it at `/listen/`. `+listen-url` mints `<base>/listen/?host=<host>&room=<room>&topic=<topic>&token=<jwt>`. The link carries no subgroup and no comet @p. The page reads the subgroup from the token's `aud`, and `host` is the host's name as Talon shows it.

```
https://<your-sidecar-host>/group/talon/<host>-<room>/?token=<jwt>
```

Three things this design deliberately accepts:

- **The link is a bearer token and cannot be revoked.** Galène's JWTs
  are stateless; nothing checks a revocation list. The only early kill
  switch is rotating the group secret, which breaks every room for
  everyone. So the TTL *is* the security model — `listen-ttl-cap` caps
  it at an hour regardless of what the client asks for, and the client
  asks for 15 minutes.
- **It punches through the group's boundary on purpose.** A party line
  is otherwise gated by the host's membership list, which is the trust
  boundary the whole design leans on. Turning listening on is therefore
  an explicit act by an admin, never a default, and never something an
  upgrade switches on: rooms migrating to state-6 get `listen=%.n`.
- **TLS is required, not advisory.** The token travels in a URL. The
  sidecar should run behind nginx on your own hostname with Galène's
  `proxyURL` set so `.status` advertises `wss://`; port 8444 is closed
  to the outside.

`ListenLinkE2ETest` covers the shape that matters: off by default,
minted when enabled, and refused again the moment it's switched off.

## Who's on the line

Both surfaces show the roster and who is talking.

**Speaking** comes from the remote audio level, polled at 250ms.
Each platform reads it differently, because the APIs differ:
`getSynchronizationSources()` on desktop (the level RTP already
carries in its header, so it costs nothing extra), and `inbound-rtp`
statistics on Android and iOS, neither of which exposes a
synchronization-source accessor. Both of those are async, so the poll
kicks off a refresh and reads what the previous one saw. No stats round trip, no `AudioContext` analyser on a stream we
only want to hear, and no protocol change: Galène names the publisher
on each `offer`, which is the only place a stream is tied to a person
(the roster is keyed by client, levels arrive per stream).

**Names** are the reader's own. Talon resolves a `@p` through its contact map, so you see whatever you call that person. The listen page has no Urbit and no contact book, and imposing the *host's* nicknames on strangers would be a different and worse thing than showing identity plainly. So it shows the name a client put in Galène's per-user data (`{"name": ...}`) when there is one, and otherwise what Galène knows, which is the token's `sub`: the `@p`. Wire 10 to 12 made a comet's `sub` its full mnemonym, which Galène's "spoofed username" check then held against every message the comet sent, so wire 13 signs comets in as their `@p` like everyone else. The page still shortens a mnemonym to `.first...last`, for hosts on those wires.

**The topic** is `room.title`, editable by admins. It reaches Talon
members live through `%announce`, and listeners through a `topic=`
parameter on the link — a snapshot taken when the link was minted,
because a browser can't ask the ship for a newer one. An empty title
means "leave the topic alone", so the toggles don't wipe it; the same
trap as `keep-sfu`, and the same fix.

**Joining mutes you.** Stepping onto a line should never start
broadcasting someone's room before they decide to speak, and an
accidental hot mic isn't recoverable after the fact.

## Offering the desk from the app

`%trunk` isn't in `%base`, and calls need it on *both* ships, so a user
who has never installed it would tap the call button and get nothing.
Instead the app offers to fetch it.

`%kiln`'s install mark takes json, so this needs no dojo — the client
pokes its own `%hood`:

```
mark  kiln-install
json  {"local":"trunk","ship":"~ricsul-bilwyt","desk":"trunk"}
```

which is exactly `|install ~ricsul-bilwyt %trunk`. `placeCall` and
`joinRoom` check first: no readable policy means no usable desk, so
they raise the offer instead of doing the thing.

Two details that are not obvious:

- **Success is a scry, not an ack.** The poke returns as soon as kiln
  accepts it; the desk arrives over ames afterwards. The controller
  polls `/x/policy` until the agent answers, up to two minutes.
- **A ship that once removed `%trunk` keeps the desk suspended**, and
  installing re-syncs it *without starting it* — the agent never
  answers and the install looks like it silently failed. Halfway
  through the wait the controller sends one `kiln-revive` (`|revive
  %trunk`), which is harmless on a desk that isn't suspended.

The dialog names the publisher, because accepting means the ship
installs and then keeps auto-updating software published by another
ship. That is the ordinary Urbit distribution model, but it should be
a knowing choice rather than a side effect of tapping a phone icon.

Since 1.6.5 the client also installs on its own, once per login, when
the ship plainly has no `%trunk` — eyre answers the policy scry with a
404 for an agent that isn't there, and nothing else is treated as
"missing". That install is quiet: on success the desk is simply there;
on failure nothing is shown, and the first call or join raises the
dialog above with the reason. The dialog is still the only path for an
outdated desk and for retries, and it still names the publisher.

`TrunkInstallE2ETest` drives the whole path against real ships. It is
destructive — it uninstalls the desk — so it needs `TRUNK_INSTALL=1`
on top of `TRUNK_E2E=1`.

## Installing the desk

The README's "The desk" has the steps and the list of files to copy from `%base` and `%landscape`. Check that `sys.kelvin` matches the ship's zuse, since a mismatch fails the commit with no useful message. `|rein` alone is not enough: gall reports "not running %trunk yet" until the desk has been installed once.

Then point the ship at its sidecar once (see `sidecar/README.md` for the key):

```dojo
:trunk &trunk-action [%set-ice ~[['stun:host:3478' '' ''] ['turn:host:3478' 'talon' 'PASS']]]
:trunk &trunk-action [%set-sfu ['http://host:8444' 'talon' 'KEY']]
```

Use an address the *other devices* can reach. `localhost` works from a desktop on the same box and fails from a phone, and that mistake costs a testing session.

## Automated checks

On a ship, the desk's own generators each answer `%ok` or name the cases that failed: `+trunk!test-push` (push bodies pinned to the old relay's bytes, the policy and switches, the preview, the `%activity` event shapes, ring bookkeeping, the debug report's redaction) and `+trunk!test-mnemonym`.

Talon's end-to-end tests are faster than driving the UI, and they run against real ships:

```
TRUNK_E2E=1 TRUNK_SFU_KEY=<key> TRUNK_SFU=http://<lan-ip>:8444 \
  ./gradlew :composeApp:desktopTest --tests '*E2E*'
```

- `TrunkCallE2ETest` — a 1:1 call end to end, with metrics.
- `PartyLineE2ETest` — two ships on one line via a real Galène.
- `PartyLineUiPathTest` — the path the UI takes (needs `TRUNK_CHANNEL`).
- `StuckRingE2ETest` — a caller that vanishes mid-ring must not leave
  the callee wedged.
- `CallPolicyE2ETest` — open rings, blocked is silent, allow-mode
  refuses a ship not on the list and rings one that is, and a block
  outranks an allow entry. Rings land on ship A only, so pointing A at
  an unused ship keeps the noise off a real device.
- `UiPrefSyncE2ETest` — a preference set on one device reaches another.
- `TrunkFixtureTest` (`TRUNK_FIXTURE=1`) — one-shot: creates a group
  with a chat channel, invites the second ship, and points the host at
  its SFU. Prints the channel to open in the app.

## Two-ship test by hand

1. Boot two fake ships (never reuse a rebuilt fake's name for
   cross-ship work) with distinct HTTP ports.
2. Install the desk on **both** — a peer without it nacks the relay.
3. Run two Talon desktops with separate config dirs:
   `XDG_CONFIG_HOME=/tmp/talon-a ./gradlew :composeApp:run` (and -b).
4. Log each into its ship, open a DM between them, tap the call icon
   (or type `/call`).
5. Answer on the other side; both machines on the same LAN should go
   live over host candidates. Grep both logs for `Trunk metric`.

## What failure teaches

- Ring arrives but no offer → check the eyre poke of `%trunk-action`
  (mark file json grab) on the caller's ship.
- Offer arrives, never live → Tier 0 insufficiency on this network;
  that's a *finding*, not a bug — note the NAT shapes involved.
- `unknown`/`unreachable` reject → the peer has no `%trunk` running.
- **"busy" on every call** → first: is another client logged into the
  same ship? A ship is one identity across many devices and they all
  receive the ring. A busy device used to reply "busy" for the whole
  ship, cancelling a call another device was ringing for — a test
  harness left connected did exactly this for a day. Busy devices now
  stay silent. Then: the far device is stuck in a ringing or
  active state. It used to stick forever; a ring now expires after 45s.
  The state is in memory, so a device wedged by an older build stays
  wedged until the process restarts.
- **Party line fails to connect** → almost always the SFU address:
  check what `location` a ticket carries (`join-room` and read the
  fact) rather than what you think you configured.
- **"duplicate client id"** in Galène's log → a client reused its id
  across connections; each connection needs a fresh one.
- Denials are deliberate and specific: `no such room` (host never
  opened it), `not a member` (not on the group roster), `no sfu
  configured` (host never ran `%set-sfu`).

## v0 results (2026-08-25, ~nec + ~feb on localhost)

The E2E harness (`TrunkCallE2ETest`, opt-in via `TRUNK_E2E=1`) passed:
ring→incoming **110ms**, gather **286ms**, media live ~**300ms** after
accept, hangup propagated. Warm-ames localhost numbers — the WAN rerun
against real ships is the next measurement. Two wire bugs found and
fixed on the way: enjs `+ship` drops the leading `~` (agent now emits
`(scot %p)`), and eyre poke nacks are async + easy to silently drop
(controller now logs channel errors).

## v1 (2026-08-25, this branch)

- **ICE distribution**: `%trunk` stores an advertised server list
  (`[%set-ice …]` poke, `/x/ice` scry). Clients fetch it at startup
  and hand it to the engine — no app configuration.
- **Sidecar**: `sidecar/docker-compose.yml` — coturn for STUN (Tier 1)
  + TURN relay (Tier 2). Galène joins at v2 for party-line SFU rooms.
- **Android engine**: libwebrtc (getstream build), mic-permission
  gate, MODE_IN_COMMUNICATION routing. `isCallsSupported` now true on
  Android + desktop.
- **Real call UI**: full-screen ring (answer/decline), in-call top
  banner with mute + duration, call button in the DM header, `/call`.
- **Resilience, E2E-proven**: a dead STUN server degrades (8s gather
  cap, partial candidates) instead of breaking; answering before the
  offer lands now waits for it instead of no-oping. The E2E runs the
  dead-STUN chaos path: ~nec advertises `stun:localhost:3478` with
  nothing listening — leave it that way, it's a regression test.

## v2 — party lines (2026-08-26, this branch)

Multi-party audio, host-centered per design D5. Validated end to end
against two fake ships plus a real Galène: `PartyLineE2ETest` has both
ships publishing to the SFU ~250ms after the host opens the line, with
a correct roster on both sides and clean leave propagation.

- **Tickets minted in Hoon.** `lib/trunk-jwt.hoon` signs Galène's
  HS256 JWTs on-ship, so the host authorizes members without any
  server round trip. The two byte-order conventions bite here and are
  documented in that file: `base64:mimes:html` reads octs LSB-first,
  `hmac-sha256l:hmac:crypto` reads them MSB-first and returns a
  big-endian atom. Get it backwards and you get a perfect-looking
  token that fails every signature check.
- **One Galène group, rooms as subgroups.** The sidecar configures a
  single `talon` group with `auto-subgroups`; each room is
  `talon/<host>-<room>`, created on first join. Opening a party line
  needs no server-side change, and each ticket's `aud` scopes it to
  exactly one room.
- **Membership is the whole check.** `[%ask]` from a non-member or for
  an unknown room is denied by the host's agent, never by the SFU.
- **Discovery.** Opening a room announces it to every member, so
  joining is an invitation rather than a guess (`/x/lines`).
- **Client.** `PartyLine.kt` speaks Galène's WebSocket protocol over
  the shared Ktor client; `PeerLink` is the trickling, one-directional
  per-stream media primitive (desktop + Android impls).

Party lines need no ICE config from the ship, since Galène has a
public address. Its own TURN server stays off (`-turn ''`), because it
relays to any address for anyone who joins. coturn stays for 1:1.

## Security review of the room path (2026-08-26)

Auditing the new trust boundaries turned up one real vulnerability,
fixed in the same pass:

- **Unsolicited `%grant` = microphone hijack.** The agent accepted a
  ticket from *any* ship, and the client auto-joins on ticket — so a
  hostile ship could push a grant naming its own SFU and the victim
  would publish its microphone there. The agent now records outstanding
  `%ask`s and accepts a `%grant`/`%deny` only as the answer to one.
  Verified then: after a completed join `+dbug %state` showed
  `asked={}`, so any later grant fails the check. (Wire 12 removed
  dbug, which served the whole state to any agent on the ship.)
- **Invitation list is remote-controlled**, so `%announce` is capped
  (`invite-cap`) rather than growing without bound.
- Membership is checked host-side at mint time, and `sub` always names the *asking* ship by its `@p`. A member cannot mint a ticket for anyone else.
- Ticket TTL is 6h with no revocation: a member removed from a group
  keeps access until expiry. Rotating the SFU key is the only immediate
  revocation. Documented ceiling, not a v2 fix.

## Known gaps

- `CallEngine` (1:1) and `PeerLink` (SFU) overlap ~60% per platform.
  Folding the former onto the latter is the obvious cleanup, deferred
  deliberately while the 1:1 path is in an RC under test; its E2E is
  the regression net for that refactor.
- Galène keeps a subgroup's roster after the last client drops, so a
  member who left can linger in everyone's list for a while. Talon now
  closes the socket cleanly (and before the slow native media
  teardown, which used to leave Galène with an abrupt EOF), but the
  reaping delay is the server's. `PartyLineE2ETest` sidesteps it by
  using a fresh room name per run.
- The SFU sees plaintext audio, exactly as the host's ship already
  sees the group's messages. Host-blind party lines would need
  insertable-streams E2EE — a v3+ concern with real key-rotation
  complexity on member leave.

## Testing on real hardware

The fake ships already have `%trunk`, so a phone + desktop session
needs no ship work. Ports are on the LAN, so use the machine's LAN
address (not localhost) from the phone.

**1:1 calls (no sidecar needed).**

1. Desktop Talon: log into `~feb` at `http://<lan-ip>:8082`.
2. Phone (rc2 APK): log into `~nec` at `http://<lan-ip>:8081`.
3. Open the DM between them, tap the call icon in the header.
4. Expect Tier 0 (host candidates) on the same LAN. Grep the desktop
   log (`~/.config/talon/log/talon.log`) and Android logcat for
   `Trunk metric` — those are the first real cross-device numbers.
5. Then put the phone on cellular and repeat. That is the first
   genuine Tier 2 test, and it needs the sidecar's TURN
   (`sidecar/README.md`) plus a `%set-ice` poke pointing at a
   publicly-reachable address.

**Party lines (needs a Galène).** Bring one up per `sidecar/README.md`,
then from each ship's dojo point it at the SFU with `%set-sfu`. Open a
group channel on a group `~nec` hosts and tap the party-line icon:
the host opens the line, everyone else joins it. The strip under the
channel header shows who is on.

Both flows are already covered headlessly by `TrunkCallE2ETest` and
`PartyLineE2ETest`, so a failure on device is a platform/network
finding rather than a protocol one — worth capturing the log either
way.

## Next

Done since this list was first written: the desk and sidecar live in their own repo (gwbtc/trunk), iOS rings through CallKit and PushKit, and the ship sends its own pushes, with the APNs gateway as the only piece off the ship. Still ahead: WAN metrics against real ships, ConnectionService on Android, ICE restart on network change, and TLS in front of Galène.
