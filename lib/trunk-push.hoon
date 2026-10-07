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
::  the longest call id a ring may carry and still be pushed. A peer
::  picks the id, and it goes into state and onto every device.
++  id-cap  128
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
      ::  an alert from another agent on our ship (wire 12), the name
      ::  of the app it came from and the agent it came through (wire
      ::  14). Both are '' for one queued before wire 14.
      [%notice from=@t via=@t tag=@t title=@t body=@t open=json]
      ::  an iPhone's app-icon count, with nothing shown (wire 12)
      [%badge n=@ud]
  ==
::  a post %activity says to notify, before Talon's own level
+$  post
  $:  whom=@t
      id=@t
      parent=(unit @t)
      mention=?
      content=(unit json)
      group=(unit @t)
  ==
::  rings we pushed, by call id, and the devices each one went to:
::  only those get its cancel
+$  rung  (map @t [at=@da answered=? to=(set @t)])
::  what the debug report says about one device
+$  device-meta
  $:  registered=@da
      sent=(unit [at=@da kind=@tas])
      ::  code 0: no answer at all
      last=(unit [at=@da code=@ud])
  ==
::  a device the ship removed, and why
+$  drop  [at=@da id=@t platform=@tas reason=@t]
++  drop-cap  16
::  the app-icon count. `n` is %activity's base notify-count, ~ until
::  the first fact after a watch starts; `sent` is the last count each
::  device was given; `timer` is set while a badge push is waiting.
+$  badge-state  [n=(unit @ud) sent=(map @t @ud) timer=(unit @da)]
::  how long the count may wait before it goes out on its own
++  badge-wait  ~s30
::  an app that sends notices, as the trunk page shows it
::    name     the name it declared, else the agent it came through
::    agent    that agent (or %eyre, for the owner's web session)
::    allowed  the owner's switch for it; a new app starts allowed
::    last     when it last got a push out
::    hour     pushes in the hour that began at `start`
::    sent     notices delivered, ever; held: notices stopped, ever
::    cap      the most pushes it may have in an hour, 0 for no limit;
::             a new app starts at +default-cap
::    waiting  the first +wait-cap notices that came within +notice-gap
::             of the last push, oldest first; `waited` counts them
::             all, and `timer` is when the wait ends
+$  sender
  $:  name=@t
      agent=@tas
      allowed=?
      first=@da
      last=(unit @da)
      hour=[start=@da n=@ud]
      sent=@ud
      held=@ud
      waiting=(list [tag=@t title=@t body=@t open=json])
      waited=@ud
      timer=(unit @da)
      cap=@ud
  ==
::  rate limits, per app. No more than one push every +notice-gap:
::  what comes sooner waits, and goes as one push when the gap is up.
::  And no more pushes an hour than the app's cap, so a buggy or
::  hostile app on the ship cannot buzz the owner's phones all day. A
::  new app starts at +default-cap; the owner can raise it, lower it,
::  or lift it (0), per app. +max-cap is what the gap allows anyway.
++  notice-gap  ~s5
++  default-cap  30
++  max-cap  720
::  a summary names five notices, so no more than that wait in full
++  wait-cap  5
::  how long a title is in a summary, so five of them stay well under
::  the 4 KiB a push service takes
++  title-max  80
::  an agent may send under this many names (+sender-of), and trunk
::  keeps this many senders, so renaming escapes no limit for long and
::  the list stays small. Neither holds against an agent that forges
::  its origin: gall lets an agent name any origin for its poke.
++  names-cap  16
++  senders-cap  128
::
::  +admit: `senders`, with room made for `id` from `agent` if it is
::  new, or ~ if there is none. An agent past +names-cap gets none.
::  When the list is full, the sender idle longest that the owner never
::  changed and that has nothing waiting is forgotten.
::
++  admit
  |=  [senders=(map @t sender) id=@t agent=@tas]
  ^-  (unit (map @t sender))
  ?:  (~(has by senders) id)  `senders
  =/  all=(list [id=@t x=sender])  ~(tap by senders)
  =/  mine  (skim all |=([@t x=sender] =(agent agent.x)))
  ?.  (lth (lent mine) names-cap)  ~
  ?:  (lth (lent all) senders-cap)  `senders
  =/  idle=(list [id=@t x=sender])
    %+  sort
      %+  skim  all
      |=  [@t x=sender]
      &(allowed.x =(default-cap cap.x) ?=(~ waiting.x) ?=(~ timer.x))
    |=  [a=[@t x=sender] b=[@t x=sender]]
    (lth (fall last.x.a first.x.a) (fall last.x.b first.x.b))
  ?~  idle  ~
  `(~(del by senders) id.i.idle)
::
::  +batch: what one push says for the notices that waited: the notice
::  itself, or "3 alerts from calendar" over their titles, oldest first.
::  Its tag is the sender's id, so two senders with one name never
::  replace each other's summary on the phone.
::
++  batch
  |=  [id=@t name=@t waited=@ud waiting=(list [tag=@t title=@t body=@t open=json])]
  ^-  [tag=@t title=@t body=@t open=json]
  ?:  &(=(1 waited) ?=([* ~] waiting))  i.waiting
  ::  a title that is not UTF-8 is left out rather than lose the push
  =/  shown=(list @t)
    %+  murn  (scag 5 waiting)
    |=  [@t t=@t @t json]
    (mole |.((clip (squeeze (trip t)) title-max)))
  =/  more  (sub waited (min waited (lent shown)))
  :^    (rap 3 ~['batch-' id])
      (crip "{<waited>} alerts from {(trip name)}")
    %-  crip
    %+  weld
      `tape`(zing (join "\0a" (turn shown trip)))
    ?:(=(0 more) "" "\0aand {<more>} more")
  ~
::  a push that may be sent again: to which device, to which target
::  (its +sham), and how many times it was sent again already
+$  flight  [id=@t target=@ =hint tries=@ud]
::
::  +qt: a JSON string. Push.kt escaped only backslash and double
::  quote; control characters are escaped too, since a peer picks a
::  call id. Any string Push.kt ever sent comes out the same.
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
    ?:  =(c '\0a')  "\\n"
    ?:  =(c '\0d')  "\\r"
    ?:  =(c '\09')  "\\t"
    ?:  (lth c 32)  (weld "\\u" ((x-co:co 4) c))
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
  ::
      %notice
    %-  obj
    %+  weld
      ^-  (list [k=@t v=@t])
      :~  ['event' (qt 'notice')]  ['patp' patp]  ['tag' (qt tag.hint)]
          ['title' (qt title.hint)]  ['body' (qt body.hint)]
          ['open' (en:json:html open.hint)]
      ==
    (sent-by from.hint via.hint)
  ::
  ::  no UnifiedPush device takes one; +request never sends it
      %badge
    (obj ~[['event' (qt 'badge')] ['patp' patp] ['badge' (num n.hint)]])
  ==
::
::  +num: a JSON number, in plain digits
::
++  num  |=(n=@ud `@t`(crip ((d-co:co 1) n)))
::
::  +urgent and +ttl: a ring, its cancel and a test are worthless
::  late, so they go out urgent and short-lived (Push.kt's
::  RING_TTL_SECS). A notice is urgent too, and worthless after an
::  hour: a reminder to leave that arrives late helps nobody.
::
++  urgent
  |=  =hint
  ^-  ?
  ?=(?(%ring %ring-cancel %test %notice) -.hint)
::
++  ttl
  |=  =hint
  ^-  @ud
  ?+  -.hint  86.400
    ?(%ring %ring-cancel %test)  60
    %notice                      3.600
  ==
::
::  +sent-by: a notice's app, and the agent it came through when that
::  is not the app itself, which a phone can show beside it. A notice
::  queued before wire 14 names neither.
::
++  sent-by
  |=  [from=@t via=@t]
  ^-  (list [k=@t v=@t])
  ?:  =('' from)  ~
  :-  ['app' (qt from)]
  ?:  |(=('' via) =(via from))  ~
  ~[['via' (qt via)]]
::
::  +gateway-body: what the Nisfeb APNs gateway is asked to send. It
::  holds the APNs tokens behind `handle`; iris speaks neither HTTP/2
::  nor ES256, so a ship cannot reach APNs itself.
::
::    alert  {"handle","secret","kind":"alert","patp","whom","postId",
::            "title","body"} plus "parent" on a reply, "nonce" on a
::            test, "event":"notice" and "open" on a notice, and
::            "badge" for a device whose caps include it
::    voip   {"handle","secret","kind":"voip","payload":<+body>}
::    clear  {"handle","secret","kind":"clear","patp","whom"}, a read,
::            for a device whose caps include "read"
::    badge  {"handle","secret","kind":"badge","badge":n}
::
::  ~ when this iPhone takes no push for the hint.
::
++  gateway-body
  |=  $:  our=@p
          handle=@t
          secret=@t
          caps=(set @t)
          badge=(unit @ud)
          =hint
      ==
  ^-  (unit @t)
  =/  who=(list [@t @t])
    ~[['handle' (qt handle)] ['secret' (qt secret)]]
  =/  patp  (qt (scot %p our))
  =/  count=(list [@t @t])
    ?.  &((~(has in caps) 'badge') ?=(^ badge))  ~
    ~[['badge' (num u.badge)]]
  ?-    -.hint
      %read
    ?.  (~(has in caps) 'read')  ~
    :-  ~
    %-  obj
    (weld who ~[['kind' (qt 'clear')] ['patp' patp] ['whom' (qt whom.hint)]])
  ::
      %badge
    ?.  (~(has in caps) 'badge')  ~
    `(obj (weld who ~[['kind' (qt 'badge')] ['badge' (num n.hint)]]))
  ::
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
      count
    ==
  ::
      %notice
    :-  ~
    %-  obj
    ;:  weld
      who
      ~[['kind' (qt 'alert')] ['patp' patp] ['whom' (qt tag.hint)]]
      ~[['postId' (qt '')] ['title' (qt title.hint)]]
      ~[['body' (qt body.hint)] ['event' (qt 'notice')]]
      ~[['open' (en:json:html open.hint)]]
      (sent-by from.hint via.hint)
      count
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
::  that device takes no push for it. `badge` is the count an iPhone
::  alert carries, if the ship knows it.
::
++  request
  |=  [our=@p dev=push-device:trunk badge=(unit @ud) =hint]
  ^-  (unit request:http)
  =/  json-type  ['content-type' 'application/json']
  ::  an app that never said it understands a notice would show one
  ::  as a new message
  ?:  &(?=(%notice -.hint) !(~(has in caps.dev) 'notice'))  ~
  ?-    -.target.dev
      %unifiedpush
    ?:  ?=(%badge -.hint)  ~
    ::  likewise a read, for an app that never said it takes one
    ?:  &(?=(%read -.hint) !(~(has in caps.dev) 'read'))  ~
    =/  hot  (urgent hint)
    :-  ~
    :^  %'POST'  endpoint.target.dev
      :~  json-type
          ['ttl' (num (ttl hint))]
          ['urgency' ?:(hot 'high' 'normal')]
      ==
    `(as-octs:mimes:html (body our hint))
  ::
      %ios-gateway
    =/  out
      %:  gateway-body
        our  handle.target.dev  secret.target.dev  caps.dev  badge  hint
      ==
    ?~  out  ~
    :-  ~
    :^  %'POST'  (gateway-url gateway.target.dev)
      ~[json-type]
    `(as-octs:mimes:html u.out)
  ==
::
::  +retryable, +retry-code: with no relay left to catch a miss, a
::  message, read, notice or badge that got a 5xx, a 429 or no answer
::  is sent again, after +retry-after. Never a ring or its cancel,
::  stale in seconds, and never a test, which the app is timing.
::
++  retryable  |=(=hint `?`?=(?(%message %read %notice %badge) -.hint))
++  retry-code  |=(code=@ud `?`|(=(0 code) =(429 code) (gte code 500)))
++  max-tries  2
++  retry-after  |=(tries=@ud `@dr`?:(=(0 tries) ~s30 ~m5))
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
::  +gone: does an answer drop this device? Only if it is dead and
::  still the target the push went to (`sent` is that target's
::  +sham), so a device registered again since then keeps its new one.
::
++  gone
  |=  [dev=push-device:trunk sent=@ code=@ud]
  ^-  ?
  &((dead target.dev code) =(sent (sham target.dev)))
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
::            "parent":{"id":p},"content":[...],"mention":false,
::            "group":"~host/name"}}}}
::
::  A DM or club post has no group.
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
      (cord-at u.e ~['group'])
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
::  +allows: Talon's per-chat level on top of %activity's own flag,
::  as Talon applies it on the desktop and on Android. `level` is ~
::  when the user never set one, and Talon shows and treats that as
::  "mentions". A DM or club is addressed to you, so "mentions" there
::  means "not every group post", not silence. And %activity notifies
::  a reply only in a thread we wrote, replied in or were mentioned
::  in, so a notified reply passes "mentions" too.
::
++  allows
  |=  [whom=@t level=(unit @t) mention=? reply=?]
  ^-  ?
  =/  lev=@t  (fall level 'mentions')
  ?:  =('none' lev)  %.n
  ?.  =('mentions' lev)  %.y
  ?|  mention
      reply
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
::  +chat-level: Talon's level for a post's chat, and whether it is
::  the group's. The chat's own entry wins. Else a channel takes its
::  group's, kept under "group/<flag>" (no chat is keyed so). ~ when
::  neither is set, which +allows reads as "mentions".
::
++  chat-level
  |=  [jon=json whom=@t group=(unit @t)]
  ^-  (unit [lev=@t from-group=?])
  =/  own  (level-of jon whom)
  ?^  own  `[u.own %.n]
  ?~  group  ~
  (bind (level-of jon (cat 3 'group/' u.group)) |=(l=@t [l %.y]))
::
::  +preview: a one-line text preview of a post's content for an iOS
::  alert: the words and the ship names, at most 140 characters.
::
++  preview-max  140
::  +tuba crashes on bytes that are not UTF-8, which would cost the
::  push its preview, not the push itself.
++  preview
  |=  content=json
  ^-  (unit @t)
  (fall (mole |.((make-preview content))) ~)
::
++  make-preview
  |=  content=json
  ^-  (unit @t)
  =/  raw=tape  (walk content ~)
  =/  words=tape  (squeeze raw)
  ?~  words  ~
  `(clip words preview-max)
