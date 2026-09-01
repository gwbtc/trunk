::  %trunk: call signaling router, ICE advertisement, party-line rooms.
::
::  1:1 (v1): local client pokes [%send ship sig]; we relay to the
::  peer's %trunk as a %trunk-signal poke. Inbound signals become
::  [%recv from sig] facts on /calls. Call state lives in the clients.
::
::  Party lines (v2): the host's ship owns the room. A member's client
::  pokes [%join-room host name]; that relays to the host's %trunk as
::  %trunk-room [%ask name]; the host checks membership and mints a
::  short-lived, room-scoped Galène ticket, which comes back as
::  [%grant ticket] and surfaces to the member's client on /calls.
::
::  The agent never sees media and never parses SDP. Its whole job is
::  the trust boundary: local-only actions, and a signal's `from` is
::  the cryptographic ames src, never a claim in the payload.
/-  trunk
/+  default-agent, dbug, trunk-jwt, trunk-json
|%
::  Rooms as they were before state-6. Old state versions must pin the
::  shape they were actually saved with — referencing the evolving
::  +$ room:trunk alias silently rewrites history, and every migration
::  then reads the new shape out of an old noun.
+$  old-room  [title=@t members=(set ship)]
::  Lines before %7 were just [host name] -> title.
+$  old-lines  (map [=ship name=@t] @t)
::  ...and as they were in %6, before the per-room SFU.
+$  old-room-6
  [title=@t members=(set ship) admins=(set ship) listen=?]
::  ...and as saved by %7, before the group binding.
+$  old-room-7
  $:  title=@t
      members=(set ship)
      admins=(set ship)
      listen=?
      sfu=(unit sfu-config:trunk)
  ==
::  ...and as saved by %8, before the role gates.
+$  old-room-8
  $:  title=@t
      members=(set ship)
      admins=(set ship)
      listen=?
      sfu=(unit sfu-config:trunk)
      group=(unit group-source:trunk)
  ==
+$  versioned-state
  $%  state-0
      state-1
      state-2
      state-3
      state-4
      state-5
      state-6
      state-7
      state-8
      state-9
  ==
+$  state-0  [%0 ~]
+$  state-1  [%1 ice=(list ice-server:trunk)]
::  %2 predates room announcements
+$  state-2
  $:  %2
      ice=(list ice-server:trunk)
      sfu=sfu-config:trunk
      hosted=(map @t old-room)
  ==
::  %3 accepted a %grant from any ship — see +on-poke
+$  state-3
  $:  %3
      ice=(list ice-server:trunk)
      sfu=sfu-config:trunk
      hosted=(map @t old-room)
      known=old-lines
  ==
+$  state-4
  $:  %4
      ice=(list ice-server:trunk)
      sfu=sfu-config:trunk
      hosted=(map @t old-room)
      ::  lines other ships have invited us to
      known=old-lines
      ::  rooms we have an outstanding %ask for. A ticket names an SFU
      ::  our client will publish its microphone to, so we only accept
      ::  one that answers a request we actually made.
      asked=(set [=ship name=@t])
  ==
::  %4 rang for any ship that asked — see +may-ring
+$  state-5
  $:  %5
      ice=(list ice-server:trunk)
      sfu=sfu-config:trunk
      hosted=(map @t old-room)
      known=old-lines
      asked=(set [=ship name=@t])
      ::  who may ring us. Enforced here rather than in the client:
      ::  a client-side filter still lets the poke land, still rings
      ::  a ship's other clients, and stops nothing for an app that
      ::  shares this agent.
      pol=policy:trunk
  ==
::  %5 rooms had no admins and no listen flag
+$  state-6
  $:  %6
      ice=(list ice-server:trunk)
      sfu=sfu-config:trunk
      hosted=(map @t old-room-6)
      known=old-lines
      asked=(set [=ship name=@t])
      pol=policy:trunk
  ==
::  %6 rooms had no per-room SFU; lines carried only a title
+$  state-7
  $:  %7
      ice=(list ice-server:trunk)
      sfu=sfu-config:trunk
      hosted=(map @t old-room-7)
      known=lines:trunk
      asked=(set [=ship name=@t])
      pol=policy:trunk
  ==
::  %8 rooms carry an optional group binding.
+$  state-8
  $:  %8
      ice=(list ice-server:trunk)
      sfu=sfu-config:trunk
      hosted=(map @t old-room-8)
      known=lines:trunk
      asked=(set [=ship name=@t])
      pol=policy:trunk
  ==
::  %9 rooms carry role gates, a moderation mute set, and the
::  mirrored per-seat roles that feed both.
+$  state-9
  $:  %9
      ice=(list ice-server:trunk)
      sfu=sfu-config:trunk
      hosted=(map @t room:trunk)
      known=lines:trunk
      asked=(set [=ship name=@t])
      pol=policy:trunk
  ==
+$  card  card:agent:gall
::  how long a minted ticket stays valid. Long enough for a call that
::  outlasts a conversation, short enough that a removed member loses
::  access without a key rotation.
++  ticket-ttl  ^~((div ~h6 ~s1))
::  how many party-line invitations we will remember from the network.
::  The wire this desk speaks.
::
::  BUMP THIS on any change to the JSON shapes in lib/trunk-json.hoon.
::  A client mirrors those by hand — there is no generator between them
::  — and every drift so far has surfaced as a silent no-op rather than
::  an error: a poke gall could not cast, a switch that did nothing.
::  With a version the client can say "your ship's Trunk is too old"
::  instead of appearing broken.
++  wire-version  5
++  invite-cap  256
::  how many lines one ship will host. A remote admin can open one, so
::  this is the brake on that.
++  room-cap  64
::  the longest a listen link may live. Galène's tokens are stateless,
::  so nothing can revoke one early — a short cap is the only brake.
++  listen-ttl-cap  ^~((div ~h1 ~s1))
::  +upgrade-rooms: rooms before state-6 had only [title members].
::  Pure, so it lives out here rather than in the agent core — that
::  core admits exactly its ten arms.
++  upgrade-rooms
  |=  old=(map @t old-room)
  ^-  (map @t room:trunk)
  %-  ~(run by old)
  |=  r=old-room
  ^-  room:trunk
  [title.r members.r ~ %.n ~ ~ ~ ~ ~ ~]
::
::  +upgrade-rooms-6: %6 rooms gain the per-room SFU, unset — every
::  existing room keeps running on its host ship's own sidecar.
++  upgrade-rooms-6
  |=  old=(map @t old-room-6)
  ^-  (map @t room:trunk)
  %-  ~(run by old)
  |=  r=old-room-6
  ^-  room:trunk
  [title.r members.r admins.r listen.r ~ ~ ~ ~ ~ ~]
