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
[%parsed (roster-from-json:trunk-json u.jon host)]