::
::  +clip: `words` cut to `max` characters, the last an ellipsis.
::  +tuba crashes on bytes that are not UTF-8.
::
++  clip
  |=  [words=tape max=@ud]
  ^-  @t
  =/  cs  (tuba words)
  ?:  (lte (lent cs) max)  (crip words)
  =/  cut  (flop (tuba (squeeze (tufa (scag (dec max) cs)))))
  (crip (tufa (flop [`@c`0x2026 cut])))
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
::  either end. Any other control character goes: +tuba refuses them.
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
  ?:  (lth i.t 32)  $(t t.t)
  =?  out  &(gap ?=(^ out))  [' ' out]
  $(t t.t, out [i.t out], gap %.n)
::
::  +rang: we pushed a ring for `id`. Prunes on write: the map only
::  holds the last minute's rings and the calls still up.
::
++  rang
  |=  [r=rung id=@t now=@da to=(set @t)]
  ^-  rung
  (~(put by (prune-rung r now)) id [now %.n to])
::
++  live-rung
  |=  [[at=@da answered=? to=(set @t)] now=@da]
  ^-  ?
  ?:  (gth at now)  %.y
  (lte (sub now at) ?:(answered answered-for ring-for))
::
++  prune-rung
  |=  [r=rung now=@da]
  ^-  rung
  %-  ~(gas by *rung)
  %+  skim  ~(tap by r)
  |=([@t r=[at=@da answered=? to=(set @t)]] (live-rung r now))
