::  +test-roster: exercise roster-from-json against a JSON cord.
::  Dev-only harness for the group-mirror parser: the field-name
::  coupling is the one part of the mirror that can rot silently, so
::  it gets a way to be probed from dojo on any ship.
::    +trunk!test-roster ['{"seats":...}' ~host]
/+  trunk-json
:-  %say
|=  [* [txt=@t host=@p ~] ~]
:-  %noun
=/  jon  (de:json:html txt)
?~  jon  [%bad-json ~]
=/  ros  (roster-from-json:trunk-json u.jon host)
?~  ros  [%parsed ~]
::  unpacked so the dojo shows lists, not raw set/map trees — the
::  seat-roles leg is the wire-5 addition this harness now covers.
:-  %parsed
:~  members+~(tap in members.u.ros)
    admins+~(tap in admins.u.ros)
    :-  %seat-roles
    %+  turn  ~(tap by seat-roles.u.ros)
    |=([s=@p r=(set @t)] [s ~(tap in r)])
==
