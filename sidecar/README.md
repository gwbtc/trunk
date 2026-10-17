# Trunkline sidecar

Two services next to your ship, on the machine your ship already runs on. Neither is required. Without them Talon still makes Tier 0 calls (same LAN, public IPv6), but together they cover the hostile-NAT fallback and let you *host* party lines.

| Service | Gives you | Needed by |
|---|---|---|
| coturn | STUN echo (Tier 1) + TURN relay (Tier 2) | 1:1 calls across hostile NAT |
| galene | the SFU party lines run on | hosting a party line |

One sidecar anywhere between two callers covers that call, so running one upgrades every call made *to* you. For why coturn exists at all when Galène already ships a TURN server, and what each service is actually on the critical path for, see "What the sidecar is actually for" in `docs/design.md`.

## 1. Generate the party-line signing key

`%trunk` signs join tickets with an HS256 secret that Galène also holds. Generate 32 random bytes, base64url:

```bash
umask 077
KEY=$(head -c 32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=')
echo "$KEY"
```

Write the Galène group config (one group, whose rooms are subgroups created on demand). The key is the whole gate. Anyone who holds it can mint a token for any room in the group, under any name, with any permission, moderation included. Keep the file private, and keep it out of anything you publish.

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

Note the mixed spelling: `authKeys` is camelCase, `auto-subgroups` is kebab. Galène wants exactly that, and rejects the file otherwise.

**One group per host ship.** If several ships host lines on one sidecar, give each its own group file and key, such as `groups/<ship>.json`, and point each ship at its own group in step 3. Every ship that holds a group's key can join, hear and moderate every room in that group. Separate groups keep one host out of another's lines, and one host's key can then be changed without touching the others. A key built into a client app, as Talon's fallback sidecar is, is a key everyone holds.

## 2. Run

```bash
umask 077
[ -f .env ] || echo "TURN_PASS=$(openssl rand -hex 16)" > .env
docker compose up -d
```

The first run writes the TURN password into `.env`, which only you can read, and later runs keep it. Compose reads `.env` on every command. Keep the file, since your ships advertise this password (step 3).

Open 3478 for both UDP and TCP, since clients fall back to TURN over TCP, and UDP 49160-49200, for coturn. Open TCP 443 for the TLS front. Do not open 8444. The compose file binds Galène to 127.0.0.1, so 8444 is never reachable from outside, and plain http would carry every ticket in the clear in the websocket's first message. Put the TLS front in step 5 up before you point a ship at Galène. Galène has a public address, so most clients reach it directly and party lines need no TURN.

On a cloud that puts the machine behind a 1:1 NAT, such as AWS, GCP or Oracle, the machine sees only its private address, so coturn would hand out an address nobody can reach. Add `--external-ip=<public ip>/<private ip>` to coturn's command in the compose file.

The compose file turns Galène's own TURN server off (`-turn ''`). It relays to any address, the host's loopback included, and Galène gives its password to everyone who joins, guests too. With it on, anyone holding a call link could reach services that listen only on the host's loopback, such as a ship's loopback HTTP port. Keep it off.

The compose file also keeps coturn from relaying into private addresses (`--denied-peer-ip` for each private range). Its password is static and reaches every device, so whoever reads it once must not get a way into your network.

To give party-line clients a relay as well, for networks that block UDP, point Galène at coturn in `galene/data/ice-servers.json`, with the port and password the compose file used:

```json
[{"urls": ["turn:calls.example.com:3478", "turn:calls.example.com:3478?transport=tcp"],
  "username": "talon", "credential": "THE_TURN_PASS"}]
```

Galène gives this password to everyone who joins, guests too, and it also lists it to anyone who sends an OPTIONS request to a group's `.whip` path. So do this only with coturn hardened as above, and only behind a TLS front that closes `.whip` (step 5). Galène rereads the file within five minutes.

## 3. Point your ship at it

From the ship's dojo, once:

```
:trunk &trunk-action [%set-ice ~[['stun:your.host:3478' '' ''] ['turn:your.host:3478' 'talon' 'THE_TURN_PASS']]]
:trunk &trunk-action [%set-sfu ['https://calls.example.com' 'talon' 'THE_KEY']]
```

The https base needs the TLS front from step 5, so build that first. Until then, an `http://127.0.0.1:8444` base works only for a test on this one machine. `%set-sfu` refuses a key that is not base64url, and an empty key means no call server. The TURN password is the one in `.env`. The dojo keeps both secrets in its history.

