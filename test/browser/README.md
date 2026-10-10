# Browser checks

End-to-end checks of trunk's three pages, run in headless Chromium against a fake ship and a local Galène. The Hoon checks in `gen/` cannot see the pages, so run these after any change to `app/trunk/guest.html`, `app/trunk/page.html`, `sidecar/listen/`, or the guest routes and their JSON.

`check.mjs` signs in as the ship's owner and opens a party line called `browser-check` with a permanent link of the same name. It runs the checks, then revokes the link and closes the line. Each check prints `ok` or `BAD`, and the run ends with `PASS` or `FAIL`.

| Part | What it checks |
|---|---|
| `guest` | Two guests hear each other. A guest alone is told others will appear. A speaking ring lights. A reload keeps the name and rejoins as the same guest. Leaving while muted rejoins unmuted. |
| `video` | Camera frames reach the others. A late joiner sees an existing camera. Mute shows. A screen share replaces the camera on the same tile. Video off is seen. |
| `page` | On the trunk page, "New line…" with a link name makes a line and a permanent link in one step. The new link is marked, with Copy focused. |
| `listen` | The listen page joins through Galène, is styled, and shows the guest speaking. It runs only when `LISTEN` is set. |

## Setup

1. **A fake ship with the desk.** Install `%trunk` on a fake ship as the main README's "The desk" says.
2. **A local Galène 1.1.** Build it from `https://github.com/jech/galene` at tag `galene-1.1`, or use the sidecar's compose file. It needs a group file `groups/talon.json` with `"auto-subgroups": true` and an HS256 key (`sidecar/README.md`, step 1), and a `data/config.json` that lets the fake ship's pages in:

   ```json
   {"allowOrigin": ["http://localhost:8080"]}
   ```

   Run it without TURN, which nothing on one machine needs:

   ```bash
   ./galene -insecure -http 127.0.0.1:8445 -turn '' -data data -groups groups -static static
   ```

   For the listen check, copy `sidecar/listen/` into its `static/listen/`.
3. **Point the ship at it**, from the dojo:

   ```
   :trunk &trunk-action [%set-sfu ['http://127.0.0.1:8445' 'talon' 'THE_KEY']]
   ```

4. **The checks' one dependency**, with Node 18 or later:

   ```bash
   cd test/browser
   npm install
   ```

## Running

```bash
SHIP=http://localhost:8080 CODE=<the ship's +code> BROWSER=/usr/bin/chromium node check.mjs
```

`BROWSER` is any Chromium-based browser: Chromium, Chrome or Brave. Name one part to run only it, such as `node check.mjs video`.

The listen check needs a listen link to the `browser-check` line. Mint its token in the dojo with the group key and the line's address, where the subgroup is the ship's name without the `~`, then `-browser-check`:

```
+trunk!token 'THE_KEY' 'listener' 'http://127.0.0.1:8445/group/talon/zod-browser-check/' 1800
```

```bash
LISTEN='http://127.0.0.1:8445/listen/?token=<the token>' SHIP=... CODE=... BROWSER=... node check.mjs
```

The microphone is a test tone the script writes to the system's temp folder: 440 Hz, on for 0.7 s of every second. Chrome's own fake microphone beeps too briefly for the speaking checks to catch.
