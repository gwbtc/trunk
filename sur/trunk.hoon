::  trunk: call signaling over ames.
::
::  1:1 calls are peer-to-peer: the agent only routes opaque SDP.
::  Party lines are host-centered: the group host's sidecar runs an SFU
::  (Galène), and the host's %trunk mints per-member, per-room join
::  tickets — the trust boundary the host already has for the group's
::  messages, extended to its audio.
|%
::  one signaling message. ids are client-minted opaque strings (uuid).
::  sdp is a complete (non-trickle) session description; fpr is the
::  DTLS certificate fingerprint the client pins the media session to.
+$  sig
  $%  [%ring id=@t]
      [%offer id=@t sdp=@t fpr=@t]
      [%accept id=@t sdp=@t fpr=@t]
      [%reject id=@t reason=@t]
      [%hangup id=@t]
  ==
::  one ICE server this ship advertises to its clients (the icepond
::  role): a STUN or TURN url plus static credentials (empty for STUN).
+$  ice-server  [url=@t user=@t cred=@t]
::  our sidecar's SFU.
::    base:   origin, e.g. 'http://calls.example.com:8444'
::    group:  the ONE Galène group configured there, e.g. 'talon'.
::            It must have "auto-subgroups": true — every party line is
::            a subgroup created on first join, so hosting a new room
::            needs no server-side configuration.
::    key:    the group's HS256 secret, base64url — the same string as
::            the "k" field of Galène's authKeys entry.
+$  sfu-config  [base=@t group=@t key=@t]
::  who may ring us 1:1. The block set always applies; the mode only
::  decides what happens to everyone who isn't blocked.
::    %open   anyone may ring
::    %allow  only ships in the allow set may ring
::
::  This is ship-level on purpose: %trunk is the chokepoint every
::  client shares, so the policy holds for every device and for apps
::  other than the one that set it. It deliberately knows nothing
::  about %contacts — a client that wants "contacts only" keeps the
::  allow set in sync itself.
+$  call-mode  ?(%open %allow)
+$  policy  [mode=call-mode allow=(set ship) block=(set ship)]
::  a party line we host. members may join; anyone else is denied.
::
::    admins   ships that may reconfigure this room remotely. %trunk
::             has no idea what a Tlon group is — this is just a list
::             the host seeds, so a group's admins can turn the line
::             on or off without owning the host ship.
::    listen   may anonymous listen links be minted for this room?
::             Off by default: a party line is gated by the host's
::             membership list, and a public link deliberately punches
::             through that, so it must be asked for.
::    sfu      which sidecar this room runs on. ~ means "the ship's
::             own", which is the common case. A group that would
::             rather not route its audio through the host's sidecar
::             sets its own here — the host still mints the tickets,
::             but against the group's chosen server.
::  where a room's roster is mirrored from, when it is bound to a
::  group. %trunk still has no idea what a group IS — this is an
::  opaque [host name] pair used to build one scry path and one
::  subscription. Unbound rooms (~) behave exactly as before: the
::  host seeds members/admins by hand and nothing watches anything.
+$  group-source  [=ship name=@t]
::  role gates (wire 5). ~ for either gate means "everyone on the
::  roster", the only behavior before state-9 — so a bunted room is
::  exactly a wire-4 room. A set gate admits a member iff their
::  seat-roles entry intersects it; the host and admins bypass both
::  gates. muted is moderation and beats everything except the host.
::  seat-roles is mirrored from the bound group alongside members and
::  admins; role gating is only meaningful on bound rooms.
+$  room
  $:  title=@t
      members=(set ship)
      admins=(set ship)
      listen=?
      sfu=(unit sfu-config)
      ::  ~ = manual roster (the only mode before wire 4)
      group=(unit group-source)
      join-roles=(unit (set @t))
      speak-roles=(unit (set @t))
      muted=(set ship)
      seat-roles=(map ship (set @t))
  ==
