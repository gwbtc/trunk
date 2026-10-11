# Notes for coding agents

Read the README first for what trunk is and its wire, `docs/design.md` for how it fits together, and `docs/notifications.md` for the notification API other apps use. This file is what you need to change the code safely.

## Layout

- `app/trunk.hoon`: the agent. One door of ten arms, and a helper core (`hc`) below it with everything else. State versions, their migrations and the wire version are at the top.
- `app/trunk/page.html` and `app/trunk/icon.svg`: the owner's page and the tile's icon, built into the agent with `/*`.
- `lib/trunk-push.hoon`: pure push logic, with no scries and no cards: what notifies, every push body, retries, ring bookkeeping, sender records and the debug report. Keep it pure so `gen/test-push.hoon` can cover it.
- `lib/trunk-guest.hoon`: pure guest-seat logic (wire 16 and 17): guest secrets and ids, invite codes and link names, who an invite or a permanent link seats, app-room seats and SFU locations. `gen/test-guest.hoon` covers it.
- `app/trunk/guest.html`: the public page a guest opens from a link: audio, video and screen sharing.
- `app/trunk/protocol.js`: Galène 1.1's own client library, unmodified (MIT), served to the guest page from the ship. Change it only to match the call server's Galène version. It publishes the way Talon does (see `docs/guest-seats.md`, "Video and screen sharing"), so change it and Talon together.
- `lib/trunk-json.hoon`: the wire's JSON. Talon mirrors it by hand.
- `lib/trunk-jwt.hoon`: Galène's HS256 tokens. `lib/mnemonym.hoon`: comet names.
- `sur/trunk.hoon`: the types, including every action.
- `gen/test-*.hoon`: checks to run on a ship. Each answers `%ok` or names the cases that failed.
- `sidecar/`: coturn, Galène and the listen page, which is not part of the desk.

## The rules that keep a ship running

- **Bump the wire for any JSON change.** `+wire-version` in `app/trunk.hoon` tells clients what the desk speaks. Every drift so far showed up as a silent no-op in a client, never as an error. Talon's `WIRE_VERSION` is the oldest wire it needs, so it moves only when Talon starts to use a new shape. Tell its maintainers about every bump anyway.
- **Keep old pokes working.** Clients and other apps on deployed ships send the current nouns. Add a new action rather than changing the shape of one that has shipped: `%push-notice-as` sits beside `%push-notice` for that reason.
- **A new state version for any change to stored state.** Add `state-N`, add it to `versioned-state`, and make every older branch of `+on-load` produce `state-N` directly. Never have an old state version name a type alias that may change later (such as `rung:trunk-push`). Pin it to the shape it was saved with, or `!<` fails when the alias moves and the agent will not load. A field that the migration drops can be pinned loosely as `*`.
- **Grubbery apps must name themselves, and grubbery keeps its own copy of the notice actions.** Every grubbery app reaches trunk as `%grubbery`, so it must send `push-notice-as` with its own name. Otherwise all grubbery apps are one sender, with one switch, one gap and one hourly limit, and their notices get merged. Grubbery's kernel checks each poke to trunk with its own marc, `/code/mar/clay/trunk/trunk-action.hoon`, which types only the notice actions. To change a notice action's shape or add one, change that marc in grubbery too, and in order: trunk on the ship first, then the marc. A marc that types a case the ship's trunk lacks makes that trunk refuse every grubbery notice, because trunk's `!<` checks the marc's whole type. `docs/notifications.md` has the rules for app authors.
- **Start from explicit defaults.** The bunt of a union is its last case, so `+on-init` and every migration set the call policy to `open-policy` and the push switches to `+all-kinds:trunk-push`. A bunted policy refuses every caller, and bunted switches turn channel posts off.
- **Test the upgrade, not just the new code.** Install the released version on a fake ship, give it state (devices, rooms, a policy), then commit your branch and check that the state came through.
- **Never crash on a fact or an answer.** A crash in `+on-agent` on a fact makes gall close the subscription. `on-arvo:def` crashes on any wire you did not match, so handle every iris response (`%progress`, `%cancel`, `%finished`) and every timer wire you set. Wires change shape over versions, so keep matching the old shape while requests sent by the old code can still answer.

## Hoon traps this code has hit