::
::  +upgrade-rooms-7: %7 rooms gain the group binding, unset — an
::  existing roster stays manual until someone binds it on purpose.
++  upgrade-rooms-7
  |=  old=(map @t old-room-7)
  ^-  (map @t room:trunk)
  %-  ~(run by old)
  |=  r=old-room-7
  ^-  room:trunk
  [title.r members.r admins.r listen.r sfu.r ~ ~ ~ ~ ~]
::
::  +upgrade-rooms-8: %8 rooms gain the role gates and mute set, all
::  unset — an existing line keeps admitting and voicing its whole
::  roster, because gating is something an admin turns on, never
::  something an upgrade turns on.
++  upgrade-rooms-8
  |=  old=(map @t old-room-8)
  ^-  (map @t room:trunk)
  %-  ~(run by old)
  |=  r=old-room-8
  ^-  room:trunk
  [title.r members.r admins.r listen.r sfu.r group.r ~ ~ ~ ~]
::
::  +upgrade-lines: a remembered invitation used to be just a title.
::  Nothing is known about its settings until the host announces
::  again, so assume the conservative values.
++  upgrade-lines
  |=  old=old-lines
  ^-  lines:trunk
  %-  ~(run by old)
  |=  t=@t
  ^-  line:trunk
  [t %.n '']
::
::  The policy a ship starts with: ring for anyone, block nobody.
::  Always assign this explicitly — never lean on the bunt of
::  +$ policy, which forks to %allow and locks the ship down.
++  open-policy  `policy:trunk`[%open ~ ~]
--
%-  agent:dbug
=|  state-9
=*  state  -
^-  agent:gall
=<
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %.n) bowl)
    hc    ~(. +> bowl)
::
::  A fresh install must start OPEN. Not decorative: `on-init` used to
::  be a bare ``this`, which leaves the bunt of the state — and the
::  bunt of ?(%open %allow) is %allow, the last case, not the first.
::  Every newly installed ship therefore came up in allow-mode with an
::  empty allow set and silently refused every caller, while the
::  migration paths below set the policy explicitly and looked fine.
::  Nothing caught it because every test ship was an upgrade.
++  on-init  `this(pol.state open-policy)
++  on-save  !>(state)
++  on-load
  |=  old-vase=vase
  ^-  (quip card _this)
  =/  old  !<(versioned-state old-vase)
  ?-  -.old
    %0  `this(state [%9 ~ ['' '' ''] ~ ~ ~ open-policy])
    %1  `this(state [%9 ice.old ['' '' ''] ~ ~ ~ open-policy])
    %2  `this(state [%9 ice.old sfu.old (upgrade-rooms hosted.old) ~ ~ open-policy])
    %3
  :-  ~
  %=  this
    state
  :*  %9  ice.old  sfu.old  (upgrade-rooms hosted.old)
      (upgrade-lines known.old)  ~  open-policy
  ==  ==
  ::  upgrading must not silently start refusing calls, so an existing
  ::  ship keeps ringing for anyone until its owner says otherwise.
    %4
  :-  ~
  %=  this
    state
  :*  %9  ice.old  sfu.old  (upgrade-rooms hosted.old)
      (upgrade-lines known.old)  asked.old  open-policy
  ==  ==
  ::  existing rooms gain no admins and no anonymous listening: both
  ::  are things you opt into, never things an upgrade turns on.
    %5
  :-  ~
  %=  this
    state
  :*  %9  ice.old  sfu.old  (upgrade-rooms hosted.old)
      (upgrade-lines known.old)  asked.old  pol.old
  ==  ==
  ::  %6 already had admins and the listen flag; it gains only the
  ::  per-room SFU, unset.
    %6
  :-  ~
  %=  this
    state
  :*  %9  ice.old  sfu.old  (upgrade-rooms-6 hosted.old)
      (upgrade-lines known.old)  asked.old  pol.old
  ==  ==
  ::  %7 rooms gain the group binding, unset.
    %7
  :-  ~
  %=  this
    state
  :*  %9  ice.old  sfu.old  (upgrade-rooms-7 hosted.old)
      known.old  asked.old  pol.old
  ==  ==
  ::  %8 rooms gain the role gates and mute set, unset.
    %8
  :-  ~
  %=  this
    state
  :*  %9  ice.old  sfu.old  (upgrade-rooms-8 hosted.old)
      known.old  asked.old  pol.old
  ==  ==
    %9  `this(state old)
  ==

