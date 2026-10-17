::  +trunk/token: mint a party-line JWT by hand, for testing the
::  signing path against a live Galène. Args: key, sub, aud, ttl-secs.
::  It grants a speaker's permissions; =listen & grants a listener's.
::  A token cannot be revoked, so ttl is capped at 6 hours, a ticket's
::  life, and a key that is not base64url is refused.
::    +trunk!token 'KEY' 'listener' 'http://host/group/talon/zod-x/' 600, =listen &
/+  trunk-jwt
:-  %say
|=  [[now=@da * *] [key=@t sub=@t aud=@t ttl=@ud ~] [listen=_| ~]]
:-  %noun
?>  ?=(^ (de-b64:trunk-jwt key))
=/  t  (unix-secs:trunk-jwt now)
%:  mint:trunk-jwt  key  sub  aud  t  (add t (min ttl 21.600))
  ?:(listen listener:trunk-jwt speaker:trunk-jwt)
==
