::  trunk-json: +roster-from-json, the group mirror's whole coupling to
::  a Tlon group's JSON. It reads field names, both schema generations
::  (seats/roles/admins, and fleet/sects/bloc before them), and a shape
::  it does not know gives ~ so the line keeps its old roster.
::  gen/test-roster.hoon probes it by hand; these pin it.
::
/+  *test, trunk-json
|%
++  ros
  |=  [txt=@t host=@p]
  (roster-from-json:trunk-json (need (de:json:html txt)) host)
::
++  test-current-schema
  =/  r
    %-  need
    %+  ros
      '''
      {"seats":{"~nec":{"roles":["mod"]},"~bud":{"roles":["admin"]},
      "~wes":{"roles":[]}},"admins":["mod"]}
      '''
    ~zod
  ;:  weld
    (expect-eq !>((silt ~[~nec ~bud ~wes])) !>(members.r))
    ::  'admin' is always an admin role; 'mod' is one the group lists
    (expect-eq !>((silt ~[~nec ~bud])) !>(admins.r))
    (expect-eq !>(`(set @t)`(silt ~['mod'])) !>((~(got by seat-roles.r) ~nec)))
    (expect-eq !>(`(set @t)`~) !>((~(got by seat-roles.r) ~wes)))
  ==
::
++  test-legacy-schema
  =/  r
    %-  need
    %+  ros
      '{"fleet":{"~nec":{"sects":["op"]},"~bud":{"sects":[]}},"bloc":["op"]}'
    ~zod
  ;:  weld
    (expect-eq !>((silt ~[~nec ~bud])) !>(members.r))
    (expect-eq !>((silt ~[~nec])) !>(admins.r))
    (expect-eq !>(`(set @t)`(silt ~['op'])) !>((~(got by seat-roles.r) ~nec)))
  ==
::
++  test-host-is-admin
  =/  r  (need (ros '{"seats":{"~zod":{"roles":[]},"~nec":{}}}' ~zod))
  ;:  weld
    (expect-eq !>((silt ~[~zod])) !>(admins.r))
    ::  a seat that is not an object, or has no roles, has none
    (expect-eq !>(`(set @t)`~) !>((~(got by seat-roles.r) ~nec)))
  ==
::
++  test-bad-keys-and-values-skipped
  =/  r
    %-  need
    %+  ros
      '''
      {"seats":{"not-a-ship":{"roles":["admin"]},
      "~nec":{"roles":["a",1,null]}},"admins":[2,"a"]}
      '''
    ~zod
  ;:  weld
    (expect-eq !>((silt ~[~nec])) !>(members.r))
    (expect-eq !>((silt ~[~nec])) !>(admins.r))
    (expect-eq !>(`(set @t)`(silt ~['a'])) !>((~(got by seat-roles.r) ~nec)))
  ==
::
++  test-unknown-shapes
  ;:  weld
    (expect-eq !>(~) !>((ros '[]' ~zod)))
    (expect-eq !>(~) !>((ros '{"members":{}}' ~zod)))
    (expect-eq !>(~) !>((ros '{"seats":[]}' ~zod)))
  ==
::
++  test-empty-group
  %+  expect-eq
    !>(`[~ ~ ~])
  !>((ros '{"seats":{}}' ~zod))
--
