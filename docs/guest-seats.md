# Guest seats: calls with people who have no ship

**Status: proposal, 2026-10-10. Not built. Wire 16 if accepted.**

A party line today seats ships. Anyone without a ship can only listen, through a listen link. This proposal lets a ship host calls that people without a ship can speak in. They arrive through an invite link, or through an app on the host's ship that already knows who they are.

This is a general feature, not a MUD feature. A ship that can put a grandparent, a customer or a game's guest on a call, without asking them to get a ship first, is one of the things that makes running your own ship worth it. The MUD on Urbit (nisfeb/mud) is the first app that wants it, and is used below as the worked example.

## What exists to build on

- **Listen links** (`%share-room`). The host mints a Galène token with no `present` permission for the user `listener` and wraps it in a URL. The link is the credential. Galène cannot revoke it, so its lifetime is the whole security model.
- **Tickets** (`%join-room`). The host mints a per-member, per-room token whose `sub` is the member's `@p`, after checking the room's roster and role gates.
- **The sidecar.** On asimov, Galène runs on :8444 with `auto-subgroups`, so every room is a subgroup created on first join. Its built-in TURN is on :1194, and coturn on :3479.
- **Local apps.** Another agent on the ship may already send `push-notice` and `push-notice-as`, under a name, with an owner switch per app.

Guest seats reuse all four. The new part is a way to mint a speaking token for someone who is not a ship, and two gates that decide who may ask for one.

## The guest

A guest is a person on the call who has no ship behind their seat.

- **Their username is not an `@p`.** It's `guest-` followed by 12 hex digits, such as `guest-3fa9c07b12de`. An `@p` always starts with `~` and a guest's name never does, so every client can tell a guest from a ship by looking, and a guest can never take a ship's name.
- **Their readable name** travels in Galène's per-user data, `"data": {"name": "Grandma"}`, the same place a comet's mnemonym already goes since wire 13. Clients should show guests marked as guests ("Grandma (guest)"), so nobody can pass as a ship by picking a name.
- **Their id is minted by trunk,** never chosen by the client. Galène refuses any message whose username differs from the token's `sub`, so a guest's client must join as exactly the name in its ticket.
- **Permissions.** A guest token grants `present` and `message`, like a member's, or nothing at all for a listener. It never grants `op`. A room's `speak-roles` and `muted` don't apply to guests, who have no roles. A host who wants listening-only guests issues listening invites (below).

## Way in 1: invite links, for people

The owner, or an admin of a room, mints an invite to a room the ship hosts:

```jsonc
// wire 16, from the owner's web session, Talon or the dojo
{"invite-guests": {"name": "lounge", "speak": true, "ttl": 86400, "uses": 10}}

// the answer, on /calls
{"guest-invite": {"name": "lounge", "code": "<code>", "url": "https://<ship's url>/apps/trunk/guest/<code>",
                  "speak": true, "expires": 1760090000, "uses": 10}}
```

An invite is not a Galène token. It's a code the ship keeps, so unlike a listen link it can be revoked, limited in uses, and listed.

1. A guest opens the URL. Trunk serves a small page (beside the listen page) that asks for a display name and shows who is hosting.
2. The page posts the code and the name to `/apps/trunk/guest/<code>`. Eyre gives an unauthenticated request a guest identity, so this route sits before any owner check, as `/http-response` already does.
3. Trunk checks the code: it exists, it hasn't expired, it has uses left, and the room still exists. It then counts a use, makes a guest id, and mints a token with `sub` = the guest id and a short lifetime (an hour).
4. The page joins Galène with that token, through Galène's `protocol.js`, as the listen page already does.

Before the hour runs out, the page asks again with the same code and the guest id it was given. Trunk renews the same id without counting a new use, while the code is valid. That keeps one person one guest across renewals. A revoked or expired code means no renewal, so a guest is out within the hour.

```jsonc
{"revoke-invite": {"name": "lounge", "code": "<code>"}}
{"list-invites": {"name": "lounge"}}   // answered on /calls with every live code, its uses left and expiry
```