::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+    mark  (on-poke:def mark vase)
  ::
  ::  local client actions
      %trunk-action
    ?>  =(src.bowl our.bowl)
    =/  act  !<(action:trunk vase)
    ?-    -.act
        %set-ice  `this(ice.state servers.act)
        %set-sfu  `this(sfu.state sfu-config.act)
    ::
    ::  policy edits. Each echoes the whole policy back on /calls so a
    ::  ship's other devices converge without re-scrying.
        %set-call-mode
      =/  new  pol.state(mode mode.act)
      :-  ~[(fact:hc [%policy new])]  this(pol.state new)
    ::
        %allow
      =/  new  pol.state(allow (~(put in allow.pol.state) ship.act))
      :-  ~[(fact:hc [%policy new])]  this(pol.state new)
    ::
        %unallow
      =/  new  pol.state(allow (~(del in allow.pol.state) ship.act))
      :-  ~[(fact:hc [%policy new])]  this(pol.state new)
    ::
    ::  blocking also drops any allow entry, so the two lists can never
    ::  disagree about one ship.
        %block
      =/  new
        %=  pol.state
          block  (~(put in block.pol.state) ship.act)
          allow  (~(del in allow.pol.state) ship.act)
        ==
      :-  ~[(fact:hc [%policy new])]  this(pol.state new)
    ::
        %unblock
      =/  new  pol.state(block (~(del in block.pol.state) ship.act))
      :-  ~[(fact:hc [%policy new])]  this(pol.state new)
    ::
        %open-room
      ::  Reopening keeps the room's existing listen setting: an admin
      ::  turning anonymous listening on shouldn't be undone by the
      ::  host's client re-announcing the line.
      =/  had  (~(get by hosted.state) name.act)
      =/  listen  ?~(had %.n listen.u.had)
      =/  room-sfu  ?~(had ~ sfu.u.had)
      ::  the group binding survives a reopen for the same reason
      ::  listen does. The manual roster in this action still lands,
      ::  and the next sync overwrites it if the room is bound.
      =/  had-group  ?~(had ~ group.u.had)
      ::  the role gates, mute set and mirrored seat roles survive a
      ::  reopen too: re-announcing a line must not silently unmute
      ::  anyone or drop the gates an admin set.
      =/  had-join  ?~(had ~ join-roles.u.had)
      =/  had-speak  ?~(had ~ speak-roles.u.had)
      =/  had-muted=(set ship)  ?~(had ~ muted.u.had)
      =/  had-seats=(map ship (set @t))  ?~(had ~ seat-roles.u.had)
      ::  a reopen that shrinks the roster must tell the leavers:
      ::  +announce reaches only the NEW members. Diffed before the
      ::  state write — helper arms see pre-mutation state, so diffs
      ::  are computed here and passed down, never derived inside.
      =/  removed=(set ship)
        ?~  had  ~
        (~(dif in members.u.had) members.act)
      =/  new=room:trunk
        :*  title.act  members.act  admins.act  listen  room-sfu
            had-group  had-join  had-speak  had-muted  had-seats
        ==
      =.  hosted.state  (~(put by hosted.state) name.act new)
      :_  this
      (weld (announce:hc name.act new %.y) (shut-cards:hc name.act removed))
    ::
        %set-room-listen
      =/  got  (~(get by hosted.state) name.act)
      ?~  got  `this
      ::  Announce, like every other room change. Without this the
      ::  flag moved on the ship and nothing was told about it —
      ::  members kept showing the old state, and our own client only
      ::  noticed if some other call happened to re-scry.
      =/  new  u.got(listen listen.act)
      =.  hosted.state  (~(put by hosted.state) name.act new)
      :_  this
      (announce:hc name.act new %.y)
    ::
    ::  A listen link is a bearer token that Galène cannot revoke, so
    ::  the ttl is the whole security model — and it only exists at all
    ::  when the room's admins have asked for it.
        %share-room
      ::  Only the host holds the signing key, so a line hosted
      ::  elsewhere has to be asked. Without this an admin of someone
      ::  else's group clicked the button and nothing happened at all.
      ?.  =(host.act our.bowl)
        :_  this
        :~  :*  %pass  /room/(scot %p host.act)
                %agent  [host.act %trunk]
                %poke  %trunk-room
                !>(`room-sig:trunk`[%share name.act ttl.act])
        ==  ==
      =/  got  (~(get by hosted.state) name.act)
      ?~  got  `this
      ?.  listen.u.got  `this
      ?:  =('' key:(room-sfu:hc name.act))  `this
      =/  now-secs  (unix-secs:trunk-jwt now.bowl)
      =/  ttl  (min ttl.act listen-ttl-cap)
      =/  exp  (add now-secs ttl)
      =/  loc=@t  (room-location:hc name.act)
      =/  tok=@t
        %:  mint-listen:trunk-jwt
          key:(room-sfu:hc name.act)
          'listener'
          loc
          now-secs
          exp
        ==
      :_  this
      ~[(fact:hc [%listen-link [name.act (listen-url:hc name.act tok) exp]])]
    ::
        %close-room
      =/  got  (~(get by hosted.state) name.act)
      :-  ?~(got ~ (announce:hc name.act u.got %.n))
      this(hosted.state (~(del by hosted.state) name.act))
    ::
        %send
      ::  Answering, declining or hanging up settles the call for the
      ::  whole ship, not just the device that did it. Every device saw
      ::  the %ring — that is deliberate — but nothing told the rest it
      ::  had been dealt with, so they rang out their full watchdog
      ::  beside a call already in progress.
      ::  ?- per variant, not ?= against a fork of three. Narrowing to
      ::  a fork leaves the compiler without one face for `id` across
      ::  the branches — that is the find-fork it complains about —
      ::  even though every variant happens to carry one.
      =/  settled=(unit @t)
        ?-  -.sig.act
          %ring    ~
          %offer   ~
          %accept  `id.sig.act
          %reject  `id.sig.act
          %hangup  `id.sig.act
        ==
      =/  extra=(list card)
        ?~  settled  ~
        ~[(fact:hc [%handled u.settled])]
      ::  the wire carries the call id: a nacked relay comes back as a
      ::  %reject on /calls, and the client drops any %reject whose id
      ::  it did not mint — so a made-up id never matched, and the
      ::  caller rang out its whole watchdog against a ship that was
      ::  not there. scot %t, because an id is a client-minted cord
      ::  (uuid), not something already knot-safe.
      =/  call-id=@t
        ?-  -.sig.act
          %ring    id.sig.act
          %offer   id.sig.act
          %accept  id.sig.act
          %reject  id.sig.act
          %hangup  id.sig.act
        ==
      =/  relay=(list card)
        :~  :*  %pass  /relay/(scot %p ship.act)/(scot %t call-id)
                %agent  [ship.act %trunk]
                %poke  %trunk-signal  !>(sig.act)
        ==  ==
      :_(this (weld extra relay))
    ::
        %configure-room
      ::  Hosting it ourselves? Apply directly. Creating is allowed
      ::  here without further checks — this action is local-only, so
      ::  it is already our own ship's owner asking.
      ?:  =(host.act our.bowl)
        =/  got  (~(get by hosted.state) name.act)
        ?.  open.act
          ?~  got  `this
          :-  (announce:hc name.act u.got %.n)
          this(hosted.state (~(del by hosted.state) name.act))
        =/  new=room:trunk
          ?~  got
            ::  a brand-new room starts unbound and ungated; binding
            ::  and gating are separate deliberate acts.
            [title.act members.act admins.act listen.act sfu.act ~ ~ ~ ~ ~]
          =/  new-sfu  ?:(keep-sfu.act sfu.u.got sfu.act)
          =/  new-title  ?:(=('' title.act) title.u.got title.act)
          %=  u.got
            listen   listen.act
            sfu      new-sfu
            title    new-title
            members  ?~(members.act members.u.got members.act)
            admins   ?~(admins.act admins.u.got admins.act)
          ==
        ::  a shrunk roster's leavers get a %shut — +announce reaches
        ::  only the ships that remain. Diffed before the write.
        =/  removed=(set ship)
          ?~  got  ~
          (~(dif in members.u.got) members.new)
        =.  hosted.state  (~(put by hosted.state) name.act new)
        :_  this
        (weld (announce:hc name.act new %.y) (shut-cards:hc name.act removed))
      :_  this
      :~  :*  %pass  /room/(scot %p host.act)
              %agent  [host.act %trunk]
              %poke  %trunk-room
              !>  ^-  room-sig:trunk
              :*  %configure  name.act  open.act  listen.act  sfu.act
                  keep-sfu.act  title.act  members.act  admins.act
              ==
      ==  ==
    ::
        %peek-room
      ::  hosting it ourselves? we already know, answer locally.
      ?:  =(host.act our.bowl)
        :_(this (peek-cards:hc our.bowl name.act))
      ::  Recorded in asked exactly like a %join: a refused peek is
      ::  answered with %deny, and the %deny handler drops anything
      ::  not in asked. Without this entry the host's answer was
      ::  silently eaten and the client re-poked a host that had
      ::  already said no.
      :-  :~  :*  %pass  /room/(scot %p host.act)
                  %agent  [host.act %trunk]
                  %poke  %trunk-room  !>(`room-sig:trunk`[%peek name.act])
          ==  ==
      this(asked.state (~(put in asked.state) [host.act name.act]))
    ::
        %bind-room
      ::  bind (or unbind) a hosted room's roster to a group. The
      ::  binding is host-local: members learn nothing unless a sync
      ::  actually changes the roster, which then announces like any
      ::  other roster change. A fresh binding syncs immediately
      ::  rather than waiting for the group to next change.
      =/  got  (~(get by hosted.state) name.act)
      ?~  got  ~|(no-such-room+name.act !!)
      =/  mirror-live=?
        =/  w  (~(get by wex.bowl) [/groups-mirror our.bowl %groups])
        ?~(w %.n acked.u.w)
      =/  ros=(unit [members=(set ship) admins=(set ship) seat-roles=(map ship (set @t))])
        ?~  group.act  ~
        ::  only sync now if the mirror watch is already live — that
        ::  is the proof %groups exists that mirror-roster requires.
        ::  A first-ever binding syncs on the watch-ack sweep instead,
        ::  moments later: /v1/groups sends no initial fact, so the
        ::  ack itself is the first (and only) proof-of-life signal.
        ?.(mirror-live ~ (mirror-roster:hc u.group.act))
      =/  new=room:trunk
        ?~  ros  u.got(group group.act)
        %=  u.got
          group       group.act
          members     members.u.ros
          admins      admins.u.ros
          seat-roles  seat-roles.u.ros
        ==
      ::  ships the fresh sync drops are told the line is gone —
      ::  +announce reaches only the new roster. Diffed against
      ::  u.got, the pre-write room.
      =/  removed=(set ship)
        ?~  ros  ~
        (~(dif in members.u.got) members.u.ros)
      =.  hosted.state  (~(put by hosted.state) name.act new)
      :_  this
      %+  weld  (mirror-sub-cards:hc hosted.state)
      ?:  =([members admins]:new [members admins]:u.got)  ~
      (weld (announce:hc name.act new %.y) (shut-cards:hc name.act removed))
    ::
        %join-room
      ::  hosting it ourselves? mint straight away, no round trip.
      ?:  =(host.act our.bowl)
        :_  this  (grant-cards:hc our.bowl name.act)
      :-  :~  :*  %pass  /room/(scot %p host.act)
                  %agent  [host.act %trunk]
                  %poke  %trunk-room  !>(`room-sig:trunk`[%ask name.act])
          ==  ==
      this(asked.state (~(put in asked.state) [host.act name.act]))
    ::
    ::  Role gates for a line. Local-only action, so it is already our
    ::  own ship's owner asking: hosting it ourselves we apply
    ::  directly, otherwise we relay and the HOST checks we are on its
    ::  admin list — the same split as %configure-room. Either way the
    ::  answer is one %access-state fact on /calls.
        %set-room-access
      ?:  =(host.act our.bowl)
        =/  got  (~(get by hosted.state) name.act)
        ?~  got  `this
        =/  new  u.got(join-roles join.act, speak-roles speak.act)
        =.  hosted.state  (~(put by hosted.state) name.act new)
        :_  this
        %+  reply:hc  our.bowl
        [%access-state name.act join-roles.new speak-roles.new muted.new]
      :_  this
      :~  :*  %pass  /room/(scot %p host.act)
              %agent  [host.act %trunk]
              %poke  %trunk-room
              !>(`room-sig:trunk`[%access name.act join.act speak.act])
      ==  ==
    ::
    ::  Muting one member for everyone. Same local/relay split; the
    ::  mute lands in the room's muted set and takes effect on the
    ::  next ticket minted — the live socket is the client's job.
        %moderate-member
      ?:  =(host.act our.bowl)
        =/  got  (~(get by hosted.state) name.act)
        ?~  got  `this
        =/  new-muted
          ?:  mute.act  (~(put in muted.u.got) who.act)
          (~(del in muted.u.got) who.act)
        =/  new  u.got(muted new-muted)
        =.  hosted.state  (~(put by hosted.state) name.act new)
        :_  this
        %+  reply:hc  our.bowl
        [%access-state name.act join-roles.new speak-roles.new muted.new]
      :_  this
      :~  :*  %pass  /room/(scot %p host.act)
              %agent  [host.act %trunk]
              %poke  %trunk-room
              !>(`room-sig:trunk`[%moderate name.act who.act mute.act])
      ==  ==
    ::
    ::  Reading the gates back. Hosting it ourselves we answer from
    ::  state; otherwise the host answers with %access-state, and a
    ::  wire-4 host nacks at the mark cast — which the client reads as
    ::  "this host does not speak roles yet".
        %get-room-access
      ?:  =(host.act our.bowl)
        =/  got  (~(get by hosted.state) name.act)
        ?~  got  `this
        :_  this
        %+  reply:hc  our.bowl
        [%access-state name.act join-roles.u.got speak-roles.u.got muted.u.got]
      :_  this
      :~  :*  %pass  /room/(scot %p host.act)
              %agent  [host.act %trunk]
              %poke  %trunk-room
              !>(`room-sig:trunk`[%get-access name.act])
      ==  ==
    ==
  ::
  ::  1:1 signal from a peer ship
      %trunk-signal
    =/  =sig:trunk  !<(sig:trunk vase)
    ::  A block is total: nothing from that ship reaches our clients.
    ?:  (~(has in block.pol.state) src.bowl)
      %-  (slog leaf+"trunk: dropped {<-.sig>} from blocked {<src.bowl>}" ~)
      `this
    ::  The mode gates rings only. The rest of an exchange — offer,
    ::  accept, hangup — has to pass even from a ship the mode would
    ::  refuse, because WE may have called THEM: gating those on the
    ::  allow list would break every outgoing call to someone not
    ::  already on it, by dropping our own callee's answer. Safe
    ::  because a client ignores any signal whose call id it does not
    ::  recognise, so a stranger's stray offer goes nowhere.
    ::
    ::  A refused caller is answered with silence, not a rejection: a
    ::  rejection confirms the ship is live and filtering, and tells a
    ::  blocked caller they were blocked. Their ring watchdog gives up
    ::  on its own, which looks the same as an offline ship.
    ?:  ?&  ?=(%ring -.sig)
            !(may-ring:hc src.bowl)
        ==
      %-  (slog leaf+"trunk: refused ring from {<src.bowl>}" ~)
      `this
    :_  this
    :~  [%give %fact ~[/calls] %trunk-update !>(`update:trunk`[%recv src.bowl sig])]
    ==
  ::
  ::  room negotiation with a peer ship
      %trunk-room
    =/  msg  !<(room-sig:trunk vase)
    ?-    -.msg
        %ask    :_(this (grant-cards:hc src.bowl name.msg))
        %peek   :_(this (peek-cards:hc src.bowl name.msg))
    ::
    ::  A room admin, over ames, turning the line on or off. %trunk
    ::  does not know what a Tlon group is — admins are simply the
    ::  ships the host listed when it opened the room.
    ::  An admin asking us to mint a listen link for a line we host.
        %share
      =/  got  (~(get by hosted.state) name.msg)
      ?~  got  `this
      ?.  (~(has in admins.u.got) src.bowl)  `this
      ?.  listen.u.got  `this
      ::  :hc, not bare. The agent core sits =< over the helper core,
      ::  so these arms resolve without it — but against the helper's
      ::  BUNTED bowl, where our.bowl is ~zod. Every link minted here
      ::  pointed at ~zod's subgroup, which no member is ever in, and
      ::  nothing errored.
      ?:  =('' key:(room-sfu:hc name.msg))  `this
      =/  now-secs  (unix-secs:trunk-jwt now.bowl)
      =/  ttl  (min ttl.msg listen-ttl-cap)
      =/  exp  (add now-secs ttl)
      =/  loc=@t  (room-location:hc name.msg)
      =/  tok=@t
        (mint-listen:trunk-jwt key:(room-sfu:hc name.msg) 'listener' loc now-secs exp)
      :_  this
      (reply:hc src.bowl [%link [name.msg (listen-url:hc name.msg tok) exp]])
    ::
    ::  the host answering our %share.
        %link
      :_  this
      ~[(fact:hc [%listen-link listen-link.msg])]
    ::
        %configure
      =/  got  (~(get by hosted.state) name.msg)
      ::  Creating a line the host has never hosted — a group admin
      ::  turning it on for the first time. There is no admin list to
      ::  check yet, so this reuses the dial that already decides who
      ::  may make this ship do work for them: whoever may ring us.
      ::  Lock your ship down and only those ships can open a line on
      ::  it; leave it open and it is the same exposure as a call.
      ?~  got
        ?.  open.msg  `this
        ?.  (may-ring:hc src.bowl)
          %-  (slog leaf+"trunk: {<src.bowl>} may not open a line here" ~)
          `this
        ?:  (gth ~(wyt by hosted.state) room-cap)
          %-  (slog leaf+"trunk: too many rooms; refusing {<name.msg>}" ~)
          `this
        =/  new=room:trunk
          [title.msg members.msg admins.msg listen.msg sfu.msg ~ ~ ~ ~ ~]
        =.  hosted.state  (~(put by hosted.state) name.msg new)
        :_  this
        (announce:hc name.msg new %.y)
      ?.  (~(has in admins.u.got) src.bowl)
        %-  (slog leaf+"trunk: {<src.bowl>} is not an admin of {<name.msg>}" ~)
        `this
      ?.  open.msg
        =.  hosted.state  (~(del by hosted.state) name.msg)
        :_  this
        (announce:hc name.msg u.got %.n)
      ::  State FIRST, announce second. +announce reads the room back
      ::  out of hosted.state, so announcing before the write told
      ::  everyone the OLD flag — the host changed and no client ever
      ::  heard about it, which is a switch that does nothing.
      =/  new-sfu  ?:(keep-sfu.msg sfu.u.got sfu.msg)
      ::  An empty title means "don't touch the topic" — every other
      ::  change sends none, and without this each listen toggle would
      ::  blank whatever an admin had set. Same trap as keep-sfu.
      =/  new-title  ?:(=('' title.msg) title.u.got title.msg)
      =/  new  u.got(listen listen.msg, sfu new-sfu, title new-title)
      =.  hosted.state  (~(put by hosted.state) name.msg new)
      :_  this
      (announce:hc name.msg new %.y)
    ::
        %announce
      ::  an invitation from anyone is fine (it is just a name), but
      ::  the list is remote-controlled, so it does not grow forever.
      ?:  (~(has in block.pol.state) src.bowl)  `this
      ?:  (gth ~(wyt by known.state) invite-cap)  `this
      =/  =line:trunk  [title.msg listen.msg sfu-base.msg]
      :-  ~[(fact:hc [%open src.bowl name.msg line])]
      ::  deliberately does NOT settle asked.state: joins and peeks
      ::  share that set, and a host's roster-change announce landing
      ::  between our %ask and its %grant would delete the entry the
      ::  %grant handler requires — the grant would be dropped as
      ::  unsolicited and the join would silently die. A peek's entry
      ::  therefore lingers after its announce answer, like an ask to
      ::  a host that never replies; the exposure is one unsolicited
      ::  %ticket fact, which every client device already ignores
      ::  unless it has a matching pending join of its own.
      this(known.state (~(put by known.state) [src.bowl name.msg] line))
    ::
        %shut
      :-  ~[(fact:hc [%shut src.bowl name.msg])]
      this(known.state (~(del by known.state) [src.bowl name.msg]))
    ::
    ::  A ticket names an SFU our client will publish its microphone
    ::  to, so an unsolicited one is a microphone-hijack attempt: only
    ::  accept an answer to a request we actually made.
        %grant
      ?.  (~(has in asked.state) [src.bowl name.ticket.msg])
        %-  (slog leaf+"trunk: unsolicited grant from {<src.bowl>}" ~)
        `this
      :-  ~[(fact:hc [%ticket src.bowl ticket.msg])]
      this(asked.state (~(del in asked.state) [src.bowl name.ticket.msg]))
    ::
        %deny
      ?.  (~(has in asked.state) [src.bowl name.msg])  `this
      :-  ~[(fact:hc [%denied src.bowl name.msg why.msg])]
      this(asked.state (~(del in asked.state) [src.bowl name.msg]))
    ::
    ::  An admin, over ames, setting a line's role gates. The auth
    ::  rule for all three access signals is +configure's: only the
    ::  host itself or a ship on the room's admin list may touch or
    ::  read the gates. Each is answered with %access-state so the
    ::  asking admin's UI converges without a scry it cannot make.
        %access
      ?:  (~(has in block.pol.state) src.bowl)  `this
      =/  got  (~(get by hosted.state) name.msg)
      ?~  got  `this
      ?.  ?|(=(src.bowl our.bowl) (~(has in admins.u.got) src.bowl))
        %-  (slog leaf+"trunk: {<src.bowl>} is not an admin of {<name.msg>}" ~)
        `this
      =/  new  u.got(join-roles join.msg, speak-roles speak.msg)
      =.  hosted.state  (~(put by hosted.state) name.msg new)
      :_  this
      %+  reply:hc  src.bowl
      [%access-state name.msg join-roles.new speak-roles.new muted.new]
    ::
    ::  An admin muting (or unmuting) one member for everyone. The
    ::  mute is a set entry, nothing more: +may-speak is where it
    ::  bites. Muting the host is dropped before it touches state,
    ::  so the muted list never contradicts the host bypass there.
        %moderate
      ?:  (~(has in block.pol.state) src.bowl)  `this
      =/  got  (~(get by hosted.state) name.msg)
      ?~  got  `this
      ?.  ?|(=(src.bowl our.bowl) (~(has in admins.u.got) src.bowl))
        %-  (slog leaf+"trunk: {<src.bowl>} is not an admin of {<name.msg>}" ~)
        `this
      =/  new-muted
        ?:  &(mute.msg =(who.msg our.bowl))  muted.u.got
        ?:  mute.msg  (~(put in muted.u.got) who.msg)
        (~(del in muted.u.got) who.msg)
      =/  new  u.got(muted new-muted)
      =.  hosted.state  (~(put by hosted.state) name.msg new)
      :_  this
      %+  reply:hc  src.bowl
      [%access-state name.msg join-roles.new speak-roles.new muted.new]
    ::
    ::  An admin reading the gates back without changing them. A
    ::  missing room stays silent: a %deny here would be dropped by
    ::  the asker's %deny handler (no asked entry), and minting an
    ::  asked entry for a read would widen the %grant mic-hijack
    ::  guard. The asking UI times out instead.
        %get-access
      ?:  (~(has in block.pol.state) src.bowl)  `this
      =/  got  (~(get by hosted.state) name.msg)
      ?~  got  `this
      ?.  ?|(=(src.bowl our.bowl) (~(has in admins.u.got) src.bowl))
        %-  (slog leaf+"trunk: {<src.bowl>} is not an admin of {<name.msg>}" ~)
        `this
      :_  this
      %+  reply:hc  src.bowl
      [%access-state name.msg join-roles.u.got speak-roles.u.got muted.u.got]
    ::
    ::  The host answering one of the three above: pass it through to
    ::  our client. Inert information, so unlike %grant it needs no
    ::  asked entry — but it must at least be a line we know from
    ::  this ship, or any stranger could spray "muted" lists at us.
        %access-state
      ?:  (~(has in block.pol.state) src.bowl)  `this
      ?.  (~(has by known.state) [src.bowl name.msg])  `this
      :_  this
      ~[(fact:hc [%access-state src.bowl name.msg join.msg speak.msg muted.msg])]
    ==
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?>  =(src.bowl our.bowl)
  ?+  path  (on-watch:def path)
    [%calls ~]  `this
  ==
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  (on-peek:def path)
    [%x %ice ~]    ``trunk-ice+!>(ice.state)
    [%x %rooms ~]   ``trunk-rooms+!>(hosted.state)
    [%x %lines ~]   ``trunk-lines+!>(known.state)
    [%x %policy ~]  ``trunk-policy+!>(pol.state)
    ::  Readable by any client, and the first thing a new one asks.
    [%x %version ~]
  ``json+!>((frond:enjs:format 'wire' (numb:enjs:format wire-version)))
    ::  base + group only. The key is write-only by design.
    [%x %sfu ~]     ``json+!>((sfu-to-json:trunk-json sfu.state))
  ==
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ::  ?- rather than ?+: all four sign types now have cases, and an
  ::  exhaustive ?+ is a mint-vain.
  ?-    -.sign
      %watch-ack
    ?.  ?=([%groups-mirror ~] wire)  (on-agent:def wire sign)
    ?~  p.sign
      ::  the ack IS the proof %groups exists and answered — sync all
      ::  bound rooms right now. The first design deferred a fresh
      ::  bind's sync to the watch's "initial fact", but /v1/groups
      ::  sends none (verified live 2026-09-01: a new subscribe emits
      ::  zero facts until the next group change), so a just-bound
      ::  room sat on its stale roster until an admin happened to bind
      ::  it a second time with the watch already live.
      =^  cards  hosted.state  (mirror-sweep:hc hosted.state)
      [cards this]
    ::  refused (older %groups, permissions...). Not an error state:
    ::  every bound room simply keeps its last known roster.
    %-  (slog leaf+"trunk: groups mirror refused; rosters stay manual" ~)
    `this
  ::
      %kick
    ?.  ?=([%groups-mirror ~] wire)  (on-agent:def wire sign)
    ::  %groups restarted or was upgraded. Re-arm if anything is
    ::  still bound; the helper no-ops otherwise.
    :_(this (mirror-sub-cards:hc hosted.state))
  ::
      %fact
    ?.  ?=([%groups-mirror ~] wire)  (on-agent:def wire sign)
    ::  The cage is deliberately never opened. %trunk cannot cast
    ::  Tlon's versioned marks and does not need to: any fact on this
    ::  wire means "something changed somewhere", and the truth is
    ::  re-read through the stable JSON scry. That is what keeps this
    ::  mirror alive across their group-2/group-3 style bumps.
    =^  cards  hosted.state  (mirror-sweep:hc hosted.state)
    [cards this]
  ::
      %poke-ack
    ?~  p.sign  `this
    ?+    wire  `this
        ::  a nacked relay means the peer has no %trunk (or rejected
        ::  us). surface it so the caller's UI stops ringing. The
        ::  reject carries the call id from the wire's third segment:
        ::  the client filters rejects by the id it minted, so a
        ::  reject without the real id is silently dropped and tells
        ::  the caller nothing.
        [%relay @ @ ~]
      =/  peer  (slav %p i.t.wire)
      =/  id  (slav %t i.t.t.wire)
      :_  this
      ~[(fact:hc [%recv peer [%reject id 'unreachable']])]
    ::
        ::  the id-less wire shape from before the fix above. A poke
        ::  in flight across a desk upgrade still acks against this
        ::  code, so the old shape must keep parsing; nothing better
        ::  than 'unknown' can be said for it.
        [%relay @ ~]
      =/  peer  (slav %p i.t.wire)
      :_  this
      ~[(fact:hc [%recv peer [%reject 'unknown' 'unreachable']])]
    ::
        [%room @ ~]
      =/  peer  (slav %p i.t.wire)
      :_  this
      ~[(fact:hc [%denied peer '' 'host unreachable'])]
    ==
  ==
