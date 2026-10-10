# Guest seats: calls with people who have no ship

**Status: built.** Invites and app rooms are wire 16 (state 17). Permanent links, guest secrets and video on the guest page are wire 17 (state 18). This began as a proposal (PR #11). The section near the end lists where the build departs from it and why.

A party line seats ships. Guest seats let a ship host calls that people without a ship can join, with audio, video and screen sharing. They arrive through a link, or through an app on the host's ship that already knows who they are.

This is a general feature, not a MUD feature. A ship that can put a grandparent, a customer or a game's guest on a call, without asking them to get a ship first, is one of the things that makes running your own ship worth it. It is also what lets a ship replace a hosted meeting service for its owner's recurring meetings.

## Running a recurring meeting

This is the whole recipe for replacing a Google Meet style meeting.

1. **One party line and one permanent link per meeting.** On the trunk page (`/apps/trunk`), under Guests, pick "New line…" as the party line and give it a title, such as "Groundwire standup". Under "Members from Talon", pick the Tlon group whose members should join from Talon as themselves, or leave it at Nobody. A ship outside that group can still use the link, and shows as a guest. Give the link a name, such as `groundwire-standup`, and press Make a permanent link. The page opens the line, binds it to the group and makes the link. A line stays open until you close it. The link never expires and has no seat limit. You can also make a link for a line you already host, or open the line from Talon or the dojo first.
2. **Copy or share the link.** Each link on the trunk page has Copy, and on a phone Share, which opens the phone's share sheet.
3. **Put the link in the calendar series**, once. People with no ship open it at meeting time in any browser, type a name and join. People with ships join the line from Talon as themselves.
4. **Leave the line open between meetings.** Closing it, from Talon, the dojo or the trunk page, ends its links, and a calendar link then stops working. To bring one back, open the line and make the link again under the same name.
5. **Try the link yourself** in a private window before the first meeting. That checks the call server, TLS and `allowOrigin` before a guest needs them.
6. **Revoke it** from the same list when the meeting ends for good, or when it leaked. Revoking stops new joins and rejoins. Whoever is already on the call stays until they leave.

On a ship whose call server has a short-link redirect (see below), the link can also be shared as `https://calls.example.com/groundwire-standup`.

A readable name can be guessed, and anyone who knows or guesses it can join until you revoke it. So the trunk page adds a hard-to-guess ending by default, such as `groundwire-standup-k3f9x2qa`. Turn that off only for a link meant for anyone.

Text for the calendar event:

> Join in any browser: <the link>. Type your name, press Join and allow the microphone. No account is needed. On a phone, open the link in Safari or Chrome, not inside the mail or calendar app. With Talon, join the line from its group instead.

From the dojo, the same three steps, then a revoke:

```
:trunk &trunk-action [%open-room 'groundwire-standup' 'Groundwire standup' ~ ~]
:trunk &trunk-action [%bind-room 'groundwire-standup' `[~hodler-lorfeb 'v769287']]
:trunk &trunk-action [%guest-link 'groundwire-standup' 'groundwire-standup' &]
:trunk &trunk-action [%revoke-invite 'groundwire-standup']
```

`%bind-room` takes the group's host and name, as in its flag `~hodler-lorfeb/v769287`. `%guest-link` takes the link's name, then the party line it opens, then whether guests may speak.

## The guest

A guest is a person on the call who has no ship behind their seat.

- **Their username is not an `@p`.** It is `guest-` and 24 hex digits, such as `guest-3fa9c07b12de5e81a7c4d230`. An `@p` always starts with `~` and a guest's name never does, so every client can tell a guest from a ship by looking, and a guest can never take a ship's name.
- **Their readable name** travels in Galène's per-user data, `"data": {"name": "Grandma"}`, the same place a comet's mnemonym goes since wire 13. The guest's page sends it, so trunk never sees it. Clients mark guests ("Grandma (guest)"), so nobody can pass as a ship by picking a name. Talon, the guest page and the listen page all do.
- **Their id is the hash of a secret (wire 17).** Trunk makes a 128-bit secret and gives it to the guest's page, which keeps it in the browser. The id is derived from it. Only the holder of the secret can rejoin as that guest, so a guest who sees another's id on the call cannot take it over. Galène refuses any message whose username differs from the token's `sub`, so a guest must join as exactly the name in their ticket. An app's guests get ids trunk makes for them (below).
- **Permissions.** A speaking guest's token grants `present` and `message`, like a member's. `present` covers the microphone, the camera and a shared screen. A listening guest's token grants nothing, which is Galène's listener: they hear and watch. A guest token never grants `op`. A room's `speak-roles` and `muted` do not apply to guests, who have no roles.
- **A token lasts an hour, and that bounds a rejoin, not a call.** Galène checks a token only when a connection joins. A guest already on the line stays until they leave, the room moves (app rooms), or someone with `op` removes them.

## Way in 1: links, for people

The owner makes a link to a party line the ship hosts, from the trunk page, Talon or the dojo. There are two kinds.

```jsonc
// wire 16: an invite, for a set number of people over a set time
{"invite-guests": {"name": "lounge", "speak": true, "ttl": 86400, "uses": 10}}
// the answer, on /calls
{"guest-invite": {"code": "<32 hex>", "name": "lounge", "path": "/apps/trunk/guest/<code>",
                  "speak": true, "expires": 1760090000, "uses": 10, "guests": 0}}

