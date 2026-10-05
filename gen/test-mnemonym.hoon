::  +test-mnemonym: the upstream 128-bit vectors (the ones Talon's
::  MnemonymVectorsTest pins) and three comets whose names are known.
::  Answers %ok, or each case that came out wrong.
::    +trunk!test-mnemonym
/+  mnemonym
:-  %say
|=  *
:-  %noun
=/  vec=(list [@ux @t])
  :~  [0x0 '..abducts']
      :-  0x7f7f.7f7f.7f7f.7f7f.7f7f.7f7f.7f7f.7f7f
      '..escapes.upsets.retook.withdrew.untamed.protest.verbose.unfit.escapes.upsets.retook.withheld'
      :-  0x8080.8080.8080.8080.8080.8080.8080.8080
      '..event.accede.auteurs.ablaze.admire.confers.abridge.allege.event.accede.auteurs.abet'
      :-  0xffff.ffff.ffff.ffff.ffff.ffff.ffff.ffff
      '..yourselves.yourselves.yourselves.yourselves.yourselves.yourselves.yourselves.yourselves.yourselves.yourselves.yourselves.withdraw'
      :-  0x9e88.5d95.2ad3.62ca.eb4e.fe34.a8e9.1bd2
      '..machine.congeal.discount.delays.cassette.discounts.ordeal.retook.caprice.coquette.convicts.mistake'
      :-  0xc0ba.5a8e.9141.1121.0f2b.d131.f3d5.e08d
      '..pulsate.remade.misspells.award.aloft.harpoons.concede.ensoul.brunettes.machines.enraged.askew'
      :-  0x23db.8160.a31d.3e0d.ca36.88ed.941a.dbf3
      '..baguette.resort.depart.conversed.remold.address.beguile.relaxed.unclaimed.massage.platoon.taboo'
      :-  0xf30f.8c1d.a665.478f.49b0.01d9.4c5f.c452
      '..unlocks.entrance.adjoin.decant.defunct.record.befalls.abate.reproach.digress.unhurt.mistook'
  ==
::  Encoded independently (Python, from Talon's word and syllable
::  tables, starting at the @p's syllables), so the @p-to-bytes seam
::  is checked too. Names minted before upstream de-duplicated its
::  word list read differently: ~foppel was .remakes...informs.
=/  com=(list [@p ? @t])
  :~  [~foppel-fitdyn-doznux-fithut--somdur-famdev-forpet-daplyd & '.renewed...involve']
      [~hadmyn-foprup-lagmur-togned--ranfep-lodryd-ponnym-daplyd & '.humane...intense']
      [~larwyx-monder-winpel-timwyd--timben-botfun-harpub-daplyd | '..retrieves...invests']
  ==
=/  bad=(list *)
  ;:  weld
    %+  murn  vec
    |=  [v=@ux want=@t]
    ^-  (unit *)
    =/  got  (encode:mnemonym v |)
    ?:(=(want got) ~ `[v want got])
  ::
    %+  murn  com
    |=  [who=@p gw=? want=@t]
    ^-  (unit *)
    =/  got  (short:mnemonym who gw)
    ?:(=(`want got) ~ `[who want got])
  ::
    ::  only a comet has a name
    %+  murn  `(list @p)`~[~zod ~marzod ~ricsul-bilwyt ~doznec-dozzod-dozzod]
    |=  who=@p
    ^-  (unit *)
    ?~((name:mnemonym who |) ~ `[who %named])
  ==
?~(bad %ok [%failed bad])
