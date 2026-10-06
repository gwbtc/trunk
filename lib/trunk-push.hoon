::  trunk-push: what wakes one of our devices, and the bytes that do it.
::
::  A port of Talon's off-ship relay (nisfeb/talon relay/): which
::  %activity events notify (NotifyPolicy.kt, Suppression.kt), the
::  text of an iOS alert (ActivityPreview.kt), which rings get a
::  cancel (RungCalls), and the bodies Push.kt sends. Talon's
::  receivers read these bodies, so they are built by hand in Push.kt's
::  key order with Push.kt's escape, and gen/test-push.hoon pins them
::  byte for byte. en:json would reorder the keys.
::
::  Everything here is pure. The agent does the scries and the cards.
/-  trunk
|%
::  a post older than this never notifies. A backlog (a ship back
::  from a restart, a fresh watch) belongs in the app, not on a lock
::  screen. The relay's freshness filter, same value.
++  fresh-for  ~m5
::  how long after a ring a cancel is still worth sending: just past
::  the client's 45 s ring watchdog. Once one of our devices answered,
::  the call's own hangup must still reach the rest, for up to this.
++  ring-for  ~s60
++  answered-for  ~h4
::  how many devices one ship keeps. Every hint fans out to all of
::  them, so this bounds the work one event can do.
++  device-cap  32
::
::  one hint for our devices
+$  hint
  $%  $:  %message
          whom=@t
          id=@t
          parent=(unit @t)
          author=(unit @t)
          preview=(unit @t)
      ==
      [%read whom=@t]
      [%ring from=@p id=@t]
      [%ring-cancel id=@t reason=@t]
      [%test nonce=@t]
  ==
::  a post %activity says to notify, before Talon's own level
+$  post
  $:  whom=@t
      id=@t
      parent=(unit @t)
      mention=?
      content=(unit json)
  ==
::  rings we pushed, by call id
+$  rung  (map @t [at=@da answered=?])
::
::  +qt: a JSON string, escaped as Push.kt's escape does: only
::  backslash and double quote.
::
++  qt
  |=  v=@t
  ^-  @t
  =/  in=tape
    %-  zing
    %+  turn  (trip v)
    |=  c=@tD
    ^-  tape
    ?:  =(c '\\')  "\\\\"
    ?:  =(c '"')  "\\\""
    [c ~]
  (crip (weld "\"" (weld in "\"")))
::
::  +obj: a JSON object, keys in the order given. Values arrive
::  already encoded, so a string goes through +qt first.
::
++  obj
  |=  kv=(list [k=@t v=@t])
  ^-  @t
  =/  out=tape
    %-  zing
    %+  join  ","
    %+  turn  kv
    |=([k=@t v=@t] `tape`:(weld "\"" (trip k) "\":" (trip v)))
  (crip :(weld "\{" out "}"))
::
::  +body: the UnifiedPush body for a hint, which is also the VoIP
::  payload an iOS ring carries. Push.kt's shapes, plus `parent` on a
::  reply and the whole of %test, which the relay never sent.
::
++  body
  |=  [our=@p =hint]
  ^-  @t
  =/  patp  (qt (scot %p our))
  ?-    -.hint
      %message
    %-  obj
    ;:  weld
      ~[['event' (qt 'new-message')] ['patp' patp]]
      ~[['whom' (qt whom.hint)] ['id' (qt id.hint)]]
      ?~(parent.hint ~ ~[['parent' (qt u.parent.hint)]])
    ==
  ::
      %read
    (obj ~[['event' (qt 'read')] ['patp' patp] ['whom' (qt whom.hint)]])
  ::
      %ring
    %-  obj
    :~  ['event' (qt 'ring')]  ['patp' patp]
        ['from' (qt (scot %p from.hint))]  ['id' (qt id.hint)]
    ==
  ::
      %ring-cancel
    %-  obj
    :~  ['event' (qt 'ring-cancel')]  ['patp' patp]
        ['id' (qt id.hint)]  ['reason' (qt reason.hint)]
    ==
  ::
      %test
    %-  obj
    ~[['event' (qt 'push-test')] ['patp' patp] ['nonce' (qt nonce.hint)]]
  ==
::
::  +urgent: a ring, its cancel and a test are worthless late, so
::  they go out urgent and short-lived. Push.kt's RING_TTL_SECS.
::
++  urgent
  |=  =hint
  ^-  ?
  ?=(?(%ring %ring-cancel %test) -.hint)