::
::  +settle: a ring's undoing, a hangup or one of our devices taking
::  the call. Answers the devices to push a cancel to: the ones the
::  ring went to, and none once no device could still be ringing. An answer
::  keeps the entry, marked, so the call's eventual hangup still finds
::  it; a hangup removes it.
::
++  settle
  |=  [r=rung id=@t answered=? now=@da]
  ^-  [(set @t) rung]
  =/  got  (~(get by r) id)
  ?~  got  [~ r]
  :-  ?.((live-rung u.got now) ~ to.u.got)
  ?:  answered  (~(put by r) id [now %.y to.u.got])
  (~(del by r) id)
::
::  +all-kinds: every kind of push on, the behaviour before wire 12.
::  The bunt of push-kinds has channel %none, so never lean on it.
::
++  all-kinds  `push-kinds:trunk`[%.y %.y %all %.y %.y %.y %.y]
::
::  +chat-of: what kind of chat a post's whom names
::
++  chat-of
  |=  whom=@t
  ^-  ?(%dm %club %channel)
  =/  t  (trip whom)
  ?:  =("~" (scag 1 t))  %dm
  ?:  =("0v" (scag 2 t))  %club
  %channel
::
::  +wants: do the owner's switches let this post through? A reply
::  needs its chat's switch and `replies` both.
::
++  wants
  |=  [k=push-kinds:trunk p=post]
  ^-  ?
  ?.  |(?=(~ parent.p) replies.k)  %.n
  ?-    (chat-of whom.p)
      %dm    dm.k
      %club  club.k
  ::
      %channel
    ?-  channel.k
      %all       %.y
      %mentions  mention.p
      %none      %.n
    ==
  ==
