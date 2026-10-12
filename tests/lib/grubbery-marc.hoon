::  grubbery-marc: the marc grubbery's kernel checks a poke to %trunk
::  with, docs/grubbery-trunk-action.hoon, against sur/trunk.hoon.
::  %trunk's on-poke does !<(action:trunk vase), and the vase carries
::  the marc's whole union, so the union must nest in action:trunk or
::  trunk refuses every grubbery poke, notices too (AGENTS.md, "Grubbery
::  apps must name themselves"). The fleet's grubbery should carry the
::  same file: scripts/ship-checks.sh compares it.
::
/-  trunk
/+  *test, marc=grubbery-marc
|%
++  want  -:!>(*action:trunk)
++  nests  |=(t=type (~(nest ut want) | t))
::
++  test-marc-nests-in-action
  (expect-eq !>(&) !>((nests -:!>(*noun:grab:marc))))
::
::  the check bites: a case trunk lacks fails it
++  test-extra-case-refused
  =/  bad  $%([%push-notice tag=@t title=@t body=@t open=json] [%nope ~])
  (expect-eq !>(|) !>((nests -:!>(*bad))))
::
::  each action a grubbery app sends comes through the marc and
::  trunk's extract unchanged
++  test-each-action-round-trips
  =/  acts=(list *)
    :~  [%push-notice 't' 'title' 'body' ~]
        [%push-notice-as 'calendar' 't' 'title' 'body' ~]
        [%app-room-open-as 'cal' 'party']
        [%app-room-close-as 'cal' 'party']
        [%app-room-rotate-as 'cal' 'party']
        [%app-guest-ticket-as 'cal' 'party' 'user-1' & 'r1']
    ==
  %-  zing
  %+  turn  acts
  |=  a=*
  =/  v  !>((noun:grab:marc a))
  (expect-eq !>(a) !>(`*`!<(action:trunk v)))
--
