::  trunk-push: gen/test-push.hoon as a unit suite, so hoon-test-kit
::  runs it offline and on the test desk. The generator stays the
::  check of record (+trunk!test-push on a ship). It covers
::  lib/trunk-push.hoon and the push bodies in
::  lib/trunk-json.hoon. A failure prints the cases
::  the generator names.
::
/+  *test
/=  gen  /gen/test-push
|%
++  test-push
  (expect-eq !>(%ok) !>(+:(+.gen ~)))
--
