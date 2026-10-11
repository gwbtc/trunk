# Trunkline sidecar

Two services next to your ship, on the machine your ship already runs
on. Neither is required — without them Talon still makes Tier 0 calls
(same LAN, public IPv6) — but together they cover the hostile-NAT
fallback and let you *host* party lines.

| Service | Gives you | Needed by |
|---|---|---|
| coturn | STUN echo (Tier 1) + TURN relay (Tier 2) | 1:1 calls across hostile NAT |
| galene | the SFU party lines run on | hosting a party line |

One sidecar anywhere between two callers covers that call, so running
one upgrades every call made *to* you. For why coturn exists at all
when Galène already ships a TURN server — and what each service is
actually on the critical path for — see "What the sidecar is actually
for" in `docs/design.md`.

## 1. Generate the party-line signing key

`%trunk` signs join tickets with an HS256 secret that Galène also
holds. Generate 32 random bytes, base64url:

```bash
umask 077
KEY=$(head -c 32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=')
echo "$KEY"
```

Write the Galène group config (one group; rooms are subgroups created
on demand). The key is the whole gate: anyone who holds it can mint a
token for any room in the group, under any name, with any permission,
moderation included. Keep the file private, and keep it out of anything
you publish.

```bash
mkdir -p galene/groups galene/data
cat > galene/groups/talon.json <<EOF
{
  "authKeys": [{"kty": "oct", "alg": "HS256", "k": "$KEY"}],
  "auto-subgroups": true,
  "public": false
}
EOF
echo '{}' > galene/data/config.json
```

Note the mixed spelling: `authKeys` is camelCase, `auto-subgroups` is
kebab — Galène wants exactly that, and rejects the file otherwise.

**One group per host ship.** If several ships host lines on one
sidecar, give each its own group file and key, such as
`groups/<ship>.json`, and point each ship at its own group in step 3.
Every ship that holds a group's key can join, hear and moderate every
room in that group. Separate groups keep one host out of another's
lines, and one host's key can then be changed without touching the
others. A key built into a client app, as Talon's fallback sidecar is,
is a key everyone holds.

## 2. Run

```bash
TURN_PASS=$(openssl rand -hex 16) docker compose up -d
```

Open UDP 3478 and 49160-49200 (coturn), and 443 for the TLS front.
Do not open 8444: the compose file binds Galène to 127.0.0.1, and
every ticket travels in the websocket's first message, which plain
http would carry in the clear. Put the TLS front in step 5 up before
you point a ship at Galène. Galène has a public address, so most
clients reach it directly and party lines need no TURN.

The compose file turns Galène's own TURN server off (`-turn ''`). It
relays to any address, the host's loopback included, and Galène gives
its password to everyone who joins, guests too. With it on, anyone
holding a call link could reach services that listen only on the
host's loopback, such as a ship's loopback HTTP port. Keep it off.

The compose file also keeps coturn from relaying into private
addresses (`--denied-peer-ip` for each private range): its password is
static and reaches every device, so whoever reads it once must not get
a way into your network.

To give party-line clients a relay as well, for networks that block
UDP, point Galène at coturn in `galene/data/ice-servers.json`, with the
port and password the compose file used:

```json
[{"urls": ["turn:calls.example.com:3478", "turn:calls.example.com:3478?transport=tcp"],
  "username": "talon", "credential": "THE_TURN_PASS"}]
```

Galène gives this password to everyone who joins, guests too, and it
also lists it to anyone who sends an OPTIONS request to a group's
`.whip` path. So do this only with coturn hardened as above, and only
behind a TLS front that closes `.whip` (step 5). Galène rereads the file
within five minutes.

## 3. Point your ship at it

From the ship's dojo, once:

```
:trunk &trunk-action [%set-ice ~[['stun:your.host:3478' '' ''] ['turn:your.host:3478' 'talon' 'THE_TURN_PASS']]]
:trunk &trunk-action [%set-sfu ['https://calls.example.com' 'talon' 'THE_KEY']]
```

The dojo keeps both secrets in its history. An `http://` base is for a
test on one machine only.

Clients scry `/x/ice` at startup and hand the result to the call
engine — nothing to configure app-side. Party-line tickets are minted
on demand by whichever ship hosts the room.

## 4. The listen page

`%trunk` mints listen links to `<sfu base>/listen/`. The page is three files, `index.html`, `listen.js` and `listen.css`: Galène serves its static files with a Content-Security-Policy that blocks inline scripts and styles. The compose file mounts `listen/` read-only at Galène's `/static/listen`, so the page is there once Galène is up. To change it later without recreating the container, and so without dropping anyone on a line, edit the files and also `docker cp listen/. <galene container>:/static/listen/`. A TLS front that serves `/listen/` itself, rather than passing it to Galène, needs all three files too.

The page shows each person by the name their client put in Galène's per-user data (`{"name": ...}`), with the username the host signed into their ticket beside it when the two differ, so nobody passes as another ship. A guest (wire 16), whose username is `guest-` and hex, is always marked as one.

A listen link is a bearer link: anyone who has it can listen, watch any camera or shared screen, and see who is on the line, until it expires (an hour at most). It cannot be revoked. Its token rides in the fragment (`#token=`), so it stays out of server logs, but it stays in browser history and in whatever chat it was pasted into.

## 5. Guests (wire 16 and 17)

People with no ship join through a page the ship serves, and an app on the ship may serve its own. Galène refuses a websocket from another origin, so list the ship's origin in `galene/data/config.json`. Galène re-reads the file when it changes, so no restart is needed:

```json
{"proxyURL": "https://calls.example.com",
 "allowOrigin": ["https://your.ship.example"]}
```

If the ship's pages are https, Galène must be too: a browser will not let an https page load `protocol.js` from, or open a websocket to, plain http. Put a TLS front before :8444, such as this nginx vhost, and get it a certificate with `certbot --nginx -d calls.example.com`, which adds the `listen 443 ssl` lines:

```nginx
server {
    server_name calls.example.com;
    # Galène's admin API: closed while no admin is configured, and
    # never needed from outside
    location /galene-api/ { return 404; }
    # WHIP is unused, and an OPTIONS there lists Galène's ICE servers,
    # TURN password included, to anyone
    location ~ "/\.whip$" { return 404; }
    location / {
        proxy_pass http://127.0.0.1:8444;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        # a party line is a long-lived socket
        proxy_read_timeout 24h;
        proxy_send_timeout 24h;
        proxy_buffering off;
    }
}
```

Set `proxyURL` to that host, as above, so Galène's `.status` names it. Once the front works, close :8444 to the outside: nginx reaches it over loopback. Then point `%set-sfu` at the https base:

```
:trunk &trunk-action [%set-sfu ['https://calls.example.com' 'talon' 'THE_KEY']]
```

Galène checks only the path of a ticket's address, not its host, so tickets minted before the switch still join.

### A short link for permanent guest links

A permanent link (wire 17) lives on the ship, at `https://your.ship.example/apps/trunk/guest/<name>`. To share it as `https://calls.example.com/<name>` instead, add this inside the TLS vhost's `server` block. It skips Galène's own one-segment paths:

```nginx
location ~ "^/(?!(?:ws|group|recordings|galene-api|listen|example|third-party)$)([a-z][a-z0-9-]{2,63})$" {
    return 302 https://your.ship.example/apps/trunk/guest/$1;
}
```