Rate limits: at most 30 guest joins a minute per code and 120 per ship. Display names are trimmed to 40 bytes, with control bytes dropped, using the same treatment as `+preview`.

## Way in 2: apps, for an app's own users

An app on the host's ship can host its own rooms, and seat its own users in them as guests. The app decides who belongs. Trunk decides only whether this app may host calls at all.

```jsonc
// wire 16, from another agent on our ship (sap.bowl /gall/<agent>)
{"app-room-open":   {"room": "party-0v3a2"}}                  // room named <agent>/<room> on the SFU
{"app-room-close":  {"room": "party-0v3a2"}}
{"app-room-rotate": {"room": "party-0v3a2"}}                  // new location; every old token stops working there
{"app-guest-ticket": {"room": "party-0v3a2", "guest": "<app's id for the user>",
                      "name": "Ash", "speak": true, "req": "<request id>"}}

// the answer, on /app/<agent>, a path only that agent may watch
{"guest-ticket": {"room": "party-0v3a2", "guest": "<app's id>", "req": "<request id>",
                  "location": "https://sfu.example/group/talon/<ship>-<agent>-party-0v3a2-<epoch>/",
                  "username": "guest-3fa9c07b12de", "token": "<jwt>", "expires": 1760003600}}
{"guest-denied": {"room": "party-0v3a2", "req": "<request id>", "why": "apps may not host calls on this ship"}}
```

- **One app, its own rooms.** An app room is named after the agent that opened it, `<agent>/<room>`, and only that agent may mint tickets for it, rotate it or close it. An app can't reach another app's rooms or the owner's party lines.
- **The app's guest id maps to one trunk guest id,** stable for that room's life. An app that asks again for the same user gets the same `username`, so renewals don't make duplicates on the line.
- **The owner decides.** A new setting, "Apps may host calls", with a switch per app, as for notices. It's off by default; the trunk page lists which apps have asked. A refusal is a `guest-denied`, never a crash.
- **Answers come on a subscription.** A poke can't return data, so the app watches `/app/<agent>` and matches answers by `req`. `+on-watch` admits that path only for the agent of the same name.
- **Revoking.** Galène tokens can't be revoked, so removing someone is `app-room-rotate`. It moves the room to a new location, named with a new epoch, and the app re-tickets everyone still welcome. The removed person's old token still opens the old location, but that subgroup is empty. Tokens last at most an hour either way.
- **Limits:** at most 64 app rooms per ship, 512 guest tickets an hour per app, and an app room closes itself after 24 hours with no ticket asked.

Like notices, the per-app gate keeps careless apps in their lane. It doesn't stop a hostile one: gall lets an agent name any origin for its poke. That's the same trust a ship already places in what it installs.

## Mixing ships and guests

A room can hold both. A ship-hosted party line whose roster has ships can also take invite guests. Members still join with `%join-room` and their `@p`; guests join with invites. An app room can also seat a ship that uses the app, as a guest whose readable name is its `@p`. Its username stays `guest-…`, because the ship hasn't signed anything; the app vouched for it. A client that wants the ship's own seat uses `%join-room` on a room the ship hosts as a member.

## What changes in trunk

- **Wire 16.** New actions: `invite-guests`, `revoke-invite`, `list-invites` (owner); `app-room-open`, `app-room-close`, `app-room-rotate`, `app-guest-ticket` (local agents). New facts: `guest-invite`, `invites`, `guest-ticket`, `guest-denied`. All of it lives in `lib/trunk-json.hoon`. No existing action or fact changes shape.
- **State N+1.** It adds three things, with a migration from every older state:
  - the invites per room: code, speak, expiry, uses left, and the guest ids issued
  - the app rooms: agent, room, epoch, guests by app id, last ticket time
  - the per-app hosting switches, and the global "Apps may host calls" switch, off
