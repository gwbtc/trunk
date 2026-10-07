::  +test-push: the push hints of wire 11, against Talon's relay. The
::  bodies are pinned to the bytes Push.kt sends; the policy and
::  preview cases are the relay's NotifyPolicyTest and
::  ActivityPreviewTest; the events are %activity v4's own shapes.
::  Answers %ok, or each case that came out wrong.
::    +trunk!test-push
/-  trunk
/+  tp=trunk-push, trunk-json
:-  %say
|=  *
:-  %noun
=,  tp
=/  j  |=(t=@t (need (de:json:html t)))
=/  zod  ~zod
=/  oc  |=(t=@t `(as-octs:mimes:html t))
=/  ell  (tufa ~[`@c`0x2026])
=/  t0  ~2026.10.6..12.00.00
=/  da-id  (rap 3 ~['~nec/' (scot %ud t0)])
=/  undotted
  (rap 3 ~['~nec/' (crip (skip (trip (scot %ud t0)) |=(c=@ =(c '.'))))])
::
::  %activity v4 facts, as eyre gave them to the relay
=/  dm-post
  %-  j
  '''
  {"add":{"source":{"dm":{"ship":"~nec"}},"event":{"notified":true,
  "child":false,"dm-post":{"key":{"id":"~nec/170.1","time":"170.1"},
  "whom":{"ship":"~nec"},"content":[{"inline":["hey ",{"ship":"~bus"},
  {"break":null},{"bold":["now"]}]}],"mention":false}}}}
  '''
=/  quiet-post
  %-  j
  '''
  {"add":{"source":{"dm":{"ship":"~nec"}},"event":{"notified":false,
  "child":false,"dm-post":{"key":{"id":"~nec/170.1","time":"170.1"},
  "whom":{"ship":"~nec"},"content":[],"mention":false}}}}
  '''
=/  club-post
  %-  j
  '''
  {"add":{"source":{"dm":{"club":"0v1.abc"}},"event":{"notified":true,
  "child":false,"dm-post":{"key":{"id":"~bus/170.5","time":"170.5"},
  "whom":{"club":"0v1.abc"},"content":[],"mention":false}}}}
  '''
=/  chan-post
  %-  j
  '''
  {"add":{"source":{"channel":{"nest":"chat/~nec/x","group":"~nec/g"}},
  "event":{"notified":true,"child":false,"post":{"key":{"id":"~bus/170.2",
  "time":"170.2"},"channel":"chat/~nec/x","group":"~nec/g",
  "content":[{"block":{"image":{"src":"x","alt":""}}}],"mention":true}}}}
  '''
=/  chan-reply
  %-  j
  '''
  {"add":{"source":{"thread":{"key":{"id":"~nec/170.1","time":"170.1"},
  "channel":"chat/~nec/x","group":"~nec/g"}},"event":{"notified":true,
  "child":true,"reply":{"key":{"id":"~bus/170.3","time":"170.3"},
  "parent":{"id":"~nec/170.1","time":"170.1"},"channel":"chat/~nec/x",
  "group":"~nec/g","content":[],"mention":false}}}}
  '''
=/  club-reply
  %-  j
  '''
  {"add":{"source":{"dm-thread":{"key":{"id":"~nec/170.1","time":"170.1"},
  "whom":{"club":"0v1.abc"}}},"event":{"notified":true,"child":true,
  "dm-reply":{"key":{"id":"~bus/170.4","time":"170.4"},
  "parent":{"id":"~nec/170.1","time":"170.1"},"whom":{"club":"0v1.abc"},
  "content":[],"mention":false}}}}
  '''
=/  invite
  %-  j
  '''
  {"add":{"source":{"dm":{"ship":"~nec"}},"event":{"notified":true,
  "child":false,"dm-invite":{"ship":"~nec"}}}}
  '''
=/  read
  |=  [src=@t count=@t]
  %-  j
  %-  crip
  ;:  weld
    "\{\"read\":\{\"source\":"  (trip src)
    ",\"activity\":\{\"recency\":1,\"count\":"  (trip count)
    ",\"notify-count\":0,\"notify\":false,\"unread\":null,"
    "\"children\":[]}}}"
  ==
::
=/  up=push-device:trunk
  [[%unifiedpush 'https://ntfy.example/up1'] (sy 'read' ~)]
=/  up-old=push-device:trunk
  [[%unifiedpush 'https://ntfy.example/up1'] ~]
=/  gw=push-device:trunk
  [[%ios-gateway 'https://relay.example/' 'h' 's'] ~]
=/  ring-body  '{"event":"ring","patp":"~zod","from":"~nec","id":"abc"}'
::
=/  p1  (sy 'p1' ~)
=/  r1  (rang ~ 'a' t0 p1)
=/  [took=(set @t) r2=rung]  (settle r1 'a' %.y (add t0 ~s10))
::
=/  cases=(list [@t ?])
  :~  :-  'body new-message'
      .=  (body zod [%message '~nec' '~nec/170.1' ~ ~ ~])
      '{"event":"new-message","patp":"~zod","whom":"~nec","id":"~nec/170.1"}'
    ::
      :-  'body new-message on a reply'
      .=  (body zod [%message 'chat/~nec/x' '~bus/170.3' `'~nec/170.1' ~ ~])
      %+  rap  3
      :~  '{"event":"new-message","patp":"~zod","whom":"chat/~nec/x",'
          '"id":"~bus/170.3","parent":"~nec/170.1"}'
      ==
    ::
      :-  'body ring'
      =(ring-body (body zod [%ring ~nec 'abc']))
    ::
      :-  'body ring-cancel'
      .=  (body zod [%ring-cancel 'abc' 'hangup'])
      '{"event":"ring-cancel","patp":"~zod","id":"abc","reason":"hangup"}'
    ::
      :-  'body read'
      .=  (body zod [%read 'chat/~nec/x'])
      '{"event":"read","patp":"~zod","whom":"chat/~nec/x"}'
    ::
      :-  'body push-test'
      .=  (body zod [%test 'n1'])
      '{"event":"push-test","patp":"~zod","nonce":"n1"}'
    ::
      :-  'body escapes backslash and quote as Push.kt did'
      .=  (body zod [%read 'a"b\\c'])
      '{"event":"read","patp":"~zod","whom":"a\\"b\\\\c"}'
    ::
      :-  'body escapes control characters'
      =('"a\\nb\\u0001c\\td\\re\\u001b"' (qt 'a\0ab\01c\09d\0de\1b'))
    ::
      :-  'a call id with a line feed still makes JSON'
      =/  out  (body zod [%ring ~nec 'x\0ay'])
      ?&  =('{"event":"ring","patp":"~zod","from":"~nec","id":"x\\ny"}' out)
          ?=(^ (de:json:html out))
      ==
    ::
      :-  'the drop guard'
      =/  sent  (sham target.up)
      ?&  (gone up sent 410)
          (gone up sent 404)
          !(gone up (sham [%unifiedpush 'https://elsewhere.example']) 410)
          !(gone up sent 401)
          !(gone up sent 500)
          (gone gw (sham target.gw) 401)
      ==
    ::
      :-  'gateway voip carries the ring body'
      .=  (gateway-body zod 'h' 's' ~ ~ [%ring ~nec 'abc'])
      :-  ~
      %+  rap  3
      :~  '{"handle":"h","secret":"s","kind":"voip","payload":'
          ring-body
          '}'
      ==
    ::
      :-  'gateway alert'
      .=  %:  gateway-body  zod  'h'  's'  ~  ~
            [%message '~nec' '~nec/1' ~ `'~nec' `'hi']
          ==
      :-  ~
      %+  rap  3
      :~  '{"handle":"h","secret":"s","kind":"alert","patp":"~zod",'
          '"whom":"~nec","postId":"~nec/1","title":"~nec","body":"hi"}'
      ==
    ::
      :-  'gateway alert defaults and parent'
      .=  %:  gateway-body  zod  'h'  's'  ~  ~
            [%message 'chat/~nec/x' '~bus/2' `'~nec/1' ~ ~]
          ==
      :-  ~
      %+  rap  3
      :~  '{"handle":"h","secret":"s","kind":"alert","patp":"~zod",'
          '"whom":"chat/~nec/x","postId":"~bus/2","title":"~zod",'
          '"body":"New message","parent":"~nec/1"}'
      ==
    ::
      :-  'gateway test alert'
      .=  (gateway-body zod 'h' 's' ~ ~ [%test 'n1'])
      :-  ~
      %+  rap  3
      :~  '{"handle":"h","secret":"s","kind":"alert","patp":"~zod",'
          '"whom":"","postId":"","title":"Talon",'
          '"body":"Notifications from your ship are working",'
          '"nonce":"n1"}'
      ==
    ::
      :-  'gateway takes no read'
      =(~ (gateway-body zod 'h' 's' ~ ~ [%read '~nec']))
    ::
      :-  'unifiedpush read: normal, a day'
      .=  (request zod up ~ [%read 'x'])
      :-  ~
      :^  %'POST'  'https://ntfy.example/up1'
        :~  ['content-type' 'application/json']
            ['ttl' '86400']
            ['urgency' 'normal']
        ==
      (oc '{"event":"read","patp":"~zod","whom":"x"}')
    ::
      :-  'unifiedpush read only with the read cap'
      =(~ (request zod up-old ~ [%read 'x']))
    ::
      :-  'unifiedpush ring: urgent, a minute'
      .=  (request zod up-old ~ [%ring ~nec 'abc'])
      :-  ~
      :^  %'POST'  'https://ntfy.example/up1'
        :~  ['content-type' 'application/json']
            ['ttl' '60']
            ['urgency' 'high']
        ==
      (oc ring-body)
    ::
      :-  'gateway ring goes to /gateway/push'
      .=  (request zod gw ~ [%ring ~nec 'abc'])
      :-  ~
      :^  %'POST'  'https://relay.example/gateway/push'
        ~[['content-type' 'application/json']]
      (oc (need (gateway-body zod 'h' 's' ~ ~ [%ring ~nec 'abc'])))
    ::
      :-  'gateway url without a slash'
      =('https://r.example/gateway/push' (gateway-url 'https://r.example'))
    ::
      :-  'gateway takes no read request'
      =(~ (request zod gw ~ [%read 'x']))
    ::
      :-  'dead answers'
      ?&  (dead [%unifiedpush 'x'] 404)
          (dead [%unifiedpush 'x'] 410)
          !(dead [%unifiedpush 'x'] 401)
          !(dead [%unifiedpush 'x'] 500)
          (dead [%ios-gateway 'x' 'h' 's'] 401)
          !(dead [%ios-gateway 'x' 'h' 's'] 409)
      ==
    ::
      :-  'valid devices'
      ?&  (valid-device up)
          (valid-device gw)
          !(valid-device [[%unifiedpush 'not a url'] ~])
          !(valid-device [[%ios-gateway 'https://r.example' '' 's'] ~])
          !(valid-device [[%ios-gateway 'https://r.example' 'h' ''] ~])
      ==
    ::
      :-  'policy: none silences everything'
      ?&  !(allows '~zod' `'none' %.y %.n)
          !(allows 'chat/~zod/x' `'none' %.y %.n)
          !(allows 'chat/~zod/x' `'none' %.y %.y)
      ==
    ::
      :-  'policy: mentions only for channels, DMs always'
      ?&  !(allows 'chat/~zod/x' `'mentions' %.n %.n)
          (allows 'chat/~zod/x' `'mentions' %.y %.n)
          (allows '~zod' `'mentions' %.n %.n)
          (allows '0v1.abc' `'mentions' %.n %.n)
      ==
    ::
      :-  'policy: a notified reply passes mentions'
      ?&  (allows 'chat/~zod/x' `'mentions' %.n %.y)
          (allows 'chat/~zod/x' ~ %.n %.y)
      ==
    ::
      :-  'policy: unset is mentions, as Talon shows it'
      ?&  !(allows 'chat/~zod/x' ~ %.n %.n)
          !(allows 'heap/~zod/x' ~ %.n %.n)
          (allows 'chat/~zod/x' ~ %.y %.n)
          (allows '~zod' ~ %.n %.n)
          (allows '0v1.abc' ~ %.n %.n)
          (allows 'chat/~zod/x' `'all' %.n %.n)
      ==
    ::
      :-  'level from settings'
      =/  s  (j '{"desk":{"notify-prefs":{"chat/~nec/x":{"level":"mentions"}}}}')
      ?&  =(`'mentions' (level-of s 'chat/~nec/x'))
          =(~ (level-of s '~nec'))
      ==
    ::
      :-  'level from settings, as Talon stores it on a live ship'
      =/  s
        %-  j
        %+  rap  3
        :~  '{"desk":{"notify-prefs":{'
            '"chat/~darduc-mitfen/chat":"{\\"level\\":\\"mentions\\"}",'
            '"~martyr-sanryg":"{\\"level\\":\\"all\\"}",'
            '"~bus":"not json"}}}'
        ==
      ?&  =(`'mentions' (level-of s 'chat/~darduc-mitfen/chat'))
          =(`'all' (level-of s '~martyr-sanryg'))
          =(~ (level-of s '~bus'))
          =(~ (level-of s '~nec'))
      ==
    ::
      :-  'dm-post notifies'
      =/  p  (add-post dm-post)
      ?&  ?=(^ p)
          =('~nec' whom.u.p)
          =('~nec/170.1' id.u.p)
          =(~ parent.u.p)
          !mention.u.p
          =(`'hey ~bus now' (preview (need content.u.p)))
      ==
    ::
      :-  'a club DM is its club'
      =(`'0v1.abc' (bind (add-post club-post) |=(p=post whom.p)))
    ::
      :-  'a channel post, mentioning us'
      =/  p  (add-post chan-post)
      ?&  ?=(^ p)
          =('chat/~nec/x' whom.u.p)
          =('~bus/170.2' id.u.p)
          mention.u.p
          =(`'[image]' (preview (need content.u.p)))
      ==
    ::
      :-  'a thread reply is its channel, with its parent'
      =/  p  (add-post chan-reply)
      ?&  ?=(^ p)
          =('chat/~nec/x' whom.u.p)
          =('~bus/170.3' id.u.p)
          =(`'~nec/170.1' parent.u.p)
      ==
    ::
      :-  'a club thread reply is its club'
      =/  p  (add-post club-reply)
      ?&  ?=(^ p)
          =('0v1.abc' whom.u.p)
          =(`'~nec/170.1' parent.u.p)
      ==
    ::
      :-  'a 1:1 thread reply is its DM'
      =/  p
        %-  add-post
        %-  j
        %+  rap  3
        :~  '{"add":{"source":{"dm-thread":{"key":{"id":"~nec/170.1",'
            '"time":"170.1"},"whom":{"ship":"~nec"}}},"event":{"notified":true,'
            '"child":true,"dm-reply":{"key":{"id":"~nec/170.6","time":"170.6"},'
            '"parent":{"id":"~nec/170.1","time":"170.1"},"whom":{"ship":"~nec"},'
            '"content":[],"mention":false}}}}'
        ==
      ?&  ?=(^ p)
          =('~nec' whom.u.p)
          =(`'~nec/170.1' parent.u.p)
      ==
    ::
      :-  'not notified, or not a post: nothing'
      ?&  =(~ (add-post quiet-post))
          =(~ (add-post invite))
          =(~ (add-post (read '{"dm":{"ship":"~bus"}}' '0')))
      ==
    ::
      :-  'read to the end'
      ?&  =(`'~bus' (read-whom (read '{"dm":{"ship":"~bus"}}' '0')))
          =(`'0v1.abc' (read-whom (read '{"dm":{"club":"0v1.abc"}}' '0')))
          =(`'chat/~nec/x' (read-whom (read '{"channel":{"nest":"chat/~nec/x","group":"~nec/g"}}' '0')))
      ==
    ::
      :-  'not read: unread left, a thread, an add'
      ?&  =(~ (read-whom (read '{"dm":{"ship":"~bus"}}' '2')))
          .=  ~
          %-  read-whom
          %-  j
          %+  rap  3
          :~  '{"read":{"source":{"dm":{"ship":"~bus"}},"activity":'
              '{"recency":1,"count":0,"notify-count":1,"notify":true,'
              '"unread":null,"children":[]}}}'
          ==
          =(~ (read-whom (read '{"thread":{"channel":"chat/~nec/x","group":"~nec/g"}}' '0')))
          =(~ (read-whom dm-post))
      ==
    ::
      :-  'preview: empty is nothing'
      =(~ (preview (j '[]')))
    ::
      :-  'preview: whitespace folds'
      =(`'a b' (preview (j '["  a \\n\\n b  "]')))
    ::
      :-  'preview: other control characters go'
      =(`'a[31mred!' (preview [%a [%s 'a\1b[31mred\00!'] ~]))
    ::
      :-  'preview: bytes that are not UTF-8 cost only the preview'
      =/  r  (preview [%a [%s (cat 3 'ok ' 0xff)] ~])
      |(=(~ r) ?=(^ r))
    ::
      :-  'preview: sect, link, cite'
      .=  `'@all @admin c [quote]'
      %-  preview
      %-  j
      '[{"sect":null}," ",{"sect":"admin"}," ",{"link":{"href":"h","content":"c"}}," ",{"cite":{}}]'
    ::
      :-  'preview: cut at 140 with an ellipsis'
      .=  `(crip (weld (reap 139 'a') ell))
      (preview [%a [%s (crip (reap 200 'a'))] ~])
    ::
      :-  'preview: cut by character, not byte'
      .=  `(crip (tufa (snoc (reap 139 `@c`0xe9) `@c`0x2026)))
      (preview [%a [%s (crip (tufa (reap 150 `@c`0xe9)))] ~])
    ::
      :-  'author'
      ?&  =(`'~nec' (author '~nec/170.1'))
          =(`'~nec' (author '~nec'))
          =(~ (author '170.1'))
      ==
    ::
      :-  'post time, dotted or not'
      ?&  =(`t0 (post-time da-id))
          =(`t0 (post-time undotted))
          =(~ (post-time '~nec/'))
      ==
    ::
      :-  'fresh for five minutes'
      ?&  (fresh da-id (add t0 ~m4))
          !(fresh da-id (add t0 ~m6))
          (fresh da-id (sub t0 ~s1))
          (fresh 'no-time' t0)
      ==
    ::
      :-  'seen prunes to the window'
      .=  (sy '~a/1' ~)
      %~  key  by
      (prune-seen (my ~[['~a/1' (sub t0 ~m1)] ['~a/2' (sub t0 ~m6)]]) t0)
    ::
      :-  'rung: a hangup cancels a fresh ring only'
      ?&  =([p1 ~] (settle r1 'a' %.n (add t0 ~s30)))
          =([~ ~] (settle r1 'a' %.n (add t0 ~s90)))
          =([~ r1] (settle r1 'b' %.n t0))
      ==
    ::
      :-  'rung: an answer keeps the call for its hangup'
      ?&  =(p1 took)
          =(`[(add t0 ~s10) %.y p1] (~(get by r2) 'a'))
          =([p1 ~] (settle r2 'a' %.n (add t0 ~h1)))
      ==
    ::
      :-  'rung: a new ring prunes the old'
      =(~[%b] ~(tap in ~(key by (rang r1 'b' (add t0 ~m2) p1))))
    ::
      :-  'json: push-register unifiedpush'
      .=  %-  action-from-json:trunk-json
          %-  j
          '''
          {"push-register":{"id":"d1","platform":"unifiedpush",
          "endpoint":"https://n.example/u","caps":["read"]}}
          '''
      `action:trunk`[%push-register 'd1' [%unifiedpush 'https://n.example/u'] (sy 'read' ~)]
    ::
      :-  'json: push-register ios-gateway'
      .=  %-  action-from-json:trunk-json
          %-  j
          '''
          {"push-register":{"id":"d2","platform":"ios-gateway",
          "gateway":"https://g.example","handle":"h","secret":"s",
          "caps":[]}}
          '''
      `action:trunk`[%push-register 'd2' [%ios-gateway 'https://g.example' 'h' 's'] ~]
    ::
      :-  'json: push-unregister and push-test'
      ?&  .=  `action:trunk`[%push-unregister 'd1']
              (action-from-json:trunk-json (j '{"push-unregister":"d1"}'))
          .=  `action:trunk`[%push-test 'd1' 'n']
              (action-from-json:trunk-json (j '{"push-test":{"id":"d1","nonce":"n"}}'))
      ==
    ::
      :-  'json: an unknown platform is refused'
      =/  bad
        '{"push-register":{"id":"d1","platform":"fcm","caps":[]}}'
      =/  r  (mule |.((action-from-json:trunk-json (j bad))))
      ?=(%| -.r)
    ::
      :-  'json: push-kinds'
      .=  `action:trunk`[%push-kinds [%.n %.y %mentions %.y %.n %.y %.n]]
      %-  action-from-json:trunk-json
      %-  j
      %+  rap  3
      :~  '{"push-kinds":{"dm":false,"club":true,"channel":"mentions",'
          '"replies":true,"calls":false,"reads":true,"notices":false}}'
      ==
    ::
      :-  'switches: all on lets every kind through'
      ?&  (wants all-kinds (need (add-post dm-post)))
          (wants all-kinds (need (add-post club-post)))
          (wants all-kinds (need (add-post chan-post)))
          (wants all-kinds (need (add-post chan-reply)))
          (wants all-kinds (need (add-post club-reply)))
      ==
    ::
      :-  'switches: each one stops its own kind'
      =/  k  all-kinds
      =/  dm  (need (add-post dm-post))
      =/  club  (need (add-post club-post))
      =/  reply  (need (add-post chan-reply))
      ?&  !(wants k(dm %.n) dm)
          (wants k(dm %.n) club)
          !(wants k(club %.n) club)
          !(wants k(replies %.n) reply)
          (wants k(replies %.n) dm)
          !(wants k(channel %none) reply)
      ==
    ::
      :-  'switches: channel posts by mention'
      =/  k  all-kinds
      =/  quiet=post  ['chat/~nec/x' '~bus/1' ~ %.n ~]
      =/  loud=post  ['chat/~nec/x' '~bus/1' ~ %.y ~]
      ?&  (wants k(channel %mentions) loud)
          !(wants k(channel %mentions) quiet)
          (wants k quiet)
          !(wants k(channel %none) loud)
      ==
    ::
      :-  'the log names the kind of chat, never the chat'
      ?&  =("DM" (chat-word (need (add-post dm-post))))
          =("group DM reply" (chat-word (need (add-post club-reply))))
          =("channel reply" (chat-word (need (add-post chan-reply))))
          =("channel post" (chat-word (need (add-post chan-post))))
      ==
    ::
      :-  'the log keeps the newest 50'
      =/  l
        =|  l=(list push-note:trunk)
        =/  i=@ud  0
        |-  ^-  (list push-note:trunk)
        ?:  =(60 i)  l
        $(i +(i), l (note l (add t0 i) "line"))
      ?&  =(50 (lent l))
          =((add t0 59) at:(snag 0 l))
      ==
    ::
      :-  'a host, never its path, query or user'
      ?&  =('ntfy.example' (host-of 'https://ntfy.example/upSECRET?x=1'))
          =('h.example:8443' (host-of 'https://u:p@h.example:8443/p'))
          =('127.0.0.1:8193' (host-of 'http://127.0.0.1:8193/up/x'))
          =('relay.nisfeb.com' (host-of 'https://relay.nisfeb.com'))
      ==
    ::
      :-  'the debug report carries no secret'
      =/  devs=(map @t push-device:trunk)
        %-  my
        :~  :-  'phone'
            [[%unifiedpush 'https://ntfy.example/upPATHXYZ?t=QUERYXYZ'] (sy 'read' ~)]
            ['ipad' [[%ios-gateway 'https://relay.example/' 'HANDLEXYZ' 'SECRETXYZ'] ~]]
        ==
      =/  out=tape
        %-  trip
        %-  en:json:html
        %:  debug-json  12  0v1  t0  all-kinds  devs
          (my ['phone' [t0 `[t0 %message] `[t0 200]]] ~)
          ~[[t0 'gone' %ios-gateway '410']]
          `3
          ~
          ~[['/v4' 'live']]
          ~[['activity' %.y]]
          (note ~ t0 "DM: pushed to 2 devices")
        ==
      ?&  =(~ (find "PATHXYZ" out))
          =(~ (find "QUERYXYZ" out))
          =(~ (find "HANDLEXYZ" out))
          =(~ (find "SECRETXYZ" out))
          ?=(^ (find "ntfy.example" out))
          ?=(^ (find "relay.example" out))
          ?=(^ (find "pushed to 2 devices" out))
      ==
    ::
      :-  'the report has the status of each device and the drops'
      =/  out=tape
        %-  trip
        %-  en:json:html
        %:  debug-json  12  0v1  t0  all-kinds
          (my ['phone' [[%unifiedpush 'https://n.example/u'] ~]] ~)
          (my ['phone' [t0 `[t0 %message] `[t0 200]]] ~)
          ~[[t0 'gone' %ios-gateway '410']]
          `3
          ~
          ~
          ~
          ~
        ==
      ?&  ?=(^ (find "\"registered\"" out))
          ?=(^ (find "\"kind\":\"message\"" out))
          ?=(^ (find "\"code\":200" out))
          ?=(^ (find "\"reason\":\"410\"" out))
          ?=(^ (find "\"badge\":3" out))
      ==
    ::
      :-  'gateway clear, only for a device that takes reads'
      ?&  .=  `'{"handle":"h","secret":"s","kind":"clear","patp":"~zod","whom":"~nec"}'
              (gateway-body zod 'h' 's' (sy 'read' ~) ~ [%read '~nec'])
          =(~ (gateway-body zod 'h' 's' ~ ~ [%read '~nec']))
      ==
    ::
      :-  'gateway badge, only for a device that shows one'
      ?&  .=  `'{"handle":"h","secret":"s","kind":"badge","badge":12}'
              (gateway-body zod 'h' 's' (sy 'badge' ~) ~ [%badge 12])
          =(~ (gateway-body zod 'h' 's' ~ ~ [%badge 12]))
      ==
    ::
      :-  'an alert to a counting iPhone carries the count'
      .=  %:  gateway-body  zod  'h'  's'  (sy 'badge' ~)  `4
            [%message '~nec' '~nec/1' ~ `'~nec' `'hi']
          ==
      :-  ~
      %+  rap  3
      :~  '{"handle":"h","secret":"s","kind":"alert","patp":"~zod",'
          '"whom":"~nec","postId":"~nec/1","title":"~nec","body":"hi",'
          '"badge":4}'
      ==
    ::
      :-  'a notice, to the gateway'
      =/  open  (j '{"app":"calendar","event":"e1"}')
      .=  %:  gateway-body  zod  'h'  's'  (sy 'notice' ~)  `0
            [%notice 'calendar' 'cal-e1' 'Leave now' 'Meeting at 3' open]
          ==
      :-  ~
      %+  rap  3
      :~  '{"handle":"h","secret":"s","kind":"alert","patp":"~zod",'
          '"whom":"cal-e1","postId":"","title":"Leave now",'
          '"body":"Meeting at 3","event":"notice",'
          (cat 3 '"open":' (en:json:html open))
          ',"app":"calendar"}'
      ==
    ::
      :-  'a notice, to UnifiedPush: urgent, an hour, caps only'
      =/  dev=push-device:trunk  [[%unifiedpush 'https://n.example/u'] (sy 'notice' ~)]
      =/  =hint  [%notice 'calendar' 'cal-e1' 'Leave now' 'Meeting at 3' ~]
      ?&  .=  (request zod dev ~ hint)
              :-  ~
              :^  %'POST'  'https://n.example/u'
                :~  ['content-type' 'application/json']
                    ['ttl' '3600']
                    ['urgency' 'high']
                ==
              %-  oc
              %+  rap  3
              :~  '{"event":"notice","patp":"~zod","tag":"cal-e1",'
                  '"title":"Leave now","body":"Meeting at 3","open":null,'
                  '"app":"calendar"}'
              ==
          =(~ (request zod up ~ hint))
          =(~ (request zod gw ~ hint))
      ==
    ::
      :-  'no badge to UnifiedPush'
      =(~ (request zod up ~ [%badge 1]))
    ::
      :-  'what goes again, and on what answer'
      ?&  (retryable [%message '~nec' '~nec/1' ~ ~ ~])
          (retryable [%read '~nec'])
          (retryable [%badge 1])
          (retryable [%notice 'a' 't' 't' 'b' ~])
          !(retryable [%ring ~nec 'c'])
          !(retryable [%ring-cancel 'c' 'hangup'])
          !(retryable [%test 'n'])
          (retry-code 500)
          (retry-code 503)
          (retry-code 429)
          (retry-code 0)
          !(retry-code 404)
          !(retry-code 410)
          !(retry-code 401)
          !(retry-code 409)
          =(~s30 (retry-after 0))
          =(~m5 (retry-after 1))
      ==
    ::
      :-  'json: push-notice, with and without open'
      ?&  .=  `action:trunk`[%push-notice 't' 'ti' 'b' (j '{"a":1}')]
              %-  action-from-json:trunk-json
              (j '{"push-notice":{"tag":"t","title":"ti","body":"b","open":{"a":1}}}')
          .=  `action:trunk`[%push-notice 't' 'ti' 'b' ~]
              %-  action-from-json:trunk-json
              (j '{"push-notice":{"tag":"t","title":"ti","body":"b"}}')
      ==
    ::
      :-  'who sent a notice'
      ?&  =(['calendar' 'calendar' %calendar] (sender-of /gall/calendar ~))
          =(['calendar' 'calendar' %calendar] (sender-of /gall/calendar `'calendar'))
          =(['grubbery/calendar' 'calendar' %grubbery] (sender-of /gall/grubbery `'calendar'))
          =(['grubbery' 'grubbery' %grubbery] (sender-of /gall/grubbery ~))
          =(['eyre' 'eyre' %eyre] (sender-of /eyre ~))
          =(['unknown' 'unknown' %unknown] (sender-of / ~))
      ==
    ::
      :-  'an app name a phone can show'
      ?&  (valid-app 'calendar')
          (valid-app 'Orrery 2')
          !(valid-app '')
          !(valid-app 'bad\0aname')
          !(valid-app (crip (reap 41 'a')))
      ==
    ::
      :-  'an app gets a fresh hour once the last one is over'
      =/  x=sender  ['cal' %calendar %.y t0 ~ [t0 30] 30 0 ~ 0 ~]
      ?&  =(30 n.hour:(roll-hour x (add t0 ~m59)))
          =(0 n.hour:(roll-hour x (add t0 ~h1)))
          =((add t0 ~h1) start.hour:(roll-hour x (add t0 ~h1)))
      ==
    ::
      :-  'the report lists the apps that sent alerts'
      =/  out=tape
        %-  trip
        %-  en:json:html
        %:  debug-json  12  0v1  t0  all-kinds  ~  ~  ~  ~
          (my ['grubbery/calendar' ['calendar' %grubbery %.n t0 `t0 [t0 4] 9 2 ~ 0 ~]] ~)
          ~  ~  ~
        ==
      ?&  ?=(^ (find "\"senders\"" out))
          ?=(^ (find "\"id\":\"grubbery/calendar\"" out))
          ?=(^ (find "\"agent\":\"grubbery\"" out))
          ?=(^ (find "\"allowed\":false" out))
          ?=(^ (find "\"hour\":4" out))
          ?=(^ (find "\"held\":2" out))
      ==
    ::
      :-  'json: push-notice-as and push-app'
      ?&  .=  `action:trunk`[%push-notice-as 'calendar' 't' 'ti' 'b' ~]
              %-  action-from-json:trunk-json
              (j '{"push-notice-as":{"app":"calendar","tag":"t","title":"ti","body":"b"}}')
          .=  `action:trunk`[%push-app 'grubbery/calendar' %.n]
              %-  action-from-json:trunk-json
              (j '{"push-app":{"id":"grubbery/calendar","allow":false}}')
      ==
    ::
      :-  'one notice that waited goes as itself'
      =/  one  ['cal-1' 'Leave now' 'Meeting at 3' ~]
      =(one (batch 'calendar' 1 ~[one]))
    ::
      :-  'several that waited go as one summary'
      =/  b
        %^  batch  'calendar'  3
        :~  ['cal-3' 'Third' 'c' ~]
            ['cal-2' 'Second' 'b' ~]
            ['cal-1' 'First' 'a' ~]
        ==
      ?&  =('batch-calendar' tag.b)
          =('3 alerts from calendar' title.b)
          =('First\0aSecond\0aThird' body.b)
          =(~ open.b)
      ==
    ::
      :-  'a long burst shows five titles and counts the rest'
      =/  items=(list [tag=@t title=@t body=@t open=json])
        (turn (gulf 1 8) |=(n=@ud [(scot %ud n) (scot %ud n) '' ~]))
      =/  b  (batch 'orrery' 12 items)
      ?&  =('12 alerts from orrery' title.b)
          =('8\0a7\0a6\0a5\0a4\0aand 7 more' body.b)
      ==
  ==
=/  bad  (murn cases |=([n=@t o=?] ?:(o ~ `n)))
?~(bad %ok bad)
