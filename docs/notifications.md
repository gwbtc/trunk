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

- **app**: your app's name as the owner should see it, at most 40 bytes and no control characters. Trunk also knows which agent sent the poke. A grubbery app, whose pokes all come from `%grubbery`, must name itself here, or the owner sees "grubbery". One agent may use up to 16 names. A notice under a 17th is refused.
- **tag**: groups and replaces notifications on the phone. A new notice with the same tag replaces the old one. Start your tags with something your app owns, such as `cal-`, so they don't collide with another app's.
- **title**: the notice's heading. If it is empty, trunk uses your app's name, since a phone drops a notice with no title.
- **body**: the text under the title. It may be empty.
- **open**: any JSON your app wants back when the notice is tapped. Talon does not act on it yet: today a tap opens a calendar notice's event, found by its tag, and simply opens the app for any other.

The four text fields and `open` together may be at most 4 KiB.

`push-notice` is the same without `app`, for wire 12 and 13. Trunk then names the notice after the agent that sent it.

## Grubbery apps

Every grubbery app's poke reaches trunk from the `%grubbery` agent, so trunk cannot tell grubbery apps apart by who sent the poke. With plain `push-notice`, they all count as one app, "grubbery". They share one switch on the trunk page, one five-second gap and one hourly limit. Two apps' notices that arrive within five seconds are merged into one summary, which loses each notice's own tag.

So a grubbery app that sends notices must:

- Send `push-notice-as` with its own name in `app` when trunk answers wire 14 or later.
- Fall back to plain `push-notice` when `push-notice-as` nacks. Grubbery's kernel checks every poke to trunk against its own copy of trunk's notice actions, the marc at `/code/mar/clay/trunk/trunk-action.hoon`. A kernel whose marc predates wire 14 refuses `push-notice-as`, and the plain poke still gets through.
- Send only `push-notice` to a trunk on wire 12 or 13.

The calendar does all three from its version 30.

A grubbery app can also host calls for its own users with the same naming scheme (wire 18). See "Grubbery apps" in `docs/guest-seats.md`. Its kernel marc must then type those actions too, and goes on a ship only after trunk 18 is there.

## What happens next

The poke's ack says trunk took the notice, not that a phone showed it. A nack means it was malformed (an unshowable app name, or over 4 KiB), or that your agent has used up its 16 names. It can also mean trunk's list of 128 apps is full of apps the owner has set up, with none idle to forget.

A notice that was taken can still be held back, without a nack:

- **The owner's switches.** The trunk page (`/apps/trunk`) has a switch for alerts from all apps, and one for each app that has sent any. A new app starts allowed.
- **One every five seconds.** Each app gets at most one push every five seconds. What comes sooner waits, and when the five seconds are up the app gets one push: the notice itself if only one waited, or a summary titled "3 alerts from calendar". The summary lists the first five titles, each cut to 80 characters, and counts the rest. Its tag is `batch-` and the sender's id: `batch-<agent>`, or `batch-<agent>/<app>` for a named app, such as `batch-grubbery/calendar`. So send each reminder once, as it falls due, rather than in a burst.
- **An hourly limit.** An app gets 30 pushes an hour unless the owner sets another limit for it on the trunk page, from a few up to 720, or none. Past it, the app's notices are dropped until the hour is up. A chat app the owner trusts can be given more; your app cannot raise its own.
- **Devices.** Only devices whose app said it understands notices get one. An older app would show it as a chat message.

Each of these leaves a line in trunk's log on the page, such as "notice from calendar: not pushed, this app is switched off". An agent can read the same log, and each app's counts, from the owner-only scry `/~/scry/trunk/debug.json`, under `log` and `senders`.

## What these limits are not

They keep a careless or buggy app from flooding the owner's phone. They are not a wall against a hostile one. Gall lets an agent name any origin for a poke it sends, so an agent can pose as another app or as the owner, and any web page the ship serves can post as the owner. An app the owner doesn't trust should not be installed: on Urbit it can already do anything as the ship.

## What the owner sees

On Android, Talon shows the title and body as a notification on its channel for reminders from the ship. On an iPhone it is a standard alert from Talon. Trunk sends your app's name with every notice (`"app"` in the push), and the agent it came through when that is a different name (`"via"`), so the app on the phone can say where it came from. Notices with the same tag replace each other on both.

Notices are for things the owner would want to know with the phone in their pocket: a reminder, a time to leave, a mail from someone who matters. They are not for activity feeds or progress. The owner can switch your app off with one tap, so earn the place.