- **Minting.** Guests use `+mint` and `+mint-listen` in `lib/trunk-jwt.hoon` with a guest `sub`; the library itself doesn't change. A new pure arm makes the guest id from the ship's entropy.
- **The guest page.** `app/trunk/guest.html`, beside `page.html`, built in with `/*`. It's a page for strangers, so it carries no owner data: only the room's title, the host's `@p` and the join form.
- **The trunk page** lists live invites with a revoke button, and the apps that host calls with their switches.
- **Security invariants**, added to AGENTS.md:
  - A guest's `sub` never starts with `~`.
  - Trunk mints a guest's id; the client never names it.
  - Only the agent that opened an app room acts on it.
  - The guest route takes nothing but a code, a name and, on renewal, the guest id it issued.
- **Tests,** in a new `gen/test-guest.hoon`:
  - invite expiry and use counting, each as a pair (the last use allowed, one more refused)
  - renewal keeping the guest id
  - a revoked code refused
  - an app refused another app's room
  - rotation changing the location
  - a guest `sub` never looking like an `@p`

## What has to be true outside trunk

- **Galène must speak TLS before any guest uses it.** Today it runs `-insecure` on plain http :8444. A page served over https, which every invite page and every app's page will be, cannot open a plain `ws://` socket at all: the browser blocks mixed content. This is the known weakness in the sidecar notes, and it becomes a blocker. The fix is an nginx vhost with a certificate in front of :8444 (for example `sfu.nisfeb.com`), and pointing `%set-sfu` at its https base. Party lines for ships get the same protection for free.
- **TURN for guests.** Galène's built-in TURN (:1194) and coturn (:3479) already serve members. Guests use the same ICE servers through Galène; nothing new is needed.
- **Capacity.** Guests use the same SFU as members. One small Galène handles dozens of speakers; a ship that hosts busy public rooms should run its own sidecar, which `%set-sfu` already allows per room.

## Worked example: the MUD's party voice

The MUD on Urbit (`%mud-world`) seats players as guests (browser cookies) and as citizens (ships), all through the world ship's own web pages. Its party voice was first built as a peer-to-peer WebRTC mesh signalled through `%mud-world` (nisfeb/mud, DESIGN-audio-mode.md, phase 3). With guest seats it becomes:

1. The world's owner turns on "Apps may host calls" for `mud-world` on the trunk page.
2. A party forms in the game. `%mud-world` sends `app-room-open` for `party-<group id>`.
3. A player presses Join party voice. `%mud-world` checks they're in that party, which it already does, and sends `app-guest-ticket` with the player's session as the app's id and their character name as the readable name.
4. `%mud-world` relays the `guest-ticket` to that player's browser. The browser joins Galène with `protocol.js`, so its push-to-talk, mute and speaking dots work on Galène's streams.
5. Someone leaves or is kicked: `%mud-world` sends `app-room-rotate` and re-tickets the rest.
6. The party disbands: `app-room-close`.

The MUD drops its own signalling relay, its ICE handling and its coturn script. It keeps its party rules, its voice bar and its settings.

## Size

| Piece | Estimate |
|---|---|
| Invites (actions, state, the guest route and page, renewal, revocation) | 2 days |
| App rooms (actions, the /app path, owner switches, rotation, limits) | 2 days |
| Migration, `gen/test-guest.hoon`, the trunk page lists, docs | 1 day |
| Galène TLS (nginx vhost, DNS, `%set-sfu`) | half a day, outside the desk |

Talon needs nothing to keep working. It can show guests, by their `guest-` usernames and `data.name`, whenever it likes.

## Open questions for trunk's maintainers

1. **One switch or two?** Should invite links need the "Apps may host calls" switch too, or only the owner's own action? Proposed: invites need only the owner's action, since the owner makes each one.
2. **Guest TTL.** An hour, renewable while the invite or the app vouches. Shorter costs more renewals; longer delays a revocation.
3. **The guest page's home.** Serve it from the ship (`/apps/trunk/guest/<code>`, proposed: it works for any ship with a URL), or from the sidecar beside the listen page (which works for ships with no public URL, but then the sidecar must reach the ship to check codes)?
4. **Galène moderation.** Galène can kick a user with an `op` token. Should trunk hold an op connection per room so a host can remove a guest at once, rather than by rotation within the hour? Proposed: rotation first, since it needs no live connection; an op kick later.