::
::  +gateway-body: what the Nisfeb APNs gateway is asked to send. It
::  holds the APNs tokens behind `handle`; iris speaks neither HTTP/2
::  nor ES256, so a ship cannot reach APNs itself.
::
::    alert  {"handle","secret","kind":"alert","patp","whom","postId",
::            "title","body"} plus "parent" on a reply, "nonce" on a
::            test
::    voip   {"handle","secret","kind":"voip","payload":<+body>}
::
::  ~ when an iPhone takes no push for the hint: a read stays put
::  until the app can be woken to clear it (Push.kt sendRead).
::
++  gateway-body
  |=  [our=@p handle=@t secret=@t =hint]
  ^-  (unit @t)
  =/  who=(list [@t @t])
    ~[['handle' (qt handle)] ['secret' (qt secret)]]
  =/  patp  (qt (scot %p our))
  ?-    -.hint
      %read  ~
      ?(%ring %ring-cancel)
    :-  ~
    %-  obj
    (weld who ~[['kind' (qt 'voip')] ['payload' (body our hint)]])
  ::
      %message
    :-  ~
    %-  obj
    ;:  weld
      who
      ~[['kind' (qt 'alert')] ['patp' patp] ['whom' (qt whom.hint)]]
      ~[['postId' (qt id.hint)]]
      ~[['title' (qt (fall author.hint (scot %p our)))]]
      ~[['body' (qt (fall preview.hint 'New message'))]]
      ?~(parent.hint ~ ~[['parent' (qt u.parent.hint)]])
    ==
  ::
      %test
    :-  ~
    %-  obj
    ;:  weld
      who
      ~[['kind' (qt 'alert')] ['patp' patp] ['whom' (qt '')]]
      ~[['postId' (qt '')] ['title' (qt 'Talon')]]
      ~[['body' (qt 'Notifications from your ship are working')]]
      ~[['nonce' (qt nonce.hint)]]
    ==
  ==
::
::  +request: the HTTP request that carries `hint` to `dev`, or ~ when
::  that device takes no push for it.
::
++  request
  |=  [our=@p dev=push-device:trunk =hint]
  ^-  (unit request:http)
  =/  json-type  ['content-type' 'application/json']
  ?-    -.target.dev
      %unifiedpush
    ::  only an app that said it understands a read gets one: an
    ::  older app shows any push it does not know as a new message.
    ?:  &(?=(%read -.hint) !(~(has in caps.dev) 'read'))  ~
    =/  hot  (urgent hint)
    :-  ~
    :^  %'POST'  endpoint.target.dev
      :~  json-type
          ['ttl' ?:(hot '60' '86400')]
          ['urgency' ?:(hot 'high' 'normal')]
      ==
    `(as-octs:mimes:html (body our hint))
  ::
      %ios-gateway
    =/  out
      (gateway-body our handle.target.dev secret.target.dev hint)
    ?~  out  ~
    :-  ~
    :^  %'POST'  (gateway-url gateway.target.dev)
      ~[json-type]
    `(as-octs:mimes:html u.out)
  ==
::
::  +gateway-url: the push route under a gateway's base url, whether
::  or not the base ends in a slash
::
++  gateway-url
  |=  base=@t
  ^-  @t
  =/  b=tape  (trip base)
  =/  slash=?  ?~(b %.n =('/' (rear b)))
  =?  b  slash  (snip b)
  (crip (weld b "/gateway/push"))
::
::  +dead: does this answer mean the device is gone for good? 404 and
::  410 are UnifiedPush's (and the gateway's) "re-register"; a gateway
::  also refuses a wrong secret with 401, which no retry will fix.
::
++  dead
  |=  [=push-target:trunk code=@ud]
  ^-  ?
  ?|  =(404 code)
      =(410 code)
      &(?=(%ios-gateway -.push-target) =(401 code))
  ==
::
::  +valid-device: refuse at the door what iris could never send to
::
++  valid-device
  |=  dev=push-device:trunk
  ^-  ?
  ?-  -.target.dev
    %unifiedpush  ?=(^ (de-purl:html endpoint.target.dev))
  ::
      %ios-gateway
    ?&  ?=(^ (de-purl:html gateway.target.dev))
        !=('' handle.target.dev)
        !=('' secret.target.dev)
    ==
  ==
::
::  JSON lookups. Each answers ~ rather than crashing on a shape it
::  does not expect: these read Tlon's JSON, which trunk does not own.
::
++  at
  |=  [jon=json pax=(list @t)]
  ^-  (unit json)
  ?~  pax  `jon
  ?.  ?=([%o *] jon)  ~
  =/  nex  (~(get by p.jon) i.pax)
  ?~  nex  ~
  $(jon u.nex, pax t.pax)
::
++  cord-at
  |=  [jon=json pax=(list @t)]
  ^-  (unit @t)
  =/  j  (at jon pax)
  ?.  ?=([~ %s *] j)  ~
  `p.u.j
