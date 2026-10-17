::  trunk-guest: gen/test-guest.hoon as a unit suite, so hoon-test-kit
::  runs it offline and on the test desk. The generator stays the
::  check of record (+trunk!test-guest on a ship). It covers
::  lib/trunk-guest.hoon. A failure prints the cases
::  the generator names.
::
/+  *test
/=  gen  /gen/test-guest
|%
++  test-guest
  (expect-eq !>(%ok) !>(+:(+.gen ~)))
--
