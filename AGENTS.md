# Notes for coding agents

Read the README first for what trunk is and its wire, `docs/design.md` for how it fits together, and `docs/notifications.md` for the notification API other apps use. This file is what you need to change the code safely.

## Layout

- `app/trunk.hoon`: the agent. One door of ten arms, and a helper core (`hc`) below it with everything else. State versions, their migrations and the wire version are at the top.
- `app/trunk/page.html` and `app/trunk/icon.svg`: the owner's page and the tile's icon, built into the agent with `/*`.
- `lib/trunk-push.hoon`: pure push logic, with no scries and no cards: what notifies, every push body, retries, ring bookkeeping, sender records and the debug report. Keep it pure so `gen/test-push.hoon` can cover it.
- `lib/trunk-json.hoon`: the wire's JSON. Talon mirrors it by hand.
- `lib/trunk-jwt.hoon`: Galène's HS256 tokens. `lib/mnemonym.hoon`: comet names.
- `sur/trunk.hoon`: the types, including every action.
- `gen/test-*.hoon`: checks to run on a ship. Each answers `%ok` or names the cases that failed.
- `sidecar/`: coturn, Galène and the listen page, which is not part of the desk.

## The rules that keep a ship running

- **Bump the wire for any JSON change.** `+wire-version` in `app/trunk.hoon` tells clients what the desk speaks. Every drift so far showed up as a silent no-op in a client, never as an error. Talon's tests pin the number too, so tell its maintainers.
- **Keep old pokes working.** Clients and other apps on deployed ships send the current nouns. Add a new action rather than changing the shape of one that has shipped: `%push-notice-as` sits beside `%push-notice` for that reason.
- **A new state version for any change to stored state.** Add `state-N`, add it to `versioned-state`, and make every older branch of `+on-load` produce `state-N` directly. Never have an old state version name a type alias that may change later (such as `rung:trunk-push`). Pin it to the shape it was saved with, or `!<` fails when the alias moves and the agent will not load. A field that the migration drops can be pinned loosely as `*`.
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

- `%trunk-action` is accepted only from our own ship. Another agent may send `push-notice` and `push-notice-as` and nothing else. Every other action, settings and the device registry included, needs `+by-owner`. Keep that allowlist at the top of the `%trunk-action` arm, which the page's action route goes through too.
- A signal's sender is the ames `src`, never anything in the payload.
- A Galène token's `sub` is the asking ship's `@p`, for every ship. Galène refuses any later message whose username differs, so a readable name travels in Galène's per-user data instead.
- The debug report (`/x/debug`) never carries a push secret, a gateway handle, an endpoint's path or a chat's id. `gen/test-push.hoon` checks this, so extend that test when you add a field.
- Push bodies are built by hand in a fixed key order, and the tests pin their bytes. Talon parses them, so a change to a body is a change to the wire.

## Testing

Boot fresh fake galaxies from the v4.6 pill: it ships Tlon's `%groups`, so `%activity` and `%settings` are real. Never reuse a fake ship's name after rebuilding its pier, since peers keep ames state for the old one and pokes vanish without an error.

Install the desk as the README's "The desk" says, then run `+trunk!test-push` and `+trunk!test-mnemonym`. For push work, register a device whose endpoint is a local HTTP listener, then drive real events: DMs and channel posts between two fake ships, reads through `%activity`'s `read` action, and rings with `%send`.

`|commit` adds and changes files in a desk but does not delete them. Remove a file from a mounted desk with `|rm`.

## Commits

Commit messages follow Doom Emacs's conventions, and a hook enforces them: a type prefix (`feat`, `fix`, `docs`, `refactor`, `test`, ...), no scope, a subject of at most 72 characters (50 is ideal), and body lines of at most 72. Add no AI attribution. In prose (docs, comments, commit messages) write short, plain sentences and no em dashes.