// wire 17: a permanent link, under a name the owner picks
{"guest-link": {"code": "groundwire-standup", "name": "lounge", "speak": true}}
// the answer, on /calls
{"guest-link": {"code": "groundwire-standup", "name": "lounge",
                "path": "/apps/trunk/guest/groundwire-standup", "speak": true}}

// either kind
{"revoke-invite": "<code or name>"}
```

Either is a code the ship keeps, not a Galène token, so unlike a listen link it can be revoked and listed. `path` is on the ship: trunk does not know its own public URL, so a client puts its origin in front. The live invites, the permanent links and the apps below are one owner-only scry, `/~/scry/trunk/guests.json`. Codes are bearer secrets, so they are never in `/x/debug`.

- **An invite** has `uses` new guests left and lasts `ttl` seconds. A guest it seated who rejoins takes no use. It lasts at most 30 days and seats at most 1,000 guests, and a ship keeps at most 64 live ones. Expired invites, and those for rooms the ship no longer hosts, are pruned when an invite is made.
- **A permanent link** never expires and has no seat limit. It keeps no guests at all: the guest's secret alone keeps their id. Its name is a `@tas` of 3 to 64 characters, and a ship keeps at most 64. Making a link again under the same name points it at another room.

Either one belongs to its line. Closing the line ends its links, so a line opened again later under the same name starts with none. A link works only for a line on the ship's own call server: the guest page runs that server's `protocol.js` on the ship's origin, and a line's admins can point it at another server.

1. A guest opens the link. Trunk serves `app/trunk/guest.html`, which asks for a display name and shows who is hosting and the room's title. Those come from `GET <path>/room`, and are all the page knows of the host.
2. On Join, the page posts `{"secret": <the secret it was given before, or null>}` to `<path>`. Eyre gives a signed-out request a guest identity, and these routes sit before the sign-in check.
3. Trunk checks the code: an unexpired invite, or a permanent link, for a room the ship still hosts. The answer is the ticket: `secret`, `username`, `location`, `endpoint`, `token`, `expires` and `speak`. The page keeps the secret.
4. The page loads Galène's `protocol.js` from the ship (`/apps/trunk/protocol.js`, Galène 1.1's own file, pinned in the desk) and joins with the token and the name. Loaded from the call server, it would run on the ship's origin, so a broken call server would become a broken ship. A call server on another Galène version may need the pinned file changed to match.

The page keeps the secret and the name in the browser, per link. A rejoin, after a reload or a dropped connection, sends the same secret. A revoked or expired link refuses the rejoin, but a guest already on the line stays until they leave.

The answers: 404 when the link has ended or never was, 410 when an invite has no seats left, 503 when the ship has no call server set up or the line runs on another one.

## Video and screen sharing

The guest page shows one tile per person on the call, with their camera or shared screen, and a tile can be tapped to enlarge it. A speaking guest has Mute, Camera, Share screen (on desktop browsers, which can share a screen) and Leave. Phones can watch a shared screen but not share one.

The page publishes the way Talon does, so each sees the other:

- **One stream**, labelled `camera`, with the microphone and one video sender. The video sender exists from the start, with no track until the camera or a share goes on.
- **The camera and a shared screen take turns** on that one sender, by `replaceTrack`, with no renegotiation. When the browser's own "Stop sharing" ends a share, the camera comes back if it was on.
- **No simulcast.** One encoding, so a shared screen is never sent as a blurry low layer.
- **`talon-video`** is a Galène usermessage, `true` while the camera or a share is on and `false` otherwise. Talon draws a person's video only after it, because every down link carries an empty video transceiver and Galène has no camera state. **`talon-mute`** says whether the microphone is off. Galène does not replay usermessages to newcomers, so both go again whenever someone joins.

## Way in 2: apps, for an app's own users

An app on the host's ship can host its own rooms and seat its own users in them as guests. The app decides who belongs. Trunk decides only whether this app may host calls at all.

```hoon
::  from another agent on our ship, as nouns on the trunk-action mark
[%app-room-open room=@t]
[%app-room-close room=@t]
[%app-room-rotate room=@t]
[%app-guest-ticket room=@t guest=@t speak=? req=@t]
```

```jsonc
// the answers, as %json facts on /app/<agent>, a path only that agent may watch
{"guest-ticket": {"room": "party-0v3a2", "guest": "<app's id>", "req": "<request id>",
                  "username": "guest-3fa9c07b12de5e81a7c4d230",
                  "location": "https://sfu.example/group/talon/<ship>/mud-world/party-0v3a2/<epoch>/",
                  "endpoint": "wss://sfu.example/ws", "token": "<jwt>", "expires": 1760003600,
                  "speak": true}}
{"guest-denied": {"room": "party-0v3a2", "req": "<request id>", "why": "apps may not host calls on this ship"}}
```

- **One app, its own rooms.** Gall names the poking agent in `sap.bowl`, and an app room is keyed by that agent and the room's name. An app cannot name another app's rooms or the owner's party lines. A room name is a `@tas`.
- **The app's id for a user maps to one guest id** for that room's life. An app that asks again for the same user gets the same `username`, so a re-ticket makes no duplicate on the line.
- **The owner decides.** The trunk page lists each app that has asked, with a switch. Every app starts switched off. The switch is the owner's action `{"app-hosting": {"agent": "mud-world", "allow": true}}`. While off, everything but closing a room is a `guest-denied`.
- **Answers come on a subscription.** A poke cannot return data, so the app watches `/app/<agent>` and matches answers by `req`. The facts are `%json`, so an app couples to field names and not to trunk's types.
- **Removing someone is a rotation.** Galène tokens cannot be revoked, so `app-room-rotate` moves the room to a new location, named by a new random epoch, and the app re-tickets everyone still welcome. They keep their guest ids. The removed person's old token opens only the old location, where nobody is left.
- **Where the rooms live.** A party line's Galène subgroup is `<ship>-<name>`, and an app room's is `<ship>/<agent>/<room>/<epoch>`. The character after the ship differs, so no line a remote admin opens can land on an app's room. App rooms run on the ship's own sidecar.
- **Limits:** at most 64 rooms per app and 256 guests in one. A room that asks for no ticket for a day closes itself, checked whenever any app acts.

An app's page that wants to interoperate with Talon publishes the way the guest page does (above).

Like notices, the per-app gate keeps careless apps in their lane. It does not stop a hostile one: gall lets an agent name any origin for its poke. That is the same trust a ship already places in what it installs.

**Grubbery apps cannot use this yet.** Every grubbery app reaches trunk as `%grubbery`, so they would share one switch and one set of rooms, and grubbery's own marc for trunk types only the notice actions. Supporting them means an `-as` variant, as `push-notice-as` did for notices, and a change to that marc.

## Mixing ships and guests

A room can hold both. Members of a party line still join with `%join-room` and their `@p`, and guests join the same subgroup with their guest ids. Talon shows guests in the roster and the meeting view, marked as guests. Presence (`%who-is-on`, the occupancy count) counts ships only.

## What has to be true outside trunk

- **Galène must take the ship's origin.** The guest page is served by the ship, and Galène refuses a websocket from another origin unless its `data/config.json` lists it: `"allowOrigin": ["https://your.ship.example"]`. An app's own page on the ship needs the same entry. Galène's `.status` sends no CORS header either, which is why every ticket carries `endpoint`. Native apps send no Origin header and are not affected.
- **Each host ship should have its own Galène group and key.** Every ship that holds a group's key can mint a token for any room in it, so a sidecar several ships share should give each its own group (`sidecar/README.md`, step 1).
- **Galène must speak TLS before guests use an https ship.** A page served over https cannot load `protocol.js` from, or open a websocket to, plain http: the browser blocks mixed content. The guest page says so rather than failing quietly. The fix is a TLS front for Galène (an nginx vhost with a certificate), `"proxyURL": "https://<that host>"` in Galène's `data/config.json` so `.status` names it, and `%set-sfu` pointed at its https base. `sidecar/README.md` has the steps.
- **The short link is optional.** One nginx rule on the call server's TLS host can send `https://<host>/<name>` to `https://<ship>/apps/trunk/guest/<name>`, as long as it skips Galène's own paths. `sidecar/README.md` has the rule.
- **TURN.** Galène hands every client its own TURN servers on join, so guests need nothing new.
- **Capacity.** Galène forwards video without decoding it, so its CPU cost is small, and bandwidth is what grows. Each person's video goes to every other person. About ten people on camera is comfortable for one small server. A ship that hosts bigger or busier rooms should measure first, or run its own sidecar.

