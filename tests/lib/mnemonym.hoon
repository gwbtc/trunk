::  mnemonym: gen/test-mnemonym.hoon as a unit suite, so hoon-test-kit
::  runs it offline and on the test desk. The generator stays the
::  check of record (+trunk!test-mnemonym on a ship). It covers
::  lib/mnemonym.hoon. A failure prints the cases
::  the generator names.
::
/+  *test
/=  gen  /gen/test-mnemonym
|%
++  test-mnemonym
  (expect-eq !>(%ok) !>(+:(+.gen ~)))
--