::
::  +chat-word: how the log names a post without naming its chat
::
++  chat-word
  |=  p=post
  ^-  tape
  %+  weld
    ?-  (chat-of whom.p)
      %dm       "DM"
      %club     "group DM"
      %channel  ?~(parent.p "channel post" "channel")
    ==
  ?~(parent.p "" " reply")
::
::  +note: one more line in the log, newest first, keeping the last
::  +log-cap of them
::
++  log-cap  50
++  note
  |=  [log=(list push-note:trunk) at=@da what=tape]
  ^-  (list push-note:trunk)
  (scag log-cap `(list push-note:trunk)`[[at (crip what)] log])
::
::  +host-of: the host of a url and nothing else. The debug report
::  shows where a device's pushes go, never the path, query or user
::  that would let someone else push to it.
::
++  host-of
  |=  url=@t
  ^-  @t
  =/  t=tape  (trip url)
  =/  s  (find "://" t)
  =?  t  ?=(^ s)  (slag (add u.s 3) t)
  =/  e  (find "/" t)
  =/  h=tape  ?~(e t (scag u.e t))
  =/  q  (find "?" h)
  =?  h  ?=(^ q)  (scag u.q h)
  =/  a  (find "@" (flop h))
  (crip ?~(a h (slag (sub (lent h) u.a) h)))