::  a listen-only link: where to point a browser, and until when.
+$  listen-link  [name=@t url=@t expires=@ud]
::  authorization to join one room: where it is, and a short-lived
::  token scoped to exactly that room.
+$  ticket  [name=@t location=@t token=@t]
::  local client -> own agent
+$  action
  $%  [%send =ship =sig]
      [%set-ice servers=(list ice-server)]
      [%set-sfu =sfu-config]
      [%open-room name=@t title=@t members=(set ship) admins=(set ship)]
      ::  turn anonymous listening on or off for a room we host
      [%set-room-listen name=@t listen=?]
      ::  mint a listen link for a room we host. ttl is in seconds:
      ::  the link is a bearer token and Galene cannot revoke one, so
      ::  the lifetime is the whole security model.
      [%share-room host=ship name=@t ttl=@ud]
      ::  ask a REMOTE host to reconfigure a line we are an admin of.
      ::  The host checks that we are actually on its admin list.
      $:  %configure-room
          host=ship
          name=@t
          open=?
          listen=?
          sfu=(unit sfu-config)
          keep-sfu=?
          title=@t
          members=(set ship)
          admins=(set ship)
      ==
      [%close-room name=@t]
      [%join-room host=ship name=@t]
      ::  ask a host whether a line exists, without joining it. A
      ::  member whose ship had no %trunk when the host announced never
      ::  received it and has no other way to find out — scries are
      ::  local, so it cannot read the host's rooms directly.
      [%peek-room host=ship name=@t]
      ::  live presence (wire 6): tell the host we connected to / left
      ::  a line, and ask how many are on one. The client heartbeats
      ::  %enter-room while connected; %occupancy-of drives the count
      ::  a non-joined viewer shows.
      [%enter-room host=ship name=@t]
      [%leave-room host=ship name=@t]
      [%occupancy-of host=ship name=@t]
      ::  bind or unbind a hosted room's roster to a group. Bound,
      ::  the members/admins lists mirror the group and manual edits
      ::  are overwritten on the next sync; ~ unbinds and freezes the
      ::  roster as it stands.
      [%bind-room name=@t group=(unit group-source)]
      ::  role-gate a line: who may join, who may speak. ~ = everyone
      ::  on the roster. Applied locally when we host, relayed to the
      ::  host otherwise — who checks we are on its admin list.
      $:  %set-room-access
          host=ship
          name=@t
          join=(unit (set @t))
          speak=(unit (set @t))
      ==
      ::  mute (or unmute) one member of a line for everyone
      [%moderate-member host=ship name=@t who=ship mute=?]
      ::  ask a host for a line's current gates and mute set
      [%get-room-access host=ship name=@t]
      [%set-call-mode mode=call-mode]
      [%allow =ship]
      [%unallow =ship]
      [%block =ship]
      [%unblock =ship]
  ==
::  ship-to-ship room negotiation
+$  room-sig
  $%  [%ask name=@t]
      ::  same checks as %ask, but mints nothing and joins nothing.
      ::  Answered with %announce when the asker may see the line, and
      ::  %deny otherwise.
      [%peek name=@t]
      [%grant =ticket]
      [%deny name=@t why=@t]
      ::  the host telling a member a line is open / gone, so joining
      ::  is an invitation rather than a guess
      [%announce name=@t title=@t listen=? sfu-base=@t]
      [%shut name=@t]
      ::  an admin asking the host to mint a listen link, and the
      ::  host answering. Only the host has the key, so an admin of a
      ::  line hosted elsewhere has to ask.
      [%share name=@t ttl=@ud]
      [%link =listen-link]
      ::  a room admin, over ames, changing what the host hosts
      ::  title/members/admins are only used when the room does not
      ::  exist yet — a group admin turning the line on for the first
      ::  time, on a host ship that has never hosted it.
      $:  %configure
          name=@t
          open=?
          listen=?
          sfu=(unit sfu-config)
          ::  leave the room's server alone; see the action of the
          ::  same name.
          keep-sfu=?
          title=@t
          members=(set ship)
          admins=(set ship)
      ==
      ::  an admin, over ames, setting a line's role gates. ~ =
      ::  everyone on the roster. The host checks the asker is on its
      ::  admin list and answers with %access-state. New in wire 5:
      ::  an old desk nacks these at the mark cast, which the sender's
      ::  client surfaces — the designed compat story.
      [%access name=@t join=(unit (set @t)) speak=(unit (set @t))]
      ::  an admin muting (or unmuting) one member for everyone
      [%moderate name=@t who=ship mute=?]
      ::  an admin asking for the current gates without changing them
      [%get-access name=@t]
      ::  the host answering any of the three above
      $:  %access-state
          name=@t
          join=(unit (set @t))
          speak=(unit (set @t))
          muted=(set ship)
      ==
      ::  live presence (wire 6). A member tells the host it connected
      ::  to / left a line; %entered doubles as a heartbeat. %occupancy
      ::  asks the host how many are on a line right now; the host
      ::  answers %present. An old host nacks these, which the client
      ::  treats as "presence unavailable".
      [%entered name=@t]
      [%left name=@t]
      [%occupancy name=@t]
      [%present name=@t n=@ud]
  ==
::  a line another ship has invited us to. Carries enough for an admin
::  to see the current settings without owning the host ship; never the
::  SFU secret, only the base URL members will connect to anyway.
+$  line  [title=@t listen=? sfu-base=@t]
+$  lines  (map [=ship name=@t] line)
::  agent -> local client, on /calls
+$  update
  $%  [%recv from=ship =sig]
      [%ticket from=ship =ticket]
      [%denied from=ship name=@t why=@t]
      [%open from=ship name=@t =line]
      [%shut from=ship name=@t]
      ::  echoed after every policy change so a ship's other devices
      ::  converge without re-scrying
      [%policy =policy]
      ::  a freshly minted listen link, for the client to share
      [%listen-link =listen-link]
      ::  one of this ship's devices answered or declined a call, so
      ::  the rest can stop ringing. Every device sees the %ring — that
      ::  is the point — but until now nothing told the others it had
      ::  been dealt with, and they rang out their whole watchdog next
      ::  to a call already in progress.
      [%handled id=@t]
      ::  a line's role gates and mute set, echoed after every access
      ::  change and on request, so admin UIs converge without a scry
      $:  %access-state
          from=ship
          name=@t
          join=(unit (set @t))
          speak=(unit (set @t))
          muted=(set ship)
      ==
      ::  live occupancy of a line we asked about (wire 6)
      [%present from=ship name=@t n=@ud]
  ==
--
