# Sending notifications through trunk

Any app on a ship can put a notification on its owner's phone by asking that ship's `%trunk`. Trunk keeps the list of the owner's devices, delivers to Android through UnifiedPush and to iPhones through an APNs gateway, retries what fails, and gives the owner one place to see and switch off what each app sends. Your app never touches a push service, a device token or an Apple key.

This page is for app developers. The wire itself, every body a device receives, is in the README.

## Check that trunk can take it

Read trunk's wire version before your first notice:

```
/~/scry/trunk/version.json        over HTTP, from a client
.^(json %gx /=trunk=/version/json)  in Hoon
```

It answers `{"wire": n}`. Wire 14 or later takes `push-notice-as`, described below. Wire 12 and 13 take only `push-notice`, which has no app name. Anything older, or no answer at all, means no notifications through trunk: an older trunk nacks the poke.

In a Gall agent, a scry of an agent that is not running fails, and a failed scry is not caught by `mule` or `mole`. Ask gall whether trunk runs first, with its own `%gu` care. Gall answers its own cares (`%gu`, `%gd`) only when the path ends in `$`; without it the scry goes to the agent with an empty path and blocks.

```hoon
=/  base  /(scot %p our.bowl)/trunk/(scot %da now.bowl)
?.  .^(? %gu (snoc base %$))  ::  trunk is not running here
  ...
=/  ver  .^(json %gx (weld base /version/json))
```

## Send one

Poke `%trunk` on your own ship, mark `%trunk-action`. From another ship it is refused.

```hoon
::  from a Gall agent
:*  %pass  /notify  %agent  [our.bowl %trunk]  %poke
    %trunk-action
    !>([%push-notice-as 'calendar' 'cal-e1-0' 'Leave now' 'Meeting at 3 in room 2' ~])
==
```

```jsonc
// from a client, over eyre, mark trunk-action
{"push-notice-as": {"app": "calendar", "tag": "cal-e1-0",
                    "title": "Leave now", "body": "Meeting at 3 in room 2",
                    "open": {"event": "e1"}}}           // open may be null or left out
```

```dojo
:trunk &trunk-action [%push-notice-as 'calendar' 'cal-e1-0' 'Leave now' 'Meeting at 3 in room 2' ~]
```

- **app**: your app's name as the owner should see it, at most 40 bytes and no control characters. Trunk also knows which agent sent the poke. A grubbery app, whose pokes all come from `%grubbery`, must name itself here, or the owner sees "grubbery".
- **tag**: groups and replaces notifications on the phone. A new notice with the same tag replaces the old one. Start your tags with something your app owns, such as `cal-`, so they don't collide with another app's.
- **title**: required. A notice with an empty title is refused.
- **body**: the text under the title. It may be empty.
- **open**: any JSON your app wants back when the notice is tapped. Talon does not act on it yet: today a tap opens a calendar notice's event, found by its tag, and simply opens the app for any other.

The four text fields and `open` together may be at most 4 KiB.

`push-notice` is the same without `app`, for wire 12 and 13. Trunk then names the notice after the agent that sent it.

## What happens next

The poke's ack says trunk took the notice, not that a phone showed it. A nack means it was malformed: no title, an unshowable app name, or over 4 KiB.

A notice that was taken can still be held back, without a nack:

- **The owner's switches.** The trunk page (`/apps/trunk`) has a switch for alerts from all apps, and one for each app that has sent any. A new app starts allowed.
- **One every five seconds.** Each app gets at most one push every five seconds. What comes sooner waits, and when the five seconds are up the app gets one push: the notice itself if only one waited, or a summary titled "3 alerts from calendar" that lists their titles, with the tag `batch-<app>`. So send each reminder once, as it falls due, rather than in a burst.
- **Thirty an hour.** No app gets more than 30 pushes an hour. Past that, its notices are dropped until the hour is up.
- **Devices.** Only devices whose app said it understands notices get one. An older app would show it as a chat message.

Each of these leaves a line in trunk's log on the page, such as "notice from calendar: not pushed, this app is switched off". An agent can read the same log, and each app's counts, from the owner-only scry `/~/scry/trunk/debug.json`, under `log` and `senders`.

## What the owner sees

On Android, Talon shows the title and body as a notification on its channel for reminders from the ship. On an iPhone it is a standard alert from Talon. Trunk sends your app's name with every notice (`"app"` in the push), so the app on the phone can say where it came from. Notices with the same tag replace each other on both.

Notices are for things the owner would want to know with the phone in their pocket: a reminder, a time to leave, a mail from someone who matters. They are not for activity feeds or progress. The owner can switch your app off with one tap, so earn the place.