::
::  +whom-of: the chat an %activity source names, as Talon keys it:
::  ~ship for a DM, 0v... for a club, the nest for a channel. A
::  thread counts as its chat only when `threads` is set.
::
++  whom-of
  |=  [src=json threads=?]
  ^-  (unit @t)
  =/  ways=(list (list @t))
    %+  weld
      ^-  (list (list @t))
      ~[~['dm' 'ship'] ~['dm' 'club'] ~['channel' 'nest']]
    ^-  (list (list @t))
    ?.  threads  ~
    :~  ~['thread' 'channel']
        ~['dm-thread' 'whom' 'ship']
        ~['dm-thread' 'whom' 'club']
    ==
  |-
  ?~  ways  ~
  =/  got  (cord-at src i.ways)
  ?^  got  got
  $(ways t.ways)
::
::  +add-post: the post an %activity /v4 fact adds, if %activity
::  marked it notified. Only posts and replies notify, as on the
::  relay; invites, group asks, flags and reacts do not.
::
::    {"add":{"source":{...},"event":{"notified":true,
::            "post"|"reply"|"dm-post"|"dm-reply":{"key":{"id":i},
::            "parent":{"id":p},"content":[...],"mention":false}}}}
::
++  add-post
  |=  jon=json
  ^-  (unit post)
  =/  add  (at jon ~['add'])
  ?~  add  ~
  =/  ev  (at u.add ~['event'])
  ?~  ev  ~
  ?.  =(`[%b %.y] (at u.ev ~['notified']))  ~
  =/  src  (at u.add ~['source'])
  ?~  src  ~
  =/  whom  (whom-of u.src %.y)
  ?~  whom  ~
  =/  tags=(list @t)  ~['post' 'reply' 'dm-post' 'dm-reply']
  |-
  ?~  tags  ~
  =/  e  (at u.ev ~[i.tags])
  ?~  e  $(tags t.tags)
  =/  id  (cord-at u.e ~['key' 'id'])
  ?~  id  ~
  :-  ~
  :*  u.whom
      u.id
      (cord-at u.e ~['parent' 'id'])
      =(`[%b %.y] (at u.e ~['mention']))
      (at u.e ~['content'])
  ==
::
::  +read-whom: the chat an %activity /v4 read says is read to the
::  end: both counts zero, and not a thread, whose chat may still be
::  unread.
::
::    {"read":{"source":{...},"activity":{"count":0,"notify-count":0}}}
::
++  read-whom
  |=  jon=json
  ^-  (unit @t)
  =/  read  (at jon ~['read'])
  ?~  read  ~
  =/  zero  `[%n '0']
  ?.  =(zero (at u.read ~['activity' 'count']))  ~
  ?.  =(zero (at u.read ~['activity' 'notify-count']))  ~
  =/  src  (at u.read ~['source'])
  ?~  src  ~
  (whom-of u.src %.n)
::
::  +author: who wrote a post, from its id `~author/<da>`
::
++  author
  |=  id=@t
  ^-  (unit @t)
  =/  t  (trip id)
  ?.  =("~" (scag 1 t))  ~
  =/  i  (find "/" t)
  `(crip ?~(i t (scag u.i t)))
::
::  +post-time: when a post was made, from its id. The @da after the
::  last slash, with or without its dots.
::
++  post-time
  |=  id=@t
  ^-  (unit @da)
  =/  rev  (flop (trip id))
  =/  i  (find "/" rev)
  =/  da=tape  (flop ?~(i rev (scag u.i rev)))
  =/  digits  (skip da |=(c=@tD =(c '.')))
  ?~  digits  ~
  (bind (rush (crip digits) dem) |=(a=@ `@da`a))
::
::  +fresh: may a post made at `id`'s time still notify at `now`?
::  An id with no readable time defers to the rest of the checks.
::
++  fresh
  |=  [id=@t now=@da]
  ^-  ?
  =/  t  (post-time id)
  ?~  t  %.y
  ?:  (gth u.t now)  %.y
  (lte (sub now u.t) fresh-for)
::
::  +prune-seen: forget posts older than the freshness window. Those
::  can never notify again, so the seen set stays small with no timer.
::
++  prune-seen
  |=  [seen=(map @t @da) now=@da]
  ^-  (map @t @da)
  %-  ~(gas by *(map @t @da))
  %+  skim  ~(tap by seen)
  |=([@t t=@da] |((gth t now) (lte (sub now t) fresh-for)))
::
::  +allows: Talon's per-chat level on top of %activity's own flag.
::  `level` is ~ when the user never set one, and then the ship
::  alone decides. A DM or club is addressed to you, so "mentions"
::  there means "not every group post", not silence.
::
++  allows
  |=  [whom=@t level=(unit @t) mention=?]
  ^-  ?
  ?~  level  %.y
  ?:  =('none' u.level)  %.n
  ?.  =('mentions' u.level)  %.y
  ?|  mention
      ?&  !=("chat/" (scag 5 (trip whom)))
          ?=(~ (find "/" (trip whom)))
      ==
  ==