::
++  on-arvo   on-arvo:def
++  on-leave  |=(path `this)
++  on-fail   on-fail:def
--
::  helper core: cards the agent hands back. Kept out of the agent
::  core because agent:gall admits exactly its ten arms.
::
|_  =bowl:gall
::
::  +fact: one update to our local client.
::
++  fact
  |=  =update:trunk
  ^-  card
  [%give %fact ~[/calls] %trunk-update !>(update)]
::
::  +may-ring: may `who` ring us 1:1? Our own ship always may — that
::  is our other devices, not a stranger.
::
++  may-ring
  |=  who=ship
  ^-  ?
  ?:  =(who our.bowl)  %.y
  ?:  (~(has in block.pol.state) who)  %.n
  ?-  mode.pol.state
    %open   %.y
    %allow  (~(has in allow.pol.state) who)
  ==
::
::  +roles-of: the mirrored group roles `who` holds in this room.
::  Empty for anyone the mirror has never seen — which on an unbound
::  room is everyone, and role gates then admit only admins, the
::  honest reading of "gate by roles nobody has".
::
++  roles-of
  |=  [=room:trunk who=ship]
  ^-  (set @t)
  (fall (~(get by seat-roles.room) who) ~)
::
::  +may-join: may `who` enter this room at all? The rule: the host
::  and its admins always may; an unset join-roles admits the whole
::  roster (the only behavior before wire 5); a set one requires the
::  member to hold at least one of the listed roles. Membership
::  itself is the caller's check — this arm only gates members.
::
++  may-join
  |=  [=room:trunk who=ship]
  ^-  ?
  ?:  =(who our.bowl)  %.y
  ?:  (~(has in admins.room) who)  %.y
  ?~  join-roles.room  %.y
  !=(~ (~(int in (roles-of room who)) u.join-roles.room))
::
::  +may-speak: may `who` publish audio? The rule: a mute beats
::  everything except the host itself — admins included, or an admin
::  could not be moderated at all; past the mute it is +may-join's
::  rule against speak-roles.
::
++  may-speak
  |=  [=room:trunk who=ship]
  ^-  ?
  ?:  =(who our.bowl)  %.y
  ?:  (~(has in muted.room) who)  %.n
  ?:  (~(has in admins.room) who)  %.y
  ?~  speak-roles.room  %.y
  !=(~ (~(int in (roles-of room who)) u.speak-roles.room))
::
::  +grant-cards: authorize (or refuse) `who` for the room `name` we
::  host. Membership plus +may-join is the whole check — a ticket is
::  only ever minted for a ship the host explicitly listed, and only
::  one the join gate admits. What KIND of ticket is +may-speak's
::  call: Galène permissions are claims in the token, so the gate has
::  to be decided here at mint time, not on the socket.
::
++  grant-cards
  |=  [who=ship name=@t]
  ^-  (list card)
  ::  a block outranks membership: being on the list is not a way
  ::  around having been blocked.
  ?:  (~(has in block.pol.state) who)
    (reply who [%deny name 'not a member'])
  =/  got  (~(get by hosted.state) name)
  ?~  got
    (reply who [%deny name 'no such room'])
  ?.  ?|  =(who our.bowl)
          (~(has in members.u.got) who)
      ==
    (reply who [%deny name 'not a member'])
  ?.  (may-join u.got who)
    (reply who [%deny name 'missing join role'])
  ?:  =('' key:(room-sfu name))
    (reply who [%deny name 'no sfu configured'])
  ::  admin → op (moderate over the socket) and, unless muted, a
  ::  voice; speaker → voice; listener → neither. %message stays in
  ::  every tier so the talon-mute gossip usermessages keep flowing —
  ::  it buys no audio and no access to another room.
  =/  is-adm=?  ?|(=(who our.bowl) (~(has in admins.u.got) who))
  =/  can-speak=?  (may-speak u.got who)
  =/  perms=(list json)
    ?:  is-adm
      ?:  can-speak  ~[s+'op' s+'present' s+'message']
      ~[s+'op' s+'message']
    ?:  can-speak  ~[s+'present' s+'message']
    ~[s+'message']
  =/  loc=@t  (room-location name)
  =/  now-secs  (unix-secs:trunk-jwt now.bowl)
  =/  tok=@t
    %:  mint-with:trunk-jwt
      key:(room-sfu name)
      (scot %p who)
      loc
      now-secs
      (add now-secs ticket-ttl)
      perms
    ==
  (reply who [%grant name loc tok])
::
::  +peek-cards: answer "is there a line here?" without joining it.
::
::  The checks are +grant-cards' checks, in the same order and with the
::  same answers, because any divergence is an oracle: a %peek that
::  said 'blocked' where %ask says 'not a member' would turn this into
::  a way to probe whether you have been blocked, which the whole
::  policy design is built to avoid.
::
::  Answers with %announce, so a client that already knows how to be
::  told about a line needs no new handling for being told on request.
++  peek-cards
  |=  [who=ship name=@t]
  ^-  (list card)
  ?:  (~(has in block.pol.state) who)
    (reply who [%deny name 'not a member'])
  =/  got  (~(get by hosted.state) name)
  ?~  got
    (reply who [%deny name 'no such room'])
  ?.  ?|  =(who our.bowl)
          (~(has in members.u.got) who)
      ==
    (reply who [%deny name 'not a member'])
  =/  base=@t  base:(room-sfu name)
  (reply who [%announce name title.u.got listen.u.got base])
::
::  +room-location: the Galène URL for a room we host.
::
::  Every room is a subgroup of the one configured group, so opening a
::  room needs no server-side config. The subgroup name is
::  host-qualified to keep two ships' rooms distinct on a shared SFU.
::  Shared by the member ticket and the anonymous listen link, so the
::  two can never disagree about which room they point at.
::
++  room-sfu
  |=  name=@t
  ^-  sfu-config:trunk
  =/  got  (~(get by hosted.state) name)
  ?~  got  sfu.state
  ?~(sfu.u.got sfu.state u.sfu.u.got)
::
::  +room-subgroup: the Galène group name for a room we host.
++  room-subgroup
  |=  name=@t
  ^-  @t
  =/  cfg  (room-sfu name)
  (rap 3 ~[group.cfg '/' (rsh [3 1] (scot %p our.bowl)) '-' name])
::
::  +listen-url: where a listener points a browser. Not the Galène
::  conference UI — that hides audio-only publishers behind a setting
::  and cannot autoplay in a tab nobody clicked, which made a link
::  useless to anyone who hadn't been told the trick. Trunk serves its
::  own one-button page at /listen.
++  listen-url
  |=  [name=@t tok=@t]
  ^-  @t
  =/  cfg  (room-sfu name)
  =/  got  (~(get by hosted.state) name)
  ::  The topic travels in the link. A listener has no Urbit and no
  ::  way to ask the ship what the line is about, so this is a
  ::  snapshot taken when the link was minted.
  =/  topic  ?~(got '' title.u.got)
  %+  rap  3
  :~  base.cfg  '/listen/?group='  (room-subgroup name)
      '&topic='  (crip (en-urlt:html (trip topic)))
      '&token='  tok
  ==
::
++  room-location
  |=  name=@t
  ^-  @t
  =/  cfg  (room-sfu name)
  =/  sub=@t
    (rap 3 ~[(rsh [3 1] (scot %p our.bowl)) '-' name])
  (rap 3 ~[base.cfg '/group/' group.cfg '/' sub '/'])
::
::  +announce: tell every member a line opened (or closed). The host
::  is always a member of its own line for this purpose; we skip
::  ourselves since our client already knows.
::
::  Takes the room BY VALUE, deliberately. `hc` is ~(. +> bowl), so
::  the helper core closes over the state as it was when the arm was
::  entered — reading hosted.state back in here returned the value
::  from before the caller's own `=.`, and every change announced the
::  flag it had just replaced. That is one bug wearing several hats:
::  a switch that does nothing, a listen link refused after enabling.
++  announce
  |=  [name=@t =room:trunk open=?]
  =/  title  title.room
  =/  members  members.room
  =/  listen  listen.room
  =/  base  base:?~(sfu.room sfu.state u.sfu.room)
  ^-  (list card)
  ::  The host tells itself too. It is excluded from the ames pokes
  ::  below — it is not a peer of its own room — but its client still
  ::  has to see the change, and it has no other way to: without this
  ::  the only path was a re-scry racing the poke, so an admin's first
  ::  click on a switch appeared to do nothing.
  :-  ?:  open
        (fact [%open our.bowl name [title listen base]])
      (fact [%shut our.bowl name])
  %+  turn  ~(tap in (~(del in members) our.bowl))
  |=  who=ship
  ^-  card
  :*  %pass  /room/(scot %p who)
      %agent  [who %trunk]
      %poke  %trunk-room
      !>(`room-sig:trunk`?:(open [%announce name title listen base] [%shut name]))
  ==
::
::  +shut-cards: tell each ship in `whom` the line is gone FOR THEM.
::  Roster shrinks need this: +announce iterates the room's members,
::  and a ship just removed is no longer one, so it never heard —
::  its known list kept the dead line forever, a call button whose
::  every tap round-trips to 'not a member'. Same card as
::  +announce's close path. Takes the removed set by value: callers
::  diff old against new BEFORE mutating state, for the closure
::  reason +announce documents.
::
++  shut-cards
  |=  [name=@t whom=(set ship)]
  ^-  (list card)
  %+  turn  ~(tap in (~(del in whom) our.bowl))
  |=  who=ship
  ^-  card
  :*  %pass  /room/(scot %p who)
      %agent  [who %trunk]
      %poke  %trunk-room
      !>(`room-sig:trunk`[%shut name])
  ==
::
::  +reply: deliver a room-sig to `who` — as a local fact when that's
::  us, over ames otherwise.
::
++  reply
  |=  [who=ship msg=room-sig:trunk]
  ^-  (list card)
  ?:  =(who our.bowl)
    ?-  -.msg
      %grant     ~[(fact [%ticket our.bowl ticket.msg])]
      %deny      ~[(fact [%denied our.bowl name.msg why.msg])]
      %announce
    ~[(fact [%open our.bowl name.msg [title.msg listen.msg sfu-base.msg]])]
      %shut      ~[(fact [%shut our.bowl name.msg])]
      %access-state
    ~[(fact [%access-state our.bowl name.msg join.msg speak.msg muted.msg])]
      ::  none of these is ever addressed to ourselves; the ?- must
      ::  still be total.
      %ask         ~
      %peek        ~
      %configure   ~
      %share       ~
      %access      ~
      %moderate    ~
      %get-access  ~
      %link        ~[(fact [%listen-link listen-link.msg])]
    ==
  :~  :*  %pass  /room/(scot %p who)
          %agent  [who %trunk]
          %poke  %trunk-room  !>(msg)
  ==  ==
::
::  +mirror-roster: one bound room's roster, read back through the
::  stable JSON scry. ~ on any failure, and the caller keeps the
::  roster it has: version drift degrades to staleness, never to a
::  broken line.
::
::  Callers must only invoke this when %groups is known to be alive —
::  a fact just arrived from it, or the mirror watch is acked in
::  wex.bowl. There is no reliable in-agent probe for a missing
::  agent: %gu of one answers nothing and a failed .^ crashes the
::  whole event, straight through mole (verified on-ship — the poke
::  trace names the %gx path). Proof-of-life is the guard, not a
::  scry. The group LIST is read before the single group for the
::  same reason: a bound-but-deleted group would otherwise crash the
::  sync instead of going quietly stale.
++  mirror-roster
  |=  gs=group-source:trunk
  ^-  (unit [members=(set ship) admins=(set ship) seat-roles=(map ship (set @t))])
  =/  base  /(scot %p our.bowl)/groups/(scot %da now.bowl)
  =/  all=json  .^(json %gx (weld base /v2/groups/json))
  ?.  ?=([%o *] all)  ~
  =/  flag  (rap 3 (scot %p ship.gs) '/' name.gs ~)
  ?.  (~(has by p.all) flag)  ~
  =/  jon=json
    .^(json %gx (weld base /v2/groups/(scot %p ship.gs)/[name.gs]/json))
  (roster-from-json:trunk-json jon ship.gs)
::
::  +mirror-sub-cards: keep exactly one local watch on %groups alive
::  while any room is bound, and none when none is. Idempotent — the
::  caller fires it after every binding change without tracking what
::  happened last time. No is-groups-installed probe: watching a
::  missing agent nacks, the nack is logged, and rosters stay manual
::  — which is the correct behaviour and needs no second mechanism.
::  +mirror-sweep: re-read every bound room's roster from %groups and
::  apply what changed. Shared by the mirror's %fact arm and the
::  watch-ack (the first sync a fresh bind gets). Takes and returns the
::  hosted map by value — helper arms close over pre-mutation state, so
::  the caller assigns the result. Announce/shut fire only when the
::  membership actually moved; a seat-roles-only change stays
::  host-local, since an announce carries no role data.
++  mirror-sweep
  |=  hosted=(map @t room:trunk)
  ^-  [(list card) (map @t room:trunk)]
  =/  rooms  ~(tap by hosted)
  =|  cards=(list card)
  |-
  ?~  rooms  [cards hosted]
  =/  nom  p.i.rooms
  =/  rum  q.i.rooms
  ?~  group.rum  $(rooms t.rooms)
  =/  ros  (mirror-roster u.group.rum)
  ?~  ros  $(rooms t.rooms)
  ?:  ?&  =(members.u.ros members.rum)
          =(admins.u.ros admins.rum)
          =(seat-roles.u.ros seat-roles.rum)
      ==
    $(rooms t.rooms)
  =/  new
    %=  rum
      members     members.u.ros
      admins      admins.u.ros
      seat-roles  seat-roles.u.ros
    ==
  =/  removed  (~(dif in members.rum) members.u.ros)
  =/  told
    ?:  =([members admins]:new [members admins]:rum)  ~
    (weld (announce nom new %.y) (shut-cards nom removed))
  =.  hosted  (~(put by hosted) nom new)
  $(rooms t.rooms, cards (weld cards told))
::
++  mirror-sub-cards
  |=  hosted=(map @t room:trunk)
  ^-  (list card)
  =/  want=?
    %+  lien  ~(tap by hosted)
    |=([@t r=room:trunk] ?=(^ group.r))
  =/  has=?
    (~(has by wex.bowl) [/groups-mirror our.bowl %groups])
  ?:  &(want !has)
    [%pass /groups-mirror %agent [our.bowl %groups] %watch /v1/groups]~
  ?:  &(!want has)
    [%pass /groups-mirror %agent [our.bowl %groups] %leave ~]~
  ~
--
