# Guest seats: calls with people who have no ship

**Status: built, wire 16, state 17.** This began as a proposal (PR #11). The last section lists where the build departs from it and why.

A party line seats ships. Before wire 16, anyone without a ship could only listen, through a listen link. Guest seats let a ship host calls that people without a ship can speak in. They arrive through an invite link, or through an app on the host's ship that already knows who they are.

This is a general feature, not a MUD feature. A ship that can put a grandparent, a customer or a game's guest on a call, without asking them to get a ship first, is one of the things that makes running your own ship worth it. The MUD on Urbit (nisfeb/mud) is the first app that wants it, and is the worked example below.

## The guest

A guest is a person on the call who has no ship behind their seat.

- **Their username is not an `@p`.** It is `guest-` and 12 hex digits, such as `guest-3fa9c07b12de`. An `@p` always starts with `~` and a guest's name never does, so every client can tell a guest from a ship by looking, and a guest can never take a ship's name.
- **Their readable name** travels in Galène's per-user data, `"data": {"name": "Grandma"}`, the same place a comet's mnemonym goes since wire 13. The guest's page sends it, so trunk never sees it. Clients should mark guests ("Grandma (guest)"), so nobody can pass as a ship by picking a name. The guest page and the listen page both do.
- **Trunk makes their id.** The guest's page and the app never name it. Galène refuses any message whose username differs from the token's `sub`, so a guest must join as exactly the name in their ticket.
- **Permissions.** A speaking guest's token grants `present` and `message`, like a member's. A listening guest's grants nothing, which is Galène's listener. A guest token never grants `op`. A room's `speak-roles` and `muted` do not apply to guests, who have no roles.
- **A token lasts an hour, and that bounds a rejoin, not a call.** Galène checks a token only when a connection joins. A guest already on the line stays until they leave, the room moves (app rooms), or someone with `op` removes them.

## Way in 1: invite links, for people

The owner makes an invite to a party line the ship hosts, from the trunk page, Talon or the dojo:

```jsonc
// wire 16, the owner's alone
{"invite-guests": {"name": "lounge", "speak": true, "ttl": 86400, "uses": 10}}

// the answer, on /calls
{"guest-invite": {"code": "<32 hex>", "name": "lounge", "path": "/apps/trunk/guest/<code>",
                  "speak": true, "expires": 1760090000, "uses": 10, "guests": 0}}

{"revoke-invite": "<code>"}
```

An invite is a code the ship keeps, not a Galène token, so unlike a listen link it can be revoked, limited and listed. `path` is on the ship: trunk does not know its own public URL, so a client puts its origin in front. `uses` counts the new guests it may still seat, and `guests` the ones it has. The live invites, and the apps below, are one owner-only scry: `/~/scry/trunk/guests.json`. Codes are bearer secrets, so they are never in `/x/debug`.

1. A guest opens the link. Trunk serves `app/trunk/guest.html`, which asks for a display name and shows who is hosting and the room's title. Those come from `GET <path>/room`, and are all the page knows of the host.
2. On Join, the page posts `{"guest": <the id it was given before, or null>}` to `<path>`. Eyre gives a signed-out request a guest identity, and these routes sit before the sign-in check.
3. Trunk checks the code: it exists, it has not expired, and the ship still hosts a room of that name. A guest it already seated keeps their id and takes no use, so one person stays one guest. Anyone else takes a use and a new id. The answer is the ticket: `username`, `location`, `endpoint`, `token`, `expires` and `speak`.
4. The page loads `protocol.js` from the SFU, joins with the token and the name, and publishes the microphone if the invite lets guests speak.

The page keeps the guest id and name in the browser, per invite. A rejoin, after a reload or a dropped connection, asks again with the same id. A revoked or expired code refuses the rejoin, but a guest already on the line stays until they leave.

The answers: 404 when the invite has ended or never was, 410 when it has no seats left, 503 when the ship has no call server set up.

Limits: an invite lasts at most 30 days and seats at most 1,000 guests, and a ship keeps at most 64 live invites. Expired invites, and those for rooms the ship no longer hosts, are pruned when an invite is made. An invite names a room: it works while a room of that name is open.

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
                  "username": "guest-3fa9c07b12de",
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
- **Limits:** at most 64 app rooms per ship and 256 guests in one. A room that asks for no ticket for a day closes itself, checked whenever any app acts.

Like notices, the per-app gate keeps careless apps in their lane. It does not stop a hostile one: gall lets an agent name any origin for its poke. That is the same trust a ship already places in what it installs.

**Grubbery apps cannot use this yet.** Every grubbery app reaches trunk as `%grubbery`, so they would share one switch and one set of rooms, and grubbery's own marc for trunk types only the notice actions. Supporting them means an `-as` variant, as `push-notice-as` did for notices, and a change to that marc.

## Mixing ships and guests

A room can hold both. Members of a party line still join with `%join-room` and their `@p`, and invite guests join the same subgroup with their guest ids. Presence (`%who-is-on`, the occupancy count) counts ships only.

## What has to be true outside trunk

- **Galène must take the ship's origin.** The guest page is served by the ship, and Galène refuses a websocket from another origin unless its `data/config.json` lists it: `{"allowOrigin": ["https://your.ship.example"]}`. An app's own page on the ship needs the same entry. Galène's `.status` sends no CORS header either, which is why every ticket carries `endpoint`.
- **Galène must speak TLS before guests use an https ship.** The sidecar runs Galène `-insecure` on plain http :8444. A page served over https cannot load `protocol.js` from, or open a websocket to, plain http: the browser blocks mixed content. The guest page says so rather than failing quietly. The fix is a TLS front for :8444 (an nginx vhost with a certificate, for example), and pointing `%set-sfu` at its https base. Party lines for ships get the same protection.
- **TURN.** Galène hands every client its own TURN servers on join, so guests need nothing new.
- **Capacity.** Guests use the same SFU as members. A ship that hosts busy public rooms should run its own sidecar.

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

- **Trunk never takes a display name.** Galène's per-user data comes from the client whatever trunk says, so the guest route and `app-guest-ticket` carry no name. The guest route takes only the code and the guest id it gave.
- **No renewal timer.** Galène checks a token only at join, so the page asks again only when it joins again.
- **An invite gives a path, not a URL,** because trunk does not know the ship's public URL.
- **Listing is a scry.** `list-invites` and its fact became `/x/guests`, and `revoke-invite` takes the code alone.
- **One switch per app, no global one.** Every app starts off, which is what the global switch was for.
- **Owner invites only.** An admin of a party line hosted elsewhere cannot make an invite yet. That needs a room-sig like `%share`.
- **Limits that bound state.** 256 guests per app room replaces 512 tickets an hour per app. The per-minute join limits were dropped: `uses` bounds new seats, and a rejoin makes no state.
- **App room locations are `<ship>/<agent>/<room>/<epoch>`, with a random epoch.** The proposal's `<ship>-<agent>-<room>-<epoch>` could collide with a party line a remote admin opens, and a counted epoch would restart when a room closed and opened again.
- **Tickets carry `endpoint`,** since a page on the ship cannot read Galène's `.status`.