## Worked example: the MUD's party voice

The MUD on Urbit (`%mud-world`, a plain gall agent) seats players as guests (browser cookies) and as citizens (ships), all through the world ship's own pages. Its party voice was first built as a peer-to-peer WebRTC mesh. With guest seats it becomes:

1. The world's owner switches `mud-world` on under "Apps that host calls" on the trunk page.
2. A party forms. `%mud-world` watches `/app/mud-world` and sends `app-room-open` for `party-<group id>`.
3. A player presses Join party voice. `%mud-world` checks they are in that party and sends `app-guest-ticket` with the player's session as the app's id.
4. `%mud-world` relays the `guest-ticket` to that player's browser. The browser joins Galène with `protocol.js`, sending the character's name in its per-user data.
5. Someone leaves or is kicked: `app-room-rotate`, then a ticket for each who remains.
6. The party disbands: `app-room-close`.

The MUD drops its own signalling relay, its ICE handling and its coturn script. It keeps its party rules, its voice bar and its settings.

## Where the build departs from the proposal

The proposal's four open questions were settled as it proposed: invites need only the owner's action, a guest's token lasts an hour, the guest page is served from the ship, and removal is by rotation, with no op connection. Beyond those:

- **Trunk never takes a display name.** Galène's per-user data comes from the client whatever trunk says, so the guest route and `app-guest-ticket` carry no name.
- **A guest id is the hash of a secret (wire 17),** not an id the page sends back. In wire 16 the page rejoined by sending its id, and any guest who saw another's id on the call could rejoin as them.
- **No renewal timer.** Galène checks a token only at join, so the page asks again only when it joins again.
- **An invite gives a path, not a URL,** because trunk does not know the ship's public URL.
- **Listing is a scry.** `list-invites` and its fact became `/x/guests`, and `revoke-invite` takes the code alone.
- **Permanent named links (wire 17)** were not in the proposal. Recurring meetings need a link that outlives 30 days.
- **One switch per app, no global one.** Every app starts off, which is what the global switch was for.
- **Owner links only.** An admin of a party line hosted elsewhere cannot make a link yet. That needs a room-sig like `%share`.
- **Limits that bound state.** 256 guests per app room replaces 512 tickets an hour per app. The per-minute join limits were dropped: `uses` bounds new seats, and a rejoin makes no state.
- **App room locations are `<ship>/<agent>/<room>/<epoch>`, with a random epoch.** The proposal's `<ship>-<agent>-<room>-<epoch>` could collide with a party line a remote admin opens, and a counted epoch would restart when a room closed and opened again.
- **Tickets carry `endpoint`,** since a page on the ship cannot read Galène's `.status`.
