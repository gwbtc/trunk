::  trunk-json: json <-> trunk types, shared by the eyre-facing marks.
::  This file is the wire's source of truth — the Kotlin client's
::  TrunkWire.kt mirrors it exactly.
::
::    action  {"send":{"ship":"~zod","sig":{...}}}
::            {"set-ice":{"servers":[{"url":u,"user":s,"cred":c}]}}
::            {"set-sfu":{"base":b,"group":g,"key":k}}
::            {"open-room":{"name":n,"title":t,"members":["~zod"],
::                           "admins":["~zod"]}}
::            {"set-room-listen":{"name":n,"listen":true}}
::            {"share-room":{"host":"~zod","name":n,"ttl":600}}
::            {"configure-room":{"host":"~zod","name":n,"open":true,
::                               "listen":false,"keep-sfu":true,
::                               "sfu":null|{"base":b,"group":g,"key":k}}}
::            {"close-room":{"name":n}}
::            {"join-room":{"host":"~zod","name":n}}
::            {"peek-room":{"host":"~zod","name":n}}
::            {"set-room-access":{"host":"~zod","name":n,
::                                "join":null|["r"],"speak":null|["r"]}}
::            {"moderate-member":{"host":"~zod","name":n,
::                                "who":"~bus","mute":true}}
::            {"get-room-access":{"host":"~zod","name":n}}
::            {"set-call-mode":"open"} | {"allow":"~zod"}
::            {"unallow":"~zod"} | {"block":"~zod"} | {"unblock":"~zod"}
::            {"push-register":{"id":d,"platform":"unifiedpush",
::                              "endpoint":u,"caps":["read"]}}
::            {"push-register":{"id":d,"platform":"ios-gateway",
::                              "gateway":u,"handle":h,"secret":s,
::                              "caps":[]}}
::            {"push-unregister":d} | {"push-test":{"id":d,"nonce":n}}
::            {"push-kinds":{"dm":true,"club":true,"channel":"all",
::                           "replies":true,"calls":true,"reads":true,
::                           "notices":true}}
::                           (channel: "all" | "mentions" | "none")
::            {"push-notice":{"tag":t,"title":t,"body":b,"open":j|null}}
::            {"push-notice-as":{"app":a,"tag":t,"title":t,"body":b,
::                               "open":j|null}}
::            {"push-app":{"id":i,"allow":true,"cap":30}}  (cap 0: no limit)
::            {"invite-guests":{"name":n,"speak":true,"ttl":86400,
::                              "uses":10}}
::            {"revoke-invite":code}  (an invite's code or a link's name)
::            {"guest-link":{"code":"groundwire-standup","name":n,
::                           "speak":true}}
::            {"app-hosting":{"agent":"mud-world","allow":true}}
::    sig     {"ring":{"id":i}} | {"offer":{"id":i,"sdp":s,"fpr":f}}
::            {"accept":{...}}  | {"reject":{"id":i,"reason":r}}
::            {"hangup":{"id":i}}
::    update  {"recv":{"from":"~zod","sig":{...}}}
::            {"ticket":{"from":"~zod","name":n,"location":l,"token":t}}
::            {"denied":{"from":"~zod","name":n,"why":w}}
::            {"access-state":{"from":"~zod","name":n,"join":null|["r"],
::                             "speak":null|["r"],"muted":["~bus"]}}
::            {"guest-invite":{"code":c,"name":n,"path":p,"speak":true,
::                             "expires":1787000000,"uses":10,"guests":0}}
::            {"guest-link":{"code":c,"name":n,"path":p,"speak":true}}
::    policy  {"mode":"open","allow":["~zod"],"block":["~bus"]}
::    link    {"listen-link":{"name":n,"url":u,"expires":1787000000}}
::
::  Guest seats (wire 16). An invite's path is /apps/trunk/guest/<code>
::  on the ship: trunk does not know its own public URL, so a client
::  puts its own origin in front. An agent's room actions are nouns, not
::  JSON, and their answers on /app/<agent> are %json facts:
::    ticket  {"guest-ticket":{"room":r,"guest":g,"req":q,
::             "username":"guest-3fa9c07b12de","location":l,
::             "endpoint":"wss://...","token":t,"expires":1787000000,
::             "speak":true}}
::    denied  {"guest-denied":{"room":r,"req":q,"why":w}}
::  The guest page's POST answers with the ticket's last six fields
::  and "secret", which the page keeps to rejoin as the same guest.
::  /x/guests is {"invites":[<guest-invite's object>],
::  "links":[<guest-link's object>],
::  "apps":[{"agent":a,"allowed":false,"rooms":[r]}]}.
/-  trunk
/+  trunk-guest
|%
++  ship-from-json  (su:dejs:format ;~(pfix sig fed:ag))
::
++  sig-from-json
  =,  dejs:format
  ^-  $-(json sig:trunk)
  %-  of
  :~  [%ring (ot ~[id+so])]
      [%offer (ot ~[id+so sdp+so fpr+so])]
      [%accept (ot ~[id+so sdp+so fpr+so])]
      [%reject (ot ~[id+so reason+so])]
      [%hangup (ot ~[id+so])]
  ==
::
++  sfu-from-json
  =,  dejs:format
  ^-  $-(json sfu-config:trunk)
  (ot ~[base+so group+so key+so])
::
++  ice-from-json
  =,  dejs:format
  ^-  $-(json ice-server:trunk)
  (ot ~[url+so user+so cred+so])
::
::  +push-register-from-json: the platform names which fields follow.
::  An unknown platform crashes, so the poke nacks.
++  push-register-from-json
  =,  dejs:format
  |=  jon=json
  ^-  [@t push-device:trunk]
  =/  [id=@t platform=@t caps=(set @t)]
    ((ot ~[id+so platform+so caps+(as so)]) jon)
  :+  id
    ?+  platform  !!
      %unifiedpush  [%unifiedpush ((ot ~[endpoint+so]) jon)]
      %ios-gateway  [%ios-gateway ((ot ~[gateway+so handle+so secret+so]) jon)]
    ==
  caps
::
++  action-from-json
  =,  dejs:format
  ^-  $-(json action:trunk)
  %-  of
  :~  [%send (ot ~[ship+ship-from-json sig+sig-from-json])]
      [%set-ice (ot ~[servers+(ar ice-from-json)])]
      [%set-sfu (ot ~[base+so group+so key+so])]
      :-  %open-room
      (ot ~[name+so title+so members+(as ship-from-json) admins+(as ship-from-json)])
      [%set-room-listen (ot ~[name+so listen+bo])]
      [%share-room (ot ~[host+ship-from-json name+so ttl+ni])]
      :-  %configure-room
      %-  ot
      :~  host+ship-from-json  name+so  open+bo  listen+bo
          ::  ~ means "use the host ship's own sidecar"
          sfu+(mu sfu-from-json)  keep-sfu+bo
          ::  only used when the room does not exist yet
          title+so  members+(as ship-from-json)  admins+(as ship-from-json)
      ==
      [%close-room (ot ~[name+so])]
      [%join-room (ot ~[host+ship-from-json name+so])]
      [%peek-room (ot ~[host+ship-from-json name+so])]
      [%enter-room (ot ~[host+ship-from-json name+so])]
      [%leave-room (ot ~[host+ship-from-json name+so])]
      [%occupancy-of (ot ~[host+ship-from-json name+so])]
      [%who-is-on (ot ~[host+ship-from-json name+so])]
      [%start-recording (ot ~[host+ship-from-json name+so])]
      [%stop-recording (ot ~[host+ship-from-json name+so])]
      [%recorders-of (ot ~[host+ship-from-json name+so])]
      ::  null means "everyone on the roster" for either gate
      :-  %set-room-access
      %-  ot
      :~  host+ship-from-json  name+so
          join+(mu (as so))  speak+(mu (as so))
      ==
      :-  %moderate-member
      (ot ~[host+ship-from-json name+so who+ship-from-json mute+bo])
      [%get-room-access (ot ~[host+ship-from-json name+so])]
      :-  %bind-room
      (ot ~[name+so group+(mu (ot ~[ship+ship-from-json name+so]))])
      [%push-register push-register-from-json]
      [%push-unregister so]
      [%push-test (ot ~[id+so nonce+so])]
      :-  %push-kinds
      %-  ot
      :~  dm+bo  club+bo  channel+(su (perk %all %mentions %none ~))
          replies+bo  calls+bo  reads+bo  notices+bo
      ==
      ::  open may be left out, which is null
      :-  %push-notice
      (ou ~[tag+(un so) title+(un so) body+(un so) open+(uf ~ same)])
      :-  %push-notice-as
      %-  ou
      :~  app+(un so)  tag+(un so)  title+(un so)  body+(un so)
          open+(uf ~ same)
      ==
      [%push-app (ot ~[id+so allow+bo cap+ni])]
      [%invite-guests (ot ~[name+so speak+bo ttl+ni uses+ni])]
      [%revoke-invite so]
      [%guest-link (ot ~[code+so name+so speak+bo])]
      [%app-hosting (ot ~[agent+(se %tas) allow+bo])]
      [%set-call-mode (su (perk %open %allow ~))]
      [%allow ship-from-json]
      [%unallow ship-from-json]
      [%block ship-from-json]
      [%unblock ship-from-json]
  ==
::
++  policy-to-json
  ::  no `=, enjs:format` here either; see +lines-to-json.
  |=  pol=policy:trunk
  ^-  json
  =/  ships
    |=  who=(set @p)
    ^-  json
    :-  %a
    %+  turn  ~(tap in who)
    |=(w=@p `json`s+(scot %p w))
  %-  pairs:enjs:format
  :~  [%mode s+`@t`mode.pol]
      [%allow (ships allow.pol)]
      [%block (ships block.pol)]
  ==
::
++  ice-to-json
  |=  servers=(list ice-server:trunk)
  ^-  json
  =,  enjs:format
  :-  %a
  %+  turn  servers
  |=  s=ice-server:trunk
  (pairs ~[url+s+url.s user+s+user.s cred+s+cred.s])
::
++  sig-to-json
  |=  s=sig:trunk
  ^-  json
  =,  enjs:format
  ?-  -.s
    %ring    (frond %ring (pairs ~[id+s+id.s]))
    %offer   (frond %offer (pairs ~[id+s+id.s sdp+s+sdp.s fpr+s+fpr.s]))
    %accept  (frond %accept (pairs ~[id+s+id.s sdp+s+sdp.s fpr+s+fpr.s]))
    %reject  (frond %reject (pairs ~[id+s+id.s reason+s+reason.s]))
    %hangup  (frond %hangup (pairs ~[id+s+id.s]))
  ==
::
::  +roles-to-json: one role gate. null means "everyone on the
::  roster" and is NEVER an empty array — the client keys off the
::  distinction, and an empty array is the opposite gate (admins
::  only).
++  roles-to-json
  |=  r=(unit (set @t))
  ^-  json
  ?~  r  ~
  [%a (turn ~(tap in u.r) |=(t=@t `json`s+t))]
::
++  update-to-json
  |=  u=update:trunk
  ^-  json
  =,  enjs:format
  ?-    -.u
      %recv
    ::  (scot %p) keeps the leading sig; enjs's +ship drops it, which
    ::  broke the client's reply path (it poked back a sig-less ship
    ::  that the action mark's dejs refused).
    %+  frond  %recv
    %-  pairs
    :~  [%from s+(scot %p from.u)]
        [%sig (sig-to-json sig.u)]
    ==
  ::
      %ticket
    %+  frond  %ticket
    %-  pairs
    :~  [%from s+(scot %p from.u)]
        [%name s+name.ticket.u]
        [%location s+location.ticket.u]
        [%token s+token.ticket.u]
    ==
  ::
      %denied
    %+  frond  %denied
    %-  pairs
    :~  [%from s+(scot %p from.u)]
        [%name s+name.u]
        [%why s+why.u]
    ==
  ::
      %open
    %+  frond  %open
    %-  pairs
    :~  [%from s+(scot %p from.u)]
        [%name s+name.u]
        [%title s+title.line.u]
        [%listen b+listen.line.u]
        [%sfu-base s+sfu-base.line.u]
    ==
  ::
      %shut
    %+  frond  %shut
    %-  pairs
    :~  [%from s+(scot %p from.u)]
        [%name s+name.u]
    ==
  ::
      %policy  (frond %policy (policy-to-json policy.u))
  ::
      %listen-link
    %+  frond  %listen-link
    %-  pairs
    :~  [%name s+name.listen-link.u]
        [%url s+url.listen-link.u]
        [%expires (numb expires.listen-link.u)]
    ==
  ::
      %handled  (frond %handled s+id.u)
  ::
      %access-state
    %+  frond  %access-state
    %-  pairs
    :~  [%from s+(scot %p from.u)]
        [%name s+name.u]
        [%join (roles-to-json join.u)]
        [%speak (roles-to-json speak.u)]
        :-  %muted
        [%a (turn ~(tap in muted.u) |=(w=@p `json`s+(scot %p w)))]
    ==
  ::
      %present
    %+  frond  %present
    %-  pairs
    :~  [%from s+(scot %p from.u)]
        [%name s+name.u]
        [%n (numb n.u)]
    ==
  ::
      %on-line
    %+  frond  %on-line
    %-  pairs
    :~  [%from s+(scot %p from.u)]
        [%name s+name.u]
        :-  %who
        [%a (turn ~(tap in who.u) |=(w=@p `json`s+(scot %p w)))]
    ==
  ::
      %recorders
    %+  frond  %recorders
    %-  pairs
    :~  [%from s+(scot %p from.u)]
        [%name s+name.u]
        :-  %who
        [%a (turn ~(tap in who.u) |=(w=@p `json`s+(scot %p w)))]
    ==
  ::
      %guest-invite  (frond %guest-invite (invite-to-json code.u invite.u))
      %guest-link    (frond %guest-link (link-to-json code.u guest-link.u))
  ==
::
++  invite-to-json
  |=  [code=@t inv=invite:trunk]
  ^-  json
  %-  pairs:enjs:format
  %+  weld  (link-pairs code name.inv speak.inv)
  ^-  (list [@t json])
  :~  ['expires' (sect:enjs:format expires.inv)]
      ['uses' (numb:enjs:format uses.inv)]
      ['guests' (numb:enjs:format ~(wyt in guests.inv))]
  ==
::
++  link-to-json
  |=  [code=@t lin=guest-link:trunk]
  ^-  json
  (pairs:enjs:format (link-pairs code name.lin speak.lin))
::
++  link-pairs
  |=  [code=@t name=@t speak=?]
  ^-  (list [@t json])
  :~  ['code' s+code]
      ['name' s+name]
      ['path' s+(cat 3 guest-path:trunk-guest code)]
      ['speak' b+speak]
  ==
::
::  +guests-to-json: /x/guests, for the trunk page and Talon
++  guests-to-json
  |=  $:  invites=(map @t invite:trunk)
          links=(map @t guest-link:trunk)
          apps=(map [agent=@tas room=@t] app-room:trunk)
          hosts=(map @tas ?)
      ==
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  :-  %invites
      a+(turn ~(tap by invites) |=([c=@t i=invite:trunk] (invite-to-json c i)))
      :-  %links
      a+(turn ~(tap by links) |=([c=@t l=guest-link:trunk] (link-to-json c l)))
      :-  %apps
      =/  rooms  ~(tap in ~(key by apps))
      :-  %a
      %+  turn  ~(tap by hosts)
      |=  [agent=@tas allowed=?]
      %-  pairs
      :~  [%agent s+agent]
          [%allowed b+allowed]
          :-  %rooms
          :-  %a
          %+  murn  rooms
          |=  [a=@tas r=@t]
          ?.(=(a agent) ~ `s+r)
      ==
  ==
::
::  +ticket-pairs: what a guest needs to join. `endpoint` is Galène's
::  websocket, since a page on the ship cannot read Galène's .status.
++  ticket-pairs
  |=  [username=@t location=@t endpoint=@t token=@t expires=@ud speak=?]
  ^-  (list [@t json])
  :~  ['username' s+username]
      ['location' s+location]
      ['endpoint' s+endpoint]
      ['token' s+token]
      ['expires' (numb:enjs:format expires)]
      ['speak' b+speak]
  ==
::
++  app-ticket-to-json
  |=  [room=@t guest=@t req=@t ticket=(list [@t json])]
  ^-  json
  %+  frond:enjs:format  'guest-ticket'
  %-  pairs:enjs:format
  [['room' s+room] ['guest' s+guest] ['req' s+req] ticket]
::
::  +room-info-to-json: what the guest page shows before Join
++  room-info-to-json
  |=  [host=@t title=@t speak=?]
  ^-  json
  (pairs:enjs:format ~[['host' s+host] ['title' s+title] ['speak' b+speak]])
::
::  +error-to-json: why the guest route refused
++  error-to-json
  |=  why=@t
  ^-  json
  (frond:enjs:format 'error' s+why)
::
++  denied-to-json
  |=  [room=@t req=@t why=@t]
  ^-  json
  %+  frond:enjs:format  'guest-denied'
  (pairs:enjs:format ~[['room' s+room] ['req' s+req] ['why' s+why]])
::
++  sfu-to-json
  ::  Never the key: a client may see WHICH sidecar its ship uses and
  ::  whether one is set, never the secret that signs its tickets.
  |=  cfg=sfu-config:trunk
  ^-  json
  %-  pairs:enjs:format
  :~  [%base s+base.cfg]
      [%group s+group.cfg]
      [%configured b+!=('' key.cfg)]
  ==
::
++  rooms-to-json
  ::  The SFU secret never leaves the ship: an admin sets it, and can
  ::  see WHICH sidecar is in use, but reading it back is not part of
  ::  the deal.
  |=  rooms=(map @t room:trunk)
  ^-  json
  :-  %a
  %+  turn  ~(tap by rooms)
  |=  [nom=@t =room:trunk]
  ^-  json
  %-  pairs:enjs:format
  :~  [%name s+nom]
      [%title s+title.room]
      [%listen b+listen.room]
      [%sfu-base s+?~(sfu.room '' base.u.sfu.room)]
      [%custom-sfu b+?=(^ sfu.room)]
      :-  %members
      [%a (turn ~(tap in members.room) |=(w=@p `json`s+(scot %p w)))]
      :-  %admins
      [%a (turn ~(tap in admins.room) |=(w=@p `json`s+(scot %p w)))]
      [%join-roles (roles-to-json join-roles.room)]
      [%speak-roles (roles-to-json speak-roles.room)]
      :-  %muted
      [%a (turn ~(tap in muted.room) |=(w=@p `json`s+(scot %p w)))]
      :-  %group
      ?~  group.room  ~
      %-  pairs:enjs:format
      :~  [%ship s+(scot %p ship.u.group.room)]
          [%name s+name.u.group.room]
      ==
  ==
::
++  lines-to-json
  ::  no `=, enjs:format` here: it shadows `ship` with the json encoder
  ::  of that name, so a `who=ship` binding silently becomes a gate.
  |=  known=lines:trunk
  ^-  json
  :-  %a
  %+  turn  ~(tap by known)
  |=  [[who=@p nom=@t] =line:trunk]
  ^-  json
  %-  pairs:enjs:format
  :~  [%host s+(scot %p who)]
      [%name s+nom]
      [%title s+title.line]
      [%listen b+listen.line]
      [%sfu-base s+sfu-base.line]
  ==
::  +roster-from-json: members, admins and per-seat roles out of a
::  Tlon group's JSON.
::
::  This is the entire coupling surface of the group mirror, and it is
::  field names, not types: %trunk never imports a Tlon structure and
::  never casts a Tlon mark. The names carry both schema generations
::  (seats/roles/admins with fleet/sects/bloc fallbacks) — the same
::  pairs Talon's own GroupAdminParser reads in production. A shape
::  this walk does not recognise yields ~, and the caller keeps the
::  roster it already has: version drift degrades to staleness, never
::  to a broken line.
::
::  admin = the group host, or anyone holding the literal 'admin'
::  role, or anyone holding a role the group lists as an admin role.
::
::  seat-roles keeps the RAW role set per seat (seats.*.roles, with
::  the legacy fleet.*.sects fallback — the same two names the admin
::  derivation above already reads): the room's join/speak gates are
::  intersected against it at ticket time, so the role ids here must
::  be the ids an admin picked in the group, untranslated.
++  roster-from-json
  |=  [jon=json host=ship]
  ^-  (unit [members=(set ship) admins=(set ship) seat-roles=(map ship (set @t))])
  ?.  ?=([%o *] jon)  ~
  =/  seats
    =/  x  (~(get by p.jon) 'seats')
    ?^(x x (~(get by p.jon) 'fleet'))
  ?~  seats  ~
  ?.  ?=([%o *] u.seats)  ~
  =/  admin-roles=(set @t)
    =/  a
      =/  x  (~(get by p.jon) 'admins')
      ?^(x x (~(get by p.jon) 'bloc'))
    ?~  a  ~
    ?.  ?=([%a *] u.a)  ~
    %-  silt
    %+  murn  p.u.a
    |=(j=json ?:(?=([%s *] j) `p.j ~))
  =/  entries  ~(tap by p.u.seats)
  =|  members=(set ship)
  =|  admins=(set ship)
  =|  seat-roles=(map ship (set @t))
  |-
  ?~  entries  `[members admins seat-roles]
  =/  who  (slaw %p p.i.entries)
  ?~  who  $(entries t.entries)
  =/  roles=(set @t)
    =/  v  q.i.entries
    ?.  ?=([%o *] v)  ~
    =/  r
      =/  x  (~(get by p.v) 'roles')
      ?^(x x (~(get by p.v) 'sects'))
    ?~  r  ~
    ?.  ?=([%a *] u.r)  ~
    %-  silt
    %+  murn  p.u.r
    |=(j=json ?:(?=([%s *] j) `p.j ~))
  =/  is-admin=?
    ?|  =(u.who host)
        (~(has in roles) 'admin')
        !=(~ (~(int in roles) admin-roles))
    ==
  %=  $
    entries     t.entries
    members     (~(put in members) u.who)
    admins      ?:(is-admin (~(put in admins) u.who) admins)
    seat-roles  (~(put by seat-roles) u.who roles)
  ==

--
