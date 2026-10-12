::  trunk-jwt: the HS256 tokens Galène accepts. Each pinned token was
::  checked outside Hoon (Python's hmac and base64, 2026-10-12): the
::  signature verifies with the key, and the header and claims decode
::  to the JSON below. lib/trunk-jwt.hoon's notes say why a byte-order
::  slip would give a token that looks right and fails every check.
::
/+  *test, trunk-jwt
|%
::  base64url of 'secret-key-for-trunk-tests', as Galène's "k"
++  key  'c2VjcmV0LWtleS1mb3ItdHJ1bmstdGVzdHM'
++  aud  'http://h:8444/group/talon/zod-x/'
::  {"alg":"HS256","typ":"JWT"}
++  hed  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
++  tok
  |=  [pay=(list @t) sig=@t]
  (rap 3 (welp [hed '.' pay] ~['.' sig]))
::
::  {"sub":"~zod","permissions":["present","message"],
::   "aud":["http://h:8444/group/talon/zod-x/"],
::   "exp":1700000600,"iat":1700000000}
++  test-speaker
  %+  expect-eq
    !>  %+  tok
          :~  'eyJzdWIiOiJ-em9kIiwicGVybWlzc2lvbnMiOlsicHJlc2VudCIsIm1l'
              'c3NhZ2UiXSwiYXVkIjpbImh0dHA6Ly9oOjg0NDQvZ3JvdXAvdGFsb24v'
              'em9kLXgvIl0sImV4cCI6MTcwMDAwMDYwMCwiaWF0IjoxNzAwMDAwMDAwfQ'
          ==
        'AFk90mzDKxBBgr0naGmYeo6qR3rl1f_VuCkGUbZ4HwA'
  !>  %:  mint:trunk-jwt  key  '~zod'  aud
        1.700.000.000  1.700.000.600  speaker:trunk-jwt
      ==
::
::  a guest listener: an empty permissions list, not a missing one
::  {"sub":"guest-0123456789abcdef01234567","permissions":[],
::   "aud":[...],"exp":1700000600,"iat":1700000000}
++  test-listener
  %+  expect-eq
    !>  %+  tok
          :~  'eyJzdWIiOiJndWVzdC0wMTIzNDU2Nzg5YWJjZGVmMDEyMzQ1NjciLCJw'
              'ZXJtaXNzaW9ucyI6W10sImF1ZCI6WyJodHRwOi8vaDo4NDQ0L2dyb3Vw'
              'L3RhbG9uL3pvZC14LyJdLCJleHAiOjE3MDAwMDA2MDAsImlhdCI6MTcw'
              'MDAwMDAwMH0'
          ==
        'QkK2344L4wqQ1J-MIlKzesbZKnZCcSUnoUOOYDLCYXA'
  !>  %:  mint:trunk-jwt  key  'guest-0123456789abcdef01234567'  aud
        1.700.000.000  1.700.000.600  listener:trunk-jwt
      ==
::
++  test-unix-secs
  ;:  weld
    (expect-eq !>(0) !>((unix-secs:trunk-jwt ~1970.1.1)))
    %+  expect-eq  !>(1.700.000.000)
    !>((unix-secs:trunk-jwt ~2023.11.14..22.13.20))
    ::  whole seconds: a fraction is dropped
    %+  expect-eq  !>(1.700.000.000)
    !>((unix-secs:trunk-jwt (add ~2023.11.14..22.13.20 (div ~s1 2))))
  ==
--
