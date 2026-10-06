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
=/  r1  (rang ~ 'a' t0)
=/  [took=? r2=rung]  (settle r1 'a' %.y (add t0 ~s10))
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
      :-  'body escapes only backslash and quote'
      .=  (body zod [%read 'a"b\\c'])
      '{"event":"read","patp":"~zod","whom":"a\\"b\\\\c"}'
    ::
      :-  'gateway voip carries the ring body'
      .=  (gateway-body zod 'h' 's' [%ring ~nec 'abc'])
      :-  ~
      %+  rap  3
      :~  '{"handle":"h","secret":"s","kind":"voip","payload":'
          ring-body
          '}'
      ==
    ::
      :-  'gateway alert'
      .=  %:  gateway-body  zod  'h'  's'
            [%message '~nec' '~nec/1' ~ `'~nec' `'hi']
          ==
      :-  ~
      %+  rap  3
      :~  '{"handle":"h","secret":"s","kind":"alert","patp":"~zod",'
          '"whom":"~nec","postId":"~nec/1","title":"~nec","body":"hi"}'
      ==
    ::
      :-  'gateway alert defaults and parent'
      .=  %:  gateway-body  zod  'h'  's'
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
      .=  (gateway-body zod 'h' 's' [%test 'n1'])
      :-  ~
      %+  rap  3
      :~  '{"handle":"h","secret":"s","kind":"alert","patp":"~zod",'
          '"whom":"","postId":"","title":"Talon",'
          '"body":"Notifications from your ship are working",'
          '"nonce":"n1"}'
      ==
    ::
      :-  'gateway takes no read'
      =(~ (gateway-body zod 'h' 's' [%read '~nec']))
    ::
      :-  'unifiedpush read: normal, a day'
      .=  (request zod up [%read 'x'])
      :-  ~
      :^  %'POST'  'https://ntfy.example/up1'
        :~  ['content-type' 'application/json']
            ['ttl' '86400']
            ['urgency' 'normal']
        ==
      (oc '{"event":"read","patp":"~zod","whom":"x"}')
    ::
      :-  'unifiedpush read only with the read cap'
      =(~ (request zod up-old [%read 'x']))
    ::
      :-  'unifiedpush ring: urgent, a minute'
      .=  (request zod up-old [%ring ~nec 'abc'])
      :-  ~
      :^  %'POST'  'https://ntfy.example/up1'
        :~  ['content-type' 'application/json']
            ['ttl' '60']
            ['urgency' 'high']
        ==
      (oc ring-body)
    ::
      :-  'gateway ring goes to /gateway/push'
      .=  (request zod gw [%ring ~nec 'abc'])
      :-  ~
      :^  %'POST'  'https://relay.example/gateway/push'
        ~[['content-type' 'application/json']]
      (oc (need (gateway-body zod 'h' 's' [%ring ~nec 'abc'])))
    ::
      :-  'gateway url without a slash'
      =('https://r.example/gateway/push' (gateway-url 'https://r.example'))
    ::
      :-  'gateway takes no read request'
      =(~ (request zod gw [%read 'x']))
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
      ?&  !(allows '~zod' `'none' %.y)
          !(allows 'chat/~zod/x' `'none' %.y)
      ==
    ::
      :-  'policy: mentions only for channels, DMs always'
      ?&  !(allows 'chat/~zod/x' `'mentions' %.n)
          (allows 'chat/~zod/x' `'mentions' %.y)
          (allows '~zod' `'mentions' %.n)
          (allows '0v1.abc' `'mentions' %.n)
      ==
    ::
      :-  'policy: unset and all defer to the ship'
      ?&  (allows 'chat/~zod/x' ~ %.n)
          (allows 'chat/~zod/x' `'all' %.n)
      ==
    ::
      :-  'level from settings'
      =/  s  (j '{"desk":{"notify-prefs":{"chat/~nec/x":{"level":"mentions"}}}}')
      ?&  =(`'mentions' (level-of s 'chat/~nec/x'))
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
      ?&  =([%.y ~] (settle r1 'a' %.n (add t0 ~s30)))
          =([%.n ~] (settle r1 'a' %.n (add t0 ~s90)))
          =([%.n r1] (settle r1 'b' %.n t0))
      ==
    ::
      :-  'rung: an answer keeps the call for its hangup'
      ?&  took
          =(`[(add t0 ~s10) %.y] (~(get by r2) 'a'))
          =([%.y ~] (settle r2 'a' %.n (add t0 ~h1)))
      ==
    ::
      :-  'rung: a new ring prunes the old'
      =(~[%b] ~(tap in ~(key by (rang r1 'b' (add t0 ~m2)))))
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
  ==
=/  bad  (murn cases |=([n=@t o=?] ?:(o ~ `n)))
?~(bad %ok bad)