::
::  +sender-of: who sent a notice, from the poke's provenance and the
::  name it declared. Gall gives /gall/<agent> for another agent and
::  /eyre for the owner's web session or Talon. The id is the agent,
::  or "<agent>/<name>" for a name the agent did not have.
::
++  sender-of
  |=  [sap=path declared=(unit @t)]
  ^-  [id=@t name=@t agent=@tas]
  =/  agent=@tas
    ?:  ?=([%gall @ *] sap)  i.t.sap
    ?~(sap %unknown i.sap)
  ?~  declared  [agent agent agent]
  ?:  =(u.declared agent)  [agent agent agent]
  [(rap 3 ~[agent '/' u.declared]) u.declared agent]
::
::  +valid-app: a declared app name a page and a phone can show
::
++  valid-app
  |=  name=@t
  ^-  ?
  ?&  !=('' name)
      (lte (met 3 name) 40)
      (levy (trip name) |=(c=@tD (gte c 32)))
  ==
::
::  +roll-hour: start a new hour for `s` once its current one is over
::
++  roll-hour
  |=  [s=sender now=@da]
  ^-  sender
  ?:  (lth (sub now (min now start.hour.s)) ~h1)  s
  s(hour [now 0])
::
::  +debug-json: what the debug page, Talon and an agent read, at
::  /~/scry/trunk/debug.json. It holds no secret, handle, endpoint
::  path or chat id, so a user can paste it to anyone. Talon reads
::  devices' "sent" and "last" and the "drops", so those names are
::  wire.
::
++  debug-json
  |=  $:  ver=@ud
          hash=@uv
          now=@da
          kinds=push-kinds:trunk
          push=(map @t push-device:trunk)
          meta=(map @t device-meta)
          drops=(list drop)
          badge=(unit @ud)
          senders=(map @t sender)
          watches=(list [@t @t])
          apps=(list [@t ?])
          log=(list push-note:trunk)
      ==
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  wire+(numb ver)
      desk-hash+s+(scot %uv hash)
      now+(time now)
      kinds+(kinds-json kinds)
      badge+?~(badge ~ (numb u.badge))
      :-  %devices
      :-  %a
      %+  turn  ~(tap by push)
      |=  [id=@t dev=push-device:trunk]
      =/  url=@t
        ?-  -.target.dev
          %unifiedpush  endpoint.target.dev
          %ios-gateway  gateway.target.dev
        ==
      =/  m  (~(get by meta) id)
      %-  pairs
      :~  id+s+id
          platform+s+-.target.dev
          host+s+(host-of url)
          caps+a+(turn ~(tap in caps.dev) |=(c=@t s+c))
          registered+?~(m ~ (time registered.u.m))
          :-  %sent
          ?~  m  ~
          ?~  sent.u.m  ~
          (pairs ~[at+(time at.u.sent.u.m) kind+s+kind.u.sent.u.m])
          :-  %last
          ?~  m  ~
          ?~  last.u.m  ~
          (pairs ~[at+(time at.u.last.u.m) code+(numb code.u.last.u.m)])
      ==
      :-  %drops
      :-  %a
      %+  turn  drops
      |=  d=drop
      %-  pairs
      :~  at+(time at.d)  id+s+id.d  platform+s+platform.d
          reason+s+reason.d
      ==
      :-  %senders
      :-  %a
      %+  turn  ~(tap by senders)
      |=  [id=@t x=sender]
      %-  pairs
      :~  id+s+id  name+s+name.x  agent+s+agent.x  allowed+b+allowed.x
          first+(time first.x)
          last+?~(last.x ~ (time u.last.x))
          hour+(numb n.hour:(roll-hour x now))
          sent+(numb sent.x)  held+(numb held.x)  waiting+(numb waited.x)
          cap+(numb cap.x)
      ==
      watches+(pairs (turn watches |=([p=@t v=@t] [p s+v])))
      apps+(pairs (turn apps |=([n=@t r=?] [n b+r])))
      :-  %log
      a+(turn log |=(n=push-note:trunk (pairs ~[at+(time at.n) what+s+what.n])))
  ==
::
++  kinds-json
  |=  k=push-kinds:trunk
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  dm+b+dm.k  club+b+club.k  channel+s+channel.k
      replies+b+replies.k  calls+b+calls.k  reads+b+reads.k
      notices+b+notices.k
  ==
--
