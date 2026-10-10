::  trunk-guest: guest seats (wire 16), with no scries and no cards,
::  so gen/test-guest.hoon can cover it.
::
::  A guest is a person on a call with no ship behind their seat. They
::  come in by an invite the owner made, or through an app on our ship
::  that knows who they are. Either way trunk makes their guest id and
::  mints their Galène token. Neither the guest nor the app names it.
/-  trunk
|%
::  how long a guest's token lasts, in seconds. Galène checks a token
::  only when a connection joins, so this bounds a rejoin, not a call.
::  A guest already on the line stays until they leave or the room
::  moves.
++  guest-ttl  ^~((div ~h1 ~s1))
::  the longest an invite may last, in seconds, and the most guests it
::  may seat. An invite can be revoked, so these only bound the state.
++  invite-ttl-cap  ^~((div ~d30 ~s1))
++  uses-cap  1.000
::  live invites, permanent links, app rooms, and guests in one app room
++  invite-cap  64
++  links-cap  64
++  app-room-cap  64
++  app-guest-cap  256
::  an app room that asks for no ticket for this long closes itself
++  app-idle  ~d1
::  the longest user id or request id an app may give
++  id-max  128
::
::  +guest-id: 'guest-' and 12 hex digits. An @p always starts with ~
::  and this never does, so a client can tell a guest from a ship and
::  no guest can take a ship's name.
::
++  guest-id
  |=  eny=@
  ^-  @t
  (crip (weld "guest-" ((x-co:co 12) (end [2 12] (shas %guest-id eny)))))
::
::  +new-secret: what a guest's page keeps, 128 random bits as 32 hex
::  digits. Their guest id is its hash (+id-of), so only the holder can
::  rejoin as that guest, and a permanent link stores nothing per guest.
::
++  new-secret
  |=  eny=@
  ^-  @t
  (crip ((x-co:co 32) (end [3 16] (shas %guest-secret eny))))
::
::  +id-of: the guest id a secret stands for
::
++  id-of
  |=  secret=@t
  ^-  @t
  (crip (weld "guest-" ((x-co:co 12) (end [2 12] (shax secret)))))
::
::  +valid-secret: 32 hex digits, the shape +new-secret makes
::
++  valid-secret
  |=  s=@t
  ^-  ?
  &(=(32 (met 3 s)) (levy (trip s) is-hex))
::
++  is-hex
  |=  c=@tD
  ^-  ?
  |(&((gte c '0') (lte c '9')) &((gte c 'a') (lte c 'f')))
::
::  +valid-name: a permanent link's name, chosen by the owner. A @tas
::  of 3 to 64 characters that does not look like a random code.
::
++  valid-name
  |=  c=@t
  ^-  ?
  ?&  (gte (met 3 c) 3)
      (lte (met 3 c) 64)
      ((sane %tas) c)
      !&(=(32 (met 3 c)) (levy (trip c) is-hex))
  ==
::
::  +new-code: an invite's code, 128 random bits as 32 hex digits
::
++  new-code
  |=  eny=@
  ^-  @t
  (crip ((x-co:co 32) (end [3 16] (shas %invite eny))))
::
::  +new-epoch: an app room's epoch. Random, so a room closed and
::  opened again does not take back the tokens of its old life.
::
++  new-epoch
  |=  eny=@
  ^-  @t
  (crip ((x-co:co 8) (end [2 8] (shas %epoch eny))))
::
::  +live: the invites worth keeping: unexpired, for a room we host
::
++  live
  |=  [invites=(map @t invite:trunk) now=@da rooms=(set @t)]
  ^-  (map @t invite:trunk)
  %-  ~(gas by *(map @t invite:trunk))
  %+  skim  ~(tap by invites)
  |=  [@t i=invite:trunk]
  &((gth expires.i now) (~(has in rooms) name.i))
::
::  +redeem: seat a guest by invite. `secret` is what the page was given
::  before, if any, and a new one is made otherwise. A guest the invite
::  seated takes no use when they rejoin, so one person stays one guest.
::  Anyone else takes a use. ~ when the invite cannot seat them.
::
++  redeem
  |=  [inv=(unit invite:trunk) secret=(unit @t) now=@da eny=@]
  ^-  (unit [secret=@t id=@t =invite:trunk])
  ?~  inv  ~
  ?.  (gth expires.u.inv now)  ~
  =/  sec  ?^(secret u.secret (new-secret eny))
  =/  id  (id-of sec)
  ?:  (~(has in guests.u.inv) id)  `[sec id u.inv]
  ?:  =(0 uses.u.inv)  ~
  `[sec id u.inv(uses (dec uses.u.inv), guests (~(put in guests.u.inv) id))]
::
::  +link-seat: seat a guest by permanent link, which has no seats to
::  count and keeps no guests: the secret alone keeps their id.
::
++  link-seat
  |=  [secret=(unit @t) eny=@]
  ^-  [secret=@t id=@t]
  =/  sec  ?^(secret u.secret (new-secret eny))
  [sec (id-of sec)]
::
::  +seat: the guest id an app's user has in one of its rooms, and the
::  room with it noted. The same user keeps the same id for the room's
::  life, so asking again makes no duplicate on the line. ~ when the
::  room is full.
::
++  seat
  |=  [r=app-room:trunk guest=@t now=@da eny=@]
  ^-  (unit [id=@t r=app-room:trunk])
  =/  had  (~(get by guests.r) guest)
  ?^  had  `[u.had r(last now)]
  ?:  (gte ~(wyt by guests.r) app-guest-cap)  ~
  =/  id  (guest-id eny)
  `[id r(guests (~(put by guests.r) guest id), last now)]
::
::  +prune-apps: close the app rooms idle past +app-idle
::
++  prune-apps
  |=  [apps=(map [@tas @t] app-room:trunk) now=@da]
  ^-  (map [@tas @t] app-room:trunk)
  %-  ~(gas by *(map [@tas @t] app-room:trunk))
  %+  skim  ~(tap by apps)
  |=  [* r=app-room:trunk]
  (lth (sub now (min now last.r)) app-idle)
::
::  +valid-room: an app's room name is a @tas, one clean URL segment
::
++  valid-room
  |=  room=@t
  ^-  ?
  &(!=('' room) (lte (met 3 room) 64) ((sane %tas) room))
::
::  +app-sub: an app room's Galène subgroup. A party line's is
::  '<ship>-<name>' and an app room's is '<ship>/<agent>/<room>/<epoch>'.
::  The character after the ship differs, so no line a remote admin
::  opens can land on an app's room.
::
++  app-sub
  |=  [our=ship agent=@tas room=@t epoch=@t]
  ^-  @t
  (rap 3 ~[(rsh [3 1] (scot %p our)) '/' agent '/' room '/' epoch])
::
::  +location: a subgroup's URL, which a token's aud must match. The
::  trailing slash is Galène's: it matches the path as /group/<name>/.
::
++  location
  |=  [cfg=sfu-config:trunk sub=@t]
  ^-  @t
  (rap 3 ~[base.cfg '/group/' group.cfg '/' sub '/'])
::
::  +endpoint: Galène's websocket for an SFU base. Galène names it in
::  a group's .status, but sends that with no CORS header, so a page
::  the ship serves cannot read it. This is Galène's own rule.
::
++  endpoint
  |=  base=@t
  ^-  @t
  =/  b=tape  (trip base)
  =/  ws=tape
    ?:  =("https:" (scag 6 b))  (weld "wss:" (slag 6 b))
    ?:  =("http:" (scag 5 b))  (weld "ws:" (slag 5 b))
    b
  (crip (weld ws "/ws"))
--
