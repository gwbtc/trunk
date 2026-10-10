::  +test-guest: guest seats (wire 16) and permanent links (wire 17).
::  Each limit is checked as a pair: the last case allowed, and one more
::  refused. Answers %ok, or the name of each case that came out wrong.
::    +trunk!test-guest
/-  trunk
/+  tg=trunk-guest
:-  %say
|=  *
:-  %noun
=,  tg
=/  now  ~2026.10.10..12.00.00
=/  inv  `invite:trunk`['lounge' & (add now ~h1) 1 ~]
=/  app  `app-room:trunk`['0e1f2a3b' ~ now]
=/  is-guest
  |=  id=@t
  ?&  =(30 (met 3 id))
      =('guest-' (end [3 6] id))
      (levy (trip (rsh [3 6] id)) is-hex)
  ==
=/  first  (guest-of ~ 42)
=/  sid  id.first
=/  sec  secret.first
=/  used  (fall (redeem inv sid now) inv)
=/  other  (new-secret 99)
=/  oid  (id-of other)
=/  full
  %-  ~(gas by *(map @t @t))
  (turn (gulf 1 app-guest-cap) |=(n=@ [(scot %ud n) (guest-id n)]))
=/  cases=(list [@t ?])
  :~  :-  'a guest id is guest- and 24 hex digits'
      (levy `(list @)`~[0 1 42 (bex 300)] |=(e=@ (is-guest (guest-id e))))
      :-  'a guest id never starts with a sig'
      (levy `(list @)`~[0 1 42 (bex 300)] |=(e=@ !=('~' (end 3 (guest-id e)))))
      :-  'a code is 32 hex digits'
      =/  c  (new-code 7)
      &(=(32 (met 3 c)) (levy (trip c) is-hex))
      :-  'two entropies make two codes'
      !=((new-code 1) (new-code 2))
  ::
      ['a new guest has a guest id' (is-guest sid)]
      ['an invite seats a new guest' ?=(^ (redeem inv sid now))]
      ['seating takes a use' =(0 uses.used)]
      ['the seated guest is remembered' (~(has in guests.used) sid)]
      ['an invite with no uses seats nobody new' =(~ (redeem used oid now))]
      ['a guest id is the hash of its secret' =(sid (id-of sec))]
      ['a secret is 32 hex digits' (valid-secret sec)]
      ['a guest id is not a secret' !(valid-secret sid)]
      ['a secret gives back the same guest' =((guest-of `sec 1) [sec sid])]
      :-  'a seated guest rejoins and takes no use'
      =((redeem used sid now) `used)
      ['another secret is another guest' !=(sid oid)]
      ['an invite seats until just before it expires' ?=(^ (redeem inv sid (sub expires.inv ~s1)))]
      ['an invite at its expiry seats nobody' =(~ (redeem inv sid expires.inv))]
      ['a rejoin after expiry is refused' =(~ (redeem used sid expires.used))]
  ::
      :-  'a new guest gets a new secret'
      =/  g  (guest-of ~ 7)
      &((valid-secret secret.g) =(id.g (id-of secret.g)) (is-guest id.g))
      ['an app guest id is a guest id' (is-guest (guest-id 5))]
      ['a link name is a @tas' (valid-name 'groundwire-standup')]
      ['a link name is not too short' !(valid-name 'ab')]
      ['a link name has no slash' !(valid-name 'a/b-c')]
      ['a link name is lower case' !(valid-name 'Standup')]
  ::
      :-  'live keeps an unexpired invite for a hosted room'
      =(1 ~(wyt by (live (my ['c' inv]~) now (sy ~['lounge']))))
      :-  'live drops an expired invite'
      =(~ (live (my ['c' inv]~) expires.inv (sy ~['lounge'])))
      ['a closed room loses its invites' =(~ (drop-invites 'lounge' (my ['c' inv]~)))]
      ['another room keeps its invites' =(1 ~(wyt by (drop-invites 'den' (my ['c' inv]~))))]
      :-  'a closed room loses its permanent links'
      =(~ (drop-links 'lounge' (my ['standup' ['lounge' &]]~)))
      :-  'another room keeps its permanent links'
      =(1 ~(wyt by (drop-links 'den' (my ['standup' ['lounge' &]]~))))
      :-  'live drops an invite for a room no longer hosted'
      =(~ (live (my ['c' inv]~) now ~))
  ::
      :-  'an app user keeps their guest id'
      =/  a  (seat app 'user-1' now 1)
      ?~  a  |
      =/  b  (seat r.u.a 'user-1' now 2)
      ?~(b | &(=(id.u.a id.u.b) =(1 ~(wyt by guests.r.u.b))))
      :-  'a room one short of full seats a new user'
      =/  r  app(guests (~(del by full) '1'))
      ?=(^ (seat r 'new' now 1))
      ['a full room seats no new user' =(~ (seat app(guests full) 'new' now 1))]
      ['a full room still seats a user it has' ?=(^ (seat app(guests full) '1' now 1))]
      :-  'an app room idle just under a day stays'
      =(1 ~(wyt by (prune-apps (my [[%mud 'p'] app]~) (add now (sub app-idle ~s1)))))
      :-  'an app room idle a day closes'
      =(~ (prune-apps (my [[%mud 'p'] app]~) (add now app-idle)))
  ::
      ['an app room name is a @tas' (valid-room 'party-0v3a2')]
      ['an app room name has no slash' !(valid-room 'a/b')]
      ['an app room name is not empty' !(valid-room '')]
      ['an app room name is lower case' !(valid-room 'Party')]
      :-  'an app room is a subgroup no party line can name'
      =/  s  (app-sub ~zod %mud 'p' 'e')
      &(=('zod/mud/p/e' s) =('/' (cut 3 [3 1] s)))
      :-  'a location ends in a slash'
      .=  'http://h:8444/group/talon/zod-x/'
      (location ['http://h:8444' 'talon' 'k'] 'zod-x')
      ['an http base has a ws endpoint' =('ws://h:8444/ws' (endpoint 'http://h:8444'))]
      ['an https base has a wss endpoint' =('wss://sfu.example/ws' (endpoint 'https://sfu.example'))]
  ==
=/  bad  (murn cases |=([n=@t ok=?] ?:(ok ~ `n)))
?~(bad %ok [%failed bad])
