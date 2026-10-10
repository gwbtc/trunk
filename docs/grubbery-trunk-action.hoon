::  mar/clay/trunk/trunk-action: typed marc so grubbery fibers can poke
::  %trunk with %trunk-action. This copy lives in trunk's docs for the
::  grubbery kernel to take; trunk does not build it.
::
::  It carries the actions a grubbery app may send:
::    %push-notice and %push-notice-as (trunk wire 12 and 14): alerts
::    for the owner's phones, under the app's own name.
::    the four app-room -as actions (trunk wire 18): calls the app hosts
::    for its own users, under its own name. See trunk's
::    docs/guest-seats.md, "Grubbery apps".
::
::  TYPED, since %trunk's on-poke does a typed extract and a passthrough
::  marc's untyped vase nest-fails it into a nack. The shapes are
::  sur/trunk.hoon's, exactly.
::
::  DEPLOY ONLY ONCE THE SHIP'S %trunk IS WIRE 18. The vase carries the
::  whole union, and an older trunk's typed extract refuses all of it,
::  notices too: calendar and orrery reminders would stop. The order is
::  trunk 18 on the ship, then this marc, then any app that uses it.
::  Read /~/scry/trunk/version.json first.
::
::  Deploys to /gub/mar/clay/trunk/trunk/action/hoon AND
::  /gub/mar/clay/trunk/trunk-action/hoon (both segment forms).
::
=/  action
  $%  [%push-notice tag=@t title=@t body=@t open=json]
      [%push-notice-as app=@t tag=@t title=@t body=@t open=json]
      [%app-room-open-as app=@t room=@t]
      [%app-room-close-as app=@t room=@t]
      [%app-room-rotate-as app=@t room=@t]
      [%app-guest-ticket-as app=@t room=@t guest=@t speak=? req=@t]
  ==
|_  a=action
++  grad  %noun
++  grow
  |%
  ++  noun  a
  --
++  grab
  |%
  ++  noun  action
  --
--