::
::  +level-of: a chat's level from %settings' JSON for desk %talon,
::  bucket notify-prefs. %settings holds no objects, so Talon stores
::  each entry as a string of JSON:
::    {"desk":{"notify-prefs":{"<whom>":"{\"level\":\"mentions\"}"}}}
::  An object in its place is read the same way.
::
++  level-of
  |=  [jon=json whom=@t]
  ^-  (unit @t)
  =/  v  (at jon ~['desk' 'notify-prefs' whom])
  =/  w  ?^(v v (at jon ~['notify-prefs' whom]))
  ?~  w  ~
  =/  entry=(unit json)
    ?.  ?=([%s *] u.w)  w
    (de:json:html p.u.w)
  ?~  entry  ~
  (cord-at u.entry ~['level'])
::
::  +preview: a one-line text preview of a post's content for an iOS
::  alert: the words and the ship names, at most 140 characters.
::
++  preview-max  140
++  preview
  |=  content=json
  ^-  (unit @t)
  =/  raw=tape  (walk content ~)
  =/  words=tape  (squeeze raw)
  ?~  words  ~
  =/  cs  (tuba words)
  ?:  (lte (lent cs) preview-max)  `(crip words)
  =/  cut  (flop (tuba (squeeze (tufa (scag (dec preview-max) cs)))))
  `(crip (tufa (flop [`@c`0x2026 cut])))
::
::  +walk: the text in a story, appended to `out`. Stops once there is
::  more than twice the preview's worth, as ActivityPreview does.
::
++  walk
  |=  [jon=json out=tape]
  ^-  tape
  ?:  (gth (lent out) (mul 2 preview-max))  out
  ?+  jon  out
    [%s *]  (weld out (trip p.jon))
  ::
      [%a *]
    |-
    ?~  p.jon  out
    $(p.jon t.p.jon, out ^$(jon i.p.jon))
  ::
      [%o *]
    =/  kv  ~(tap by p.jon)
    |-
    ?~  kv  out
    =/  k=@t  p.i.kv
    =/  v=json  q.i.kv
    =/  add=tape
      ?+  k  ~
        %ship   ?:(?=([%s *] v) (trip p.v) ~)
        %break  " "
        %image  "[image] "
        %cite   "[quote] "
        %code   (trip (fall (cord-at v ~['code']) ''))
      ::
          %link
        %-  trip
        (fall (cord-at v ~['content']) (fall (cord-at v ~['href']) ''))
      ::
          %sect
        (weld "@" ?:(?=([%s *] v) (trip p.v) "all"))
      ==
    =/  known  ?=(?(%ship %break %image %cite %code %link %sect) k)
    $(kv t.kv, out ?:(known (weld out add) ^$(jon v)))
  ==
::
::  +squeeze: every run of whitespace becomes one space, and none at
::  either end
::
++  squeeze
  |=  t=tape
  ^-  tape
  =/  white  |=(c=@tD ?=(?(%' ' %'\09' %'\0a' %'\0b' %'\0c' %'\0d') c))
  =|  out=tape
  =|  gap=?
  |-
  ?~  t  (flop out)
  ?:  (white i.t)  $(t t.t, gap %.y)
  =?  out  &(gap ?=(^ out))  [' ' out]
  $(t t.t, out [i.t out], gap %.n)
::
::  +rang: we pushed a ring for `id`. Prunes on write: the map only
::  holds the last minute's rings and the calls still up.
::
++  rang
  |=  [r=rung id=@t now=@da]
  ^-  rung
  (~(put by (prune-rung r now)) id [now %.n])
::
++  live-rung
  |=  [[at=@da answered=?] now=@da]
  ^-  ?
  ?:  (gth at now)  %.y
  (lte (sub now at) ?:(answered answered-for ring-for))
::
++  prune-rung
  |=  [r=rung now=@da]
  ^-  rung
  %-  ~(gas by *rung)
  %+  skim  ~(tap by r)
  |=([@t r=[at=@da answered=?]] (live-rung r now))
::
::  +settle: a ring's undoing, a hangup or one of our devices taking
::  the call. Answers whether to push a cancel: only for a ring we
::  pushed, and only while a device could still be ringing. An answer
::  keeps the entry, marked, so the call's eventual hangup still finds
::  it; a hangup removes it.
::
++  settle
  |=  [r=rung id=@t answered=? now=@da]
  ^-  [? rung]
  =/  got  (~(get by r) id)
  ?~  got  [%.n r]
  :-  (live-rung u.got now)
  ?:  answered  (~(put by r) id [now %.y])
  (~(del by r) id)
--