- **Gall's own scry cares need a trailing `$`:** `/gu/<ship>/<agent>/<case>/$`, and likewise `/gd`. Without it the scry goes to the agent with an empty path and blocks.
- **A blocked or failed scry is not caught by `mule` or `mole`.** It escapes them and crashes the event. Guard a scry with one that cannot fail first (`%gu` for an agent, `%cd` for desks), rather than wrapping it.
- **Gall converts an `%x` scry to the mark you ask for,** with a tube from the agent's desk. A missing tube is a block, not a crash.
- **Narrowing a leg narrows the whole state.** `?~ n.badge.state` or `?=(~ push.s)` narrows the state's type, and a later `=^ x state` then nest-fails. Bind the leg to a face first, or test with `=(~ x)`.
- **`(scag n [x list])` keeps the non-empty cell type.** Cast the list first. The same goes for any wet gate given a literal cell.
- **`~(gut by m) [default]` loses the value's faces** when the default is a bare tuple. Annotate the result.
- **An apostrophe ends a cord.** Test names like `'the device's id'` are a syntax error.
- **Eyre gives a signed-out HTTP request a guest identity,** so `+on-watch` must accept `/http-response/@` before any `src.bowl == our.bowl` check.
- **`sap.bowl` says where a poke came from:** `/gall/<agent>` for another agent, `/eyre` for the owner's web session and Talon, `/gall/dojo` for the dojo. `+by-owner` uses it to keep settings out of other agents' hands. It is not proof: gall lets an agent name any origin for a poke it sends, so it guards against careless apps only.
- **`+tuba` crashes on control bytes and bad UTF-8.** Text from a chat reaches it in `+preview`, which drops control bytes and runs under `mole`.

## Security invariants

- `%trunk-action` is accepted only from our own ship. Another agent may send `push-notice`, `push-notice-as` and the four `app-*` room actions, and nothing else. Every other action, settings, invites and the device registry included, needs `+by-owner`. Keep that allowlist at the top of the `%trunk-action` arm, which the page's action route goes through too.
- An app reaches only its own rooms: app rooms are keyed by the agent gall names in `sap.bowl`, and `/app/<agent>` admits only that agent.
- A guest's Galène `sub` is a guest id, `guest-` and 24 hex digits. It never starts with `~`. A link guest's id is the hash of a secret only their page holds (`+id-of`), so nobody else can rejoin as them. An app guest's id is one trunk makes. Neither a guest nor an app ever names an id.
- `/calls` carries invite codes, listen links and our own tickets, so only the owner's sessions (`+by-owner`) may watch it. An app gets its answers on `/app/<agent>`.
- Only our own ship sets a line's own SFU. A line another ship opens on ours runs on our SFU, under a name that is one clean URL segment, and a remote admin's `%configure` cannot move it to another server. A room's own SFU key never leaves through a scry.
- The guest page loads only the ship's own copy of `protocol.js`, never the call server's: the page runs on the ship's origin.
- The guest routes under `/apps/trunk/guest/` are public. They take nothing but a link's code and a guest's secret, and show nothing of the host but its name and the room's title. Codes, link names and secrets are bearer secrets, so they are never in `/x/debug`.
- A signal's sender is the ames `src`, never anything in the payload.
- A ship's Galène token has its `@p` as `sub`, for every ship, and a guest's has its guest id (below). Galène refuses any later message whose username differs, so a readable name travels in Galène's per-user data instead.
- The debug report (`/x/debug`) never carries a push secret, a gateway handle, an endpoint's path or a chat's id. `gen/test-push.hoon` checks this, so extend that test when you add a field.
- Push bodies are built by hand in a fixed key order, and the tests pin their bytes. Talon parses them, so a change to a body is a change to the wire.

## Testing

Boot fresh fake galaxies from the v4.6 pill: it ships Tlon's `%groups`, so `%activity` and `%settings` are real. Never reuse a fake ship's name after rebuilding its pier, since peers keep ames state for the old one and pokes vanish without an error.

Install the desk as the README's "The desk" says, then run `+trunk!test-push`, `+trunk!test-guest` and `+trunk!test-mnemonym`. For any change to the guest page, the trunk page, the listen page or the guest routes, also run the browser checks in `test/browser/` (its README has the setup). For push work, register a device whose endpoint is a local HTTP listener, then drive real events: DMs and channel posts between two fake ships, reads through `%activity`'s `read` action, and rings with `%send`.

`|commit` adds and changes files in a desk but does not delete them. Remove a file from a mounted desk with `|rm`.

## Commits

Commit messages follow Doom Emacs's conventions, and a hook enforces them: a type prefix (`feat`, `fix`, `docs`, `refactor`, `test`, ...), no scope, a subject of at most 72 characters (50 is ideal), and body lines of at most 72. Add no AI attribution. In prose (docs, comments, commit messages) write short, plain sentences and no em dashes.