Clients scry `/x/ice` at startup and hand the result to the call engine, with nothing to configure app-side. Party-line tickets are minted on demand by whichever ship hosts the room.

## 4. The listen page

`%trunk` mints listen links to `<sfu base>/listen/`. The page is three files, `index.html`, `listen.js` and `listen.css`, because Galène serves its static files with a Content-Security-Policy that blocks inline scripts and styles. The compose file mounts the `listen/` folder read-only at Galène's `/static/listen`, so the page is there once Galène is up. Files in a mounted folder update live, so to change the page, edit the files. There is no need to recreate the container, which would drop everyone on a line, and no `docker cp`, which fails on a read-only mount. A TLS front that serves `/listen/` itself, rather than passing it to Galène, needs all three files too.

The page shows each person by the name their client put in Galène's per-user data (`{"name": ...}`), with the username the host signed into their ticket beside it when the two differ, so nobody passes as another ship. A guest (wire 16), whose username is `guest-` and hex, is always marked as one.

A listen link is a bearer link. Anyone who has it can listen, watch any camera or shared screen, and see who is on the line, until it expires (an hour at most). It cannot be revoked. Its token rides in the fragment (`#token=`), so it stays out of server logs, but it stays in browser history and in whatever chat it was pasted into.

### The join page (wire 19)

An app's guest link, such as a calendar event's call, opens at `<sfu base>/join/#<ship's host>/<code>`. The join page is trunk's own guest page: `app/trunk/guest.html` as `index.html`, with `guest.js` and `guest.css` beside it. The compose file mounts the `join/` folder read-only at Galène's `/static/join`, as it does `listen/`. Fill it from a checkout of this repo, and again whenever trunk's guest page changes:

```bash
mkdir -p join
cp ../app/trunk/guest.html join/index.html
cp ../app/trunk/guest.js ../app/trunk/guest.css join/
```

Files in a mounted folder update live, so the new copies are served at once, with no restart and no `docker cp`. On a call server that is not a checkout of this repo, copy the three files there from one.

The page fetches nothing from the ship, since Galène's CSP would refuse it. It sends the guest to the ship's guest page, which sends them back with a ticket in the fragment, and the call runs on Galène's own origin. So the join page needs no `allowOrigin` entry, and a new ship on this server needs no change here. `docs/guest-seats.md`, "The join page", has the steps.

## 5. Guests (wire 16 to 19)

People with no ship join through a page the ship serves, and an app on the ship may serve its own. Galène refuses a websocket from another origin, so list the ship's origin in `galene/data/config.json`. Galène re-reads the file when it changes, so no restart is needed. Guests from an app's link (wire 19) instead join on the join page from step 4, on Galène's own origin, which needs no entry.

```json
{"proxyURL": "https://calls.example.com",
 "allowOrigin": ["https://your.ship.example"]}
```

If the ship's pages are https, Galène must be too. A browser will not let an https page load `protocol.js` from, or open a websocket to, plain http. Apps' links need the schemes to match too. Trunk refuses to make one while the ship's public address and the call server differ in http or https. Put a TLS front before :8444, such as this nginx vhost, and get it a certificate with `certbot --nginx -d calls.example.com`, which adds the `listen 443 ssl` lines:

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

Set `proxyURL` to that host, as above, so Galène's `.status` names it. Port 8444 stays closed to the outside, since the compose file binds it to loopback, and nginx reaches it there. If step 3 used the `http://` base for a test, point `%set-sfu` at the https base now:

```
:trunk &trunk-action [%set-sfu ['https://calls.example.com' 'talon' 'THE_KEY']]
```

Galène checks only the path of a ticket's address, not its host, so tickets minted before the switch still join.

### A short link for permanent guest links

A permanent link (wire 17) lives on the ship, at `https://your.ship.example/apps/trunk/guest/<name>`. To share it as `https://calls.example.com/<name>` instead, add this inside the TLS vhost's `server` block. It skips Galène's own one-segment paths:

```nginx
location ~ "^/(?!(?:ws|group|recordings|galene-api|listen|join|example|third-party)$)([a-z][a-z0-9-]{2,63})$" {
    return 302 https://your.ship.example/apps/trunk/guest/$1;
}
```
