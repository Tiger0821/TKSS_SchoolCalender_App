# Timetable

The userscript's timetable dock as an iPhone app with widgets, plus today's
date, a clock, a countdown to Taiwan's next national holiday, and the weather
outside as a pixel-art sky behind the page. One build serves the whole year
group: the first time it opens it asks who you are and which classes are
yours, and lays out your own timetable. Built with
the iOS 27 SDK (Xcode 27); runs on iOS 26 and later. There is an Apple Watch
app with it, and a Mac app with the same page in a window and the class that
is on in the menu bar: see [On the Mac](#on-the-mac).

The userscript it comes from:
[ManageBac Reimagined](https://github.com/Tiger0821/ManageBac-Reimagined).

## Download

**[Download the code (ZIP)](https://github.com/Tiger0821/TKSS_SchoolCalender_App/archive/refs/heads/main.zip)**
— the iPhone, the Apple Watch and the Mac together. The three share most of
their code, so none of them builds from its own folder alone.

There is no app here to install as it is: an app that opens on someone
else's iPhone, Apple Watch or Mac has to be signed through Apple's paid
Developer Program, and these are signed with a free Apple ID. So each person
builds their own copy, on a Mac with Xcode 27:

1. Unzip the download and open `ManageBacTimetable.xcodeproj`.
2. At the top of Xcode's window pick what to build and where:
   **TimeTableIPHONE** and your iPhone, **TimeTableWATCH** and your Apple
   Watch, or **TimeTableMAC** and My Mac.
3. Sign in with your Apple ID (Xcode → Settings → Accounts), and change the
   bundle id and the app group to your own, as [Run it](#run-it) says.
4. Press Run. The Mac app is built straight into Applications, so it is
   still there after it is quit, in Launchpad and Spotlight.

On a free Apple ID each copy opens for seven days; build it again after that.

## Setup

The first time the app is opened it asks a few questions, one to a page:

1. **Your name.** It goes under the clock.
2. **Your form** — 11A or 11B. Each has its own timetable.
3. **Your classes.** The form's classes are sorted into sets that are on at
   the same time, so nobody takes two from one set: Maths (MAA HL, MAA SL,
   MAI HL), the two TOK groups, and so on. Each set is one page and one tap.
   Where a set isn't strictly one-or-the-other — in 11A, Eng B-1 and Eng Lit
   can be taken together, but neither with Eng A-2 — the page lets you pick
   more than one, and picking a class drops any that clash with it.
4. **SL revision**, if any of the classes you picked has a revision class.
5. **Your clubs.** The timetable only says "Service Clubs" and "Academic
   Clubs"; put in what yours are called, with a room if you like, and a
   different club for Week 2 if yours alternate. Or leave them blank. The
   teacher is picked from a menu of the teachers the school's timetable has
   in that slot for your form — that week's, or both weeks' for a club that
   is the same in each — or typed after **Custom…** for someone not on it.
   The school publishes who runs the clubs but not what they are called.

Guidance, Weekly Alignment and the clubs are on everyone's timetable and are
never asked about. Any period before 16:05 with none of your classes in it is
shown as IB Core.

Tap your name under the clock to go through it again, already filled in, and
change anything. Changing form keeps the choices the two forms share.

None of the sets are written into the app. `Timetable.catalog(for:)` works
them out from the rows: two classes clash when they are on at the same time
on some day, a class that clashes with nothing is everyone's, and the rest
fall into sets of classes linked by clashes. So when the school changes the
options, the questions follow.

## The app

- Your name and form, then today's date and the time to the second.
- The class running now (or the next one), with the minutes left.
- The next national holiday: whole days while it is more than a day away, then
  hours, minutes and seconds. The three after it are listed underneath.
- A picker for any of the ten days in the cycle, and that day's timetable.
  Tap a class in it for its homework.
- Your homework from ManageBac, soonest first — see [Homework](#homework).
- The weather outside, painted behind it all as pixel art — see
  [Weather](#weather).

The five boxes — class, holiday, day picker, timetable, homework — can be put in any
order: touch and hold one until it lifts, drag it, and the others slide out of
its way. Hold it near the top or bottom of the screen and the page scrolls
under it, so a box can travel further than one screen. The order is remembered
(`boxOrder` in the app's defaults). A swipe still scrolls the page and a tap
still picks a day; only a held finger lifts a box.

Nothing else is on the page. **Settings** is a page of its own off the
right-hand edge: swipe in from that edge, or tap the gear beside the clock,
and it slides across; swipe back from the left edge, or tap the arrow, and it
goes. It has the Lock Screen switch, your form and classes, a way to put the
boxes back as they came, and where the timetable, the holidays and the
weather come from.

## Widgets

- **Now & Next** — small, medium, and three Lock Screen sizes (inline,
  circular, rectangular). The class running now with a live countdown and
  progress bar, and what's next. Before school, after it and at weekends it
  shows the first class of the next school day instead.
- **Today** — large. The whole day as the dock lays it out: finished blocks
  greyed back, and the current one filling from left to right across its row
  as it runs, with its countdown.
- **Holiday Countdown** — small, medium, and the three Lock Screen sizes. Days
  to the next national holiday, switching to a live hours:minutes:seconds
  countdown once it is under a day away. The medium size adds today's date and
  a running clock.

Add them by touching and holding the Home Screen or Lock Screen → Edit →
Add Widget → search "Timetable".

The timetable is built into the app, so the widgets need no network and no
account. Whose timetable to show they read from the profile setup saves, which
the app and the widgets share through an app group; until setup has been done
they say to open the app. Each widget lays out a timeline with an entry at every bell through
the next two school days; the countdowns in between are drawn by the system.

## On the Lock Screen

Switch on **Show the day's classes** in Settings and the school day goes up
as a Live Activity: on the Lock Screen, the class you're in, the time left in
it, a bar filling as it runs down, and what's next; in the Dynamic Island,
the class's name and the minutes left of it ("CS 14 min"). Before the first
bell it shows the first class and, for the last two hours, counts down to it.
It changes with every bell by itself.

The island counts to the end of the class, so through a double period it is
one countdown; the Lock Screen counts to the end of the period. In a short
break the Lock Screen names the class to come and counts down to it, to the
second; the island names it and gives the time it starts.

On a paired Apple Watch the Live Activity shows in the Smart Stack as the
day's name and a countdown of how long school has left, and no more. (The
phone's panels can't be used there, and nor can a bar that fills as the day
goes by: on the watch a bar run by the clock is drawn finished whatever the
time is, so the masks hide nothing and a bar for the day was full at half
past two. A countdown is text, and is the one thing that moves.) What is on
now and what is next is the watch app's own widget — see "On the Apple
Watch" below.

The watch is sent the drawing when the day's Live Activity starts, so a new
build shows there from the next start — turn the Lock Screen switch off and
on in Settings to see it sooner.

- **It goes up at 06:00** on school days (the time can be changed). The app
  books the next school morning with the system each time it is opened, and
  the system starts it at that time without the app running. Opening the app
  once between school days keeps that going.
- **Without opening the app at all:** the app offers Shortcuts a **Start
  Classes** action. In Shortcuts: Automation › New › Time of Day › pick the
  time and days › Run Immediately › Start Classes.
- **How long it stays:** iOS takes a Live Activity out of the Dynamic Island
  after 8 hours and off the Lock Screen after 12. One that goes up at 06:00 is
  in the island until 14:00 and on the Lock Screen until 18:00.
- **Swiping it away** clears it until the app is next opened. The switch is
  how to turn it off.
- With the screen dimmed, iOS shows a countdown's minutes and leaves the
  seconds as dashes.

### How it changes by itself

A Live Activity can't be given a timeline the way a widget can: what it shows
only changes when the app updates it or a server pushes to it, and during the
school day there is neither. So the whole day goes in when it starts, and the
view is every block's panel stacked up, all but one of them hidden by the
clock — by a progress bar set to run out at the block's first second, which
is one of the two things the system will animate by itself. `TimeSwitch` in
`Widget/ClassLiveActivity.swift` is that; the comments there say what it took
to make it hold.

There are two ways of hiding, and each is used where what it costs matters
least. The empty part of a bar is not clear: the system draws a faint track
there, a quarter solid, so a bar used plainly as a mask lets a ghost of the
hidden panel through.

- On the Lock Screen each panel has two black bars over it (`Shutter`), one
  that lifts when its block begins and one that falls when the next does.
  They are laid on as hard light, under which the full, black part of a bar
  blacks the panel out and the mid-grey track leaves it as it was; and the
  panels are added together, so the blacked-out ones add nothing. Each panel
  is drawn apart once. That is for the frame rate: the first way of doing
  this put every panel behind four masks, and all the later panels behind
  those again, and scrolling the Lock Screen's notifications under some
  seventy masks fell from 120 frames a second to 60.
- In the island each panel is behind one mask (`Curtain`): the bar in white
  on black, its contrast raised until the track is black too, and its
  brightness used as the mask. A bar that is only a mask is a third of the
  weight of one that is seen, in the file below, and the island's panels are
  small enough for a mask each to cost nothing worth counting. The island's
  two ends are also what a Mac shows in its menu bar when the phone is near,
  and the Mac does not draw a bar quite as the phone does: look there too
  after changing this.

The limit to design within: the system saves a Live Activity's drawing to a
file and silently shows nothing if it is over 2,000,000 bytes (1,953 KB), and
what fills it is countdowns (about 40 KB each) and bars. iOS 27 saves the
same drawing about an eighth larger than iOS 26, so it is the one to measure
on. For 11B's ten days, measured on iOS 27.0 on 22 Oct 2026:

| | iOS 27.0 |
|---|---|
| lightest day (13 blocks) | 1,469 KB |
| fullest day (16 blocks) | 1,790 KB |

That is with the short breaks counting down on the Lock Screen, which added
some 23 KB a break (the fullest day has five), and with the shutters and
curtains as above, which between them weigh a little less than the masks
did. It is also with each subject's own few letters in the island. Chem,
Bio, Eng A-2 and others had all been "Club", so two of them in a row were
one stage of the label; telling them apart put a stage back on four of the
ten days, some 5 to 14 KB each. iOS 26.5 has not been weighed since
either; before, on 6 Oct, the same two days were 1,223 and 1,457 KB there.

A day of more than sixteen blocks drops the island's minutes, which is some
300 KB lighter (`affordsMinutes`). Anything added to the Live Activity should be weighed the
same way before it is trusted: the saved file is the `.activity-archive` under
the simulator's `Containers/Data/PluginKitPlugin/…/SystemData/com.apple.chrono/activities`.

The minutes in the island are a countdown with its seconds clipped off
(`MinutesLeft`). A text formatted to read "32 min" is not kept up to date in
a Live Activity; a countdown is.

To try it without waiting for a bell, run a debug build with `LIVE_TEST` set
in the scheme's environment: a number starts a made-up day with blocks that
many seconds long; `day` starts the next real school day now; `size:3` starts
the day three days from now as it would be booked, to weigh it.

## On the Apple Watch

The phone app carries a watch app with it (`Watch/`, and its widget in
`WatchWidget/`), and the watch app stands on its own as well: it is marked as
running independently of the phone's, and has a setup of its own, so it shows
the day on a watch whose phone has never had Timetable opened.

- **Setup** on the wrist (`WatchSetupView.swift`) is the phone's with what
  wants a keyboard taken out: your form, each set of classes that are on at
  the same time, and any SL revision. It comes up the first time, and again
  from "Change classes" under the day. Your name and what your clubs are
  called are asked only on the phone, and are kept when the classes are
  changed on the watch.
- **With a phone that has been set up too**, the phone hands its profile
  across whenever the app is opened or the classes change, with the time it
  came out of setup. The watch takes it unless its own is the newer, so the
  watch shows whichever was changed last. What is chosen on the watch is not
  handed back to the phone.
- **The app** is the phone's page cut down to what a wrist has room for: each
  class with the time it starts and its room, the breaks between, the class
  that is on outlined with its time left, and the same pixel sky behind. No
  date, no clock, no teachers.
- **The days ahead** are a swipe away: from right to left goes on to the next
  school day, and the other way comes back. A day arriving is felt and seen
  together: a click on the wrist, and at the same moment its name gives a
  start and its rows come in from the side the swipe came from, one behind
  another. There are ten days, which is every
  day of both weeks. Each says at its top which day it is and whether it is
  in the odd week or the even one (the timetable's Week 1 and Week 2). Left
  and come back to, the app is at the day the clock leads to again.
- **The widget** (Smart Stack › Edit › add Timetable) says the class that is
  on with its room and the time it has left, and the class after it with its
  room. The class after is the first to start once the one on now is over,
  so the second half of a double period is not "next". Where that line is
  too long for the tile it is the time the class starts that is left out and
  not its room, and in the last class of the day the line says that it is.
  From two hours before the first bell it says "Good morning" — in
  pixels, like the sky (`PixelText.swift` draws the letters as squares) —
  over the first class, a small countdown to it, and the class after; for the
  last half hour the countdown takes the greeting's line and is the largest
  thing on the tile. Over the same hours, and until the last bell, it tells
  the Smart Stack it is worth bringing to the top, and it says so ahead of
  time for the fortnight coming. It is a widget and not the Live Activity
  because a widget is given a timeline, and so can change at every bell.
- **The tile a watch shows by itself** during the school day is not that
  widget. It is the phone's Live Activity sent across — the day's name and
  how long school has left, as said under "On the Lock Screen" above — and the
  system puts it at the top of the Smart Stack; an app is given no say in
  that. To have the class that is on there instead, add the widget once
  (open the Smart Stack, touch and hold, "+", Timetable) and pin it, and to
  be rid of the other tile turn Timetable off in the Watch app on the phone
  under Smart Stack › Live Activities.

## On the Mac

`Mac/` is a Mac app made from the phone's own parts: the page, setup, the
widgets and the reminders are the phone's, and what the phone does on the
Lock Screen the Mac does in the menu bar. It runs on macOS 26 and later.

- **The window** is the phone's page, its top laid out for a wide window.
  Whose timetable it is is a person on glass in the middle of the header,
  which opens setup. Under the pointer it stretches into a capsule with the
  name and the form, on a spring as Apple's glass moves, the words coming up
  through a blur; out of its far end the gear for Settings comes away as a
  drop of glass of its own, the two pulling apart as water does, and the
  person stays where it was (`PersonButton`). It is quick to open and slow
  to close: a margin round it still counts as over it, and it waits a
  moment after the pointer has gone, so a pointer that overshoots the gear
  finds it still there. Under the pointer each drop swells a little, the
  person's as well as the gear's, the gear turns once, and the trackpad
  gives a tap each time the pointer comes onto either. Beside it the day
  and the weather face each other across the sky, line for line — the date large,
  and the weekday and the clock under it, at the left; the temperature
  large, and the conditions, the high and low and the place under it, at the
  right — with the sun or the moon between them, all in white with a soft
  halo. Scrolled, the boxes come up into the header and it gives way to
  them, as the Weather app's does: the large lines fade and the header
  gathers into one line, the date and the clock at the left and "24°C |
  Drizzle" at the right. The boxes then go on up under it the way the
  Weather app's cards do, not fading but cut off at the top: each one's top
  edge stays just under the header, rounded as it was, and the box grows
  shorter until it is gone (`TucksUnder`). The day's card keeps its title
  at the top of what is left while its lessons slide up beneath it. Under the
  header are the five boxes. While the window is narrow they are one column,
  as on the phone; from 820 points wide they go into two of the same width,
  at first the class, the holiday and the homework on the left and the picker
  and the day on the right, so the gap between them runs down from the person
  in the header. The date and the sky stay where they are and the boxes scroll
  up under them. The boxes can be moved, as on the phone: press and hold one
  and it lifts with a tap on the trackpad and a closed hand for a pointer,
  follows the pointer — into the other column too — while the others slide
  out of its way, and settles into the gap when let go
  (`Mac/MacBoxes.swift`). Where each box is, is kept. The two columns are one
  layout of all five boxes (`BoxColumns`), so a box keeps itself crossing
  from one to the other and glides across. A class in the day's list,
  clicked, shows its homework in a popover. A box is half a window wide, so
  the phone's small print reads small across it: the day picker, the boxes'
  titles ("NOW", "NEXT HOLIDAY", "HOMEWORK") and the day's title ("Today ·
  Friday · Week 2") are larger on the Mac (`Font.boxTitle`, `Font.dayTitle`).
- **Appearance**, in Settings, is the weather sky or Liquid Glass
  (`Mac/MacBackdrop.swift`), picked from two pictures as System Settings
  shows Light and Dark. Under glass the window is see-through, and the
  desktop and the windows behind it shine through; the page takes the Mac's
  own Light or Dark colours, the date and the weather keep the sky's halo of
  light, and the sky's frames stop. Two sliders set the
  glass: **Transparency**, from Solid to Clear, is how much of the window's
  own colour is laid over what is behind; **Blur**, from Sharp to Soft, is
  how blurred it is, its steps made to look even: measured over a
  desktop-like picture, small text over big blocks of colour, at 22 radii,
  each tenth of the slider takes away a tenth of the fine detail and the big
  shapes averaged, up to a radius of 72 (`MacBackdrop.blurRadius`). Measured
  over text alone at first, the curve had the text gone by four fifths of
  the way and the big shapes, most of what a desktop is, changing all at
  once in the last fifth. While either slider is dragged, Settings fades out of
  the way, so the window behind can be seen as it changes, and the slider
  alone stays: a copy of it on a capsule of glass, in a window of its own
  laid exactly over the real one, moving as the drag moves the setting
  while the pointer goes through to the real slider underneath. Let go, and
  Settings comes back. Apple's glass comes only clear or frosted, and fading
  one into the other left a sharp ghost of the desktop under a blurred one,
  so the blur is the system's own behind-window blur, the one under a HUD,
  with its strength set by hand (`BackdropBlur`): AppKit has no strength to
  set, so the radius of the blur filter on its backdrop layer is changed,
  by key path inside the filters the layer has — handed a new set of
  filters, the layer kept them but the screen showed the old blur until
  the changes stopped for a while, so a dragged slider never showed and the
  window opened on the system's own blur for half a minute —
  and the layer takes in what is behind at a finer size the lighter the blur
  is, or the eighth it uses smears a light blur into a grey haze; the blur
  always spreads over at least sixteen of the pixels taken in, as over
  three it showed their blocks, a mosaic that shimmered over a video
  behind. The layer counts what it takes in to a point, not to a pixel, so
  its "whole" was half of a Retina screen, and a light blur turned fine
  lines into stairs of two-pixel blocks; it now takes in at the screen's own
  resolution (`backingScaleFactor`) when the blur is light. The
  blur is set finer than the system's own — high quality, dithered, and
  mixed in linear light as frosted glass mixes it — and the system's colour
  boost after it (half again) is taken off: side by side, the system's own
  left soft blotches in colours that looked daubed on, and this one diffuses
  evenly. At no blur
  there is none at all. The boxes on it are Liquid Glass. Clear Liquid
  Glass over the whole window, for the bend along its edges, was taken out:
  macOS draws glass brighter in the window in front and darker in one
  behind, so with Settings open over the window, the glass being set there
  was only ever seen darker than it would be. The header is on the same glass as the rest: a band of blur and colour of
  its own behind it dimmed the top of the window. With Reduce Transparency
  on, the glass is solid. It is the window itself that is made see-through
  (`SeeThroughWindow`): SwiftUI draws over the window's own background. The
  iPhone has no such choice, since an app there can't show the Home Screen
  through itself.
- **Setup** is the phone's — in the window the first time, and over it after
  that from the person at the top of the window or Settings › Change. The
  Mac keeps a profile of its own, as the watch can: an app group does not
  reach from one device to another, and the free team this is signed with
  has no iCloud to carry it across. So the Mac is set up on its own.
- **The menu bar** says what the Dynamic Island says: the class that is on
  and the minutes left of it ("Econ 14 min"), to the end of a double period; in
  a short break, and before the first bell, the class to come and the time it
  starts; out of school hours, only a mortarboard. Clicked, it opens the Now
  box, with the ways to the window, to Settings, and out. It is the app's own,
  not a Live Activity, and turns over on the minute by a clock the app keeps
  (`MacModel`). A Mac with the iPhone near it also shows the phone's Live
  Activity in its menu bar; the switch in Settings takes this one away if two
  are too many.
- **Closing the window** leaves Timetable running in the menu bar, keeping
  the reminders topped up; Quit is in the panel. **Open at login**, in
  Settings, has it there from the morning on.
- **Settings** is a window of its own, as on any Mac (⌘, or the gear by the
  clock): whose timetable it is, the menu bar, opening at login, the
  reminders, and where everything comes from.
- **Widgets** — Now & Next (small, medium), Today (large) and Holiday
  Countdown (small, medium) — are the phone's, from the same `Widget/` folder
  built again for the Mac. Right-click the desktop › Edit Widgets › search
  "Timetable". The Lock Screen sizes and the Live Activity are left out of the
  Mac's build (`#if os(iOS)`), since a Mac has neither.
- **Reminders** are laid down on the Mac as on the phone, some four school
  days ahead, and topped up each new day the app is running and each time the
  Mac wakes. They are the Mac's own: where the phone or the watch is
  reminding as well, each of them says so.
- **The sky** is the same. The Mac is asked for its location the older way,
  with a `CLLocationManager`, since there is no `CLServiceSession` on macOS.

To run it, pick the **TimeTableMAC** scheme and My Mac, and press Run. It is
built straight into `/Applications` (`DEPLOYMENT_LOCATION`, with `DSTROOT` set
to `/Applications`), and run from there in its Release form: built into
Xcode's own folder, the app was gone from sight once it was quit, and it is
meant to be left running. Building it needs an account that can add apps to
Applications. It has
the phone's bundle id (`com.tigercho.ManageBacTimetable`, and `.Widget` for
its widget) — an iPhone app and a Mac app may share one — and the same app
group, so the App IDs the team already has cover it; Xcode makes Mac profiles
for them the first time, and registers the Mac. Those last seven days on the
free team, as the phone's do, and the app has to be built again after that.

## Homework

Each class's homework comes from the school's ManageBac
(kueishan.managebac.com). Tap or click a class in the day's list and what is
set for it shows: each task due from today on, with when it is due (in red by
the end of tomorrow), what kind it is ("Quiz", "Homework", 個人口試 IO), the
first few lines of what it says, and an arrow that opens it in ManageBac. A
class with something due in the week ahead has a small count at the end of its
row. The **Homework** box lists the six due soonest across every class.

- **Signing in** is on ManageBac's own page, in a sheet inside the app
  (`ManageBacSignIn`): the password goes to ManageBac and the app never sees
  it. Tick "Remember me for 30 days" on that page, or the session ends when
  the app quits; after the thirty days the box says "Signed out" and asks
  again. The iPhone and the Mac are each signed in on their own.
- **Reading** is done from inside a ManageBac page, as the userscript's "Due
  today" does it: the calendar page is opened out of sight with the session,
  and from there the app fetches `/student/events.json` (every task, its due
  time, its kind, and a link that names its class), reads the class names
  from the page's sidebar, and takes the address of the "Subscribe to
  Calendar" feed for the tasks' descriptions. Asked from outside the page,
  with copies of the session's cookies, ManageBac sent every request to its
  sign-in page. It looks again every ten minutes while the app is open, and
  keeps what it read for next time.
- **The calendar feed on its own** is not enough: it has each task's title,
  due time and description, but not which class it is for. A third of one
  student's tasks were due at the very minute one of their lessons began;
  the rest could have been anyone's.
- **Matching** ManageBac's classes ("Economics", "English LIterature", "HS G11
  Guidance") to the timetable's ("DP Econ", "Eng Lit", the two Guidance
  slots) goes by the subject in the name (`Homework.describes`). A revision
  class has the homework of the class it is for. There is nothing to set:
  every one of the thirteen classes of the first student to sign in found
  its own.

The school's address is `ManageBac.school` in `Page/ManageBac.swift`.

## Reminders

Fifteen minutes and five minutes before each class starts, a notification
says what it is and where ("CS in 5 min · 5F HS3"). A double period is
announced once. The switch is in Settings.

Once Timetable has been opened on the watch, the watch sends them itself, so
they tap the wrist whatever the phone is doing, and the phone stands down so
nothing is said twice. Without the watch app the phone sends them, and iOS
passes them to the watch while the phone is locked. They are laid down some
four school days ahead (the system keeps 64 for an app) and renewed each time
either app is opened.

## Run it

Open `ManageBacTimetable.xcodeproj`, pick a scheme — **TimeTableIPHONE**
for the iPhone, **TimeTableWATCH** for the Apple Watch, **TimeTableMAC** for
the Mac — and a simulator or My Mac, and press Run. Those three are the only
schemes: each builds its app with its widgets inside, and Xcode is told not
to make one of its own for every target. The iPhone app doesn't offer "My Mac
(Designed for iPad)", as the Mac has an app of its own.

On your own iPhone or watch: Xcode → Settings → Accounts, sign in with your
Apple ID, then select the project → each target → Signing & Capabilities →
Team. Every target has the App Groups capability, which Xcode registers for
your team the first time it signs them.

Building it under a different Apple ID — a classmate building their own copy —
means changing the bundle id `com.tigercho.ManageBacTimetable` to something of
their own, with the ids under it (`.Widget`, `.watchkitapp` and
`.watchkitapp.Widget`) and the watch's companion app id, which is the phone's
(`WKCompanionAppBundleIdentifier` in the watch targets' build settings). The
app group changes with it: in `Profile.group` in `Shared/Profile.swift` and in
every target's `.entitlements` file — one each in `App/`, `Widget/`, `Watch/`
and `WatchWidget/`, and two in `Mac/`. The group id has to start with
`group.` and be the same in all of them, or the widgets won't see the
profile.

## When the school changes the timetable

```bash
python3 Tools/update_timetable.py
```

That reads the school's published Prime Timetable and rewrites
`Shared/TimetableData.swift` with every lesson of each form, one row each:
subject, day, start, end, staff, room. Build again and everyone's timetable,
and the questions setup asks, follow the new rows. To add a form, add its name
to `FORMS` at the top of the script.

Cards the school has left off the grid (they have no day) are not lessons and
are left out.

## Keeping it in step with the userscript

The timetable logic in `Shared/Timetable.swift` is a port of the userscript's
TIMETABLE section, and for the same classes lays out the same ten days. The
differences are deliberate:

- The userscript has one person's classes written into it; here they come
  from the profile, so `TT_MINE` and `TT_CLUBS` have no constants to match.
- The timetable's "G: Agency [EE, CAS, CC]" block is shown as "Guidance" (see
  `Timetable.displayName`).
- The rows are read from the school's feed by the script above. The
  userscript's `TT_RAW` counts cards with no day as Week 1 Monday, which puts
  two lessons on that day that the published timetable doesn't have (a Bus Man
  at 16:15 and a Chinese revision at 15:40); `TT_SKIP` was there to hide one
  of them. Neither is in the rows here, so there is nothing to skip.

| Userscript   | Here                                            |
|--------------|-------------------------------------------------|
| `TT_RAW`     | `Shared/TimetableData.swift`, from the script   |
| `TT_MINE`    | `Profile.subjects`, picked in setup             |
| `TT_SKIP`    | not needed                                      |
| `TT_CLUBS`   | `Profile.clubs`, typed in setup                 |
| `TT_ANCHOR`  | `Timetable.anchor`                              |
| `TT_SOURCE`  | `Timetable.source`                              |

Subject colours are in `Shared/SubjectStyle.swift`: a tone to each subject
(`Tone`), with one value for dark backgrounds and a deeper one for light, and
picked so that the classes one person has together are not neighbours on the
colour wheel. The Lock Screen's day and the island are black whatever the
phone is set to, and take the dark values (`onDark`).

## Holidays

`Shared/Holidays.swift` lists Taiwan's national holidays from the government
office calendars for 2026 (民國115年) and 2027 (116年), from National Day 2026
through New Year's Day 2028, with the weekday given off when one lands on a
weekend. The lunar festivals move every year, so add the 2028 dates when that
calendar is published — after the last entry the countdown simply disappears.

The countdown runs to midnight at the start of the holiday itself (not the
substitute day off), in the phone's own time zone.

A weekday off for a holiday has no classes on it (`Holidays.off(on:)`, which
`Timetable.day(of:)` asks): the widgets, the watch, the class reminders and
the Lock Screen's day all pass over it to the next school day, and say "No
class today" where they have room to. On the page the card at the top says
it, and the evening before, "No class tomorrow"; the day's own list has a
notice in place of its classes, with a **Show** button that brings the usual
ones up under it. On the day off itself the page stays on today, and **Today**
goes back to it, where on a school day it turns over to the next one at the
last bell.

The picker's ten days are days of the cycle and carry no dates, so to find
the one a holiday takes out, each is taken for the date it falls on this week
or next (`Timetable.fortnight`). That day is in red.

## Weather

The page's background is the sky as it is outside, the way the Weather app
does it, drawn as pixel art: a sun with rays or a crescent moon, stars,
clouds drifting with the wind, rain that leans with it, snow, fog, lightning,
and a line of hills along the bottom. Under the date is a strip of open sky
for it to show in, with the temperature, the conditions, the place and the
day's high and low on glass in its corner.

- The weather is from [Open-Meteo](https://open-meteo.com/), which needs no
  key and no account. It is looked up when the app opens and every ten
  minutes while it stays open, and the last reading is kept for three hours so
  the sky is there at once next time.
- It is for where the phone is, so the app asks to use the location while it
  is open. The position is rounded to about a kilometre before it is sent.
  Refuse, or be offline, and there is no weather: the page keeps its plain
  background and nothing else changes.
- Sunrise and sunset come with the weather, so the sky turns from day through
  twilight to night on its own between readings.
- Over a sky the page is always in its dark colours, since every sky is dark
  at the top where the date is.
- With Reduce Motion on, the sky is painted once and left still. On the Mac
  it goes on moving under Mission Control and App Exposé, at its full
  fifteen frames a second (they make the Dock the app in use, and behind
  another app the sky goes at four), but left there three minutes it is
  held still, and goes on from where it stopped as soon
  as the window starts to grow back: nothing tells a window they are up, so
  the sky looks four times a second for the Dock's window over it, and
  twenty while it is held.
- The clouds are heaped cumulus, nine shapes of them, lit from the upper left
  in four tones and stippled between; they ride at three depths, the far ones
  small, a little hazy and slow, the near ones big and quicker, all of them
  solid, so they pass each other on the wind. A cloud moves half a pixel at a time, which keeps
  it pixel art and still lets it glide.
- Nothing is an image file. `PixelSky.swift` paints each frame into a small
  grid of pixels, fifteen times a second, and scales it up unsmoothed. On
  the phone and the Mac each frame goes straight onto a layer of its own
  (`SkyLayer`), out of SwiftUI's sight: handed to SwiftUI, every frame had
  the whole window worked out again, and the Mac app sat at a third of a
  core where it now sits at about two per cent.

To see a sky without waiting for the weather, launch with the argument
`-demoWeather` and a sky and a time of day — `-demoWeather thunderstorm-night`,
say. The skies are `clear`, `mostlyClear`, `partlyCloudy`, `overcast`, `fog`,
`drizzle`, `rain`, `heavyRain`, `snow` and `thunderstorm`; the times are `day`,
`twilight` and `night`. In Xcode that is Product → Scheme → Edit Scheme → Run →
Arguments.

The widgets do not show the weather and still use no network.

## Layout

- `Shared/` — the timetable and its styling; compiled into every target.
  `TimetableData.swift` is the rows for each form, `Profile.swift` is whose
  timetable it is, and `Timetable.swift` lays one person's fortnight out.
  `ClassActivity.swift` is a day as the Live Activity carries it.
- `App/` — the phone app: the page, laid out in one column, with the settings
  off its edge. `ReorderableStack.swift` is the hold-and-drag reordering, edge scrolling
  included. `SettingsPanel.swift` is the settings page and the edge swipe that
  brings it in. `ClassActivityManager.swift` starts and books the Live
  Activity, `LockScreenSettings.swift` is its switch, and
  `ClassActivityIntent.swift` is the Shortcuts action.
- `Page/` — what the phone and the Mac both put on the page, in
  `PageParts.swift`: date and clock, the sky strip, Now card, holiday card,
  the ten-day picker and the day's card. `SetupView.swift` is setup, for both.
  `ManageBac.swift` signs in to ManageBac and reads the homework, and
  `HomeworkViews.swift` shows it: a class's list, the Homework box, the
  sign-in sheet and the rows in Settings.
- `Tools/` — `update_timetable.py`, which rebuilds the rows from the school's
  published timetable, and `draw_icon.swift`, which draws the app's icon (a
  pixel owl in a red bow tie, on white, shaded and lifted in layers) into the
  three asset catalogues.
- `Widget/` — the widget extension: the widgets, and in
  `ClassLiveActivity.swift` the Live Activity's views.
- `Common/` — what the apps (phone, watch and Mac) share but the widgets do
  not: `Weather.swift` and `PixelSky.swift`, `ClassReminders.swift`,
  `Picking.swift`, which is what a pick in setup does to the profile on
  either, and `DeviceLink.swift`, which carries the profile from phone to
  watch.
- `Watch/` and `WatchWidget/` — the watch app and its Smart Stack widget.
  `Shared/ClassActivity.swift` is left out of both, since there is no
  ActivityKit on the watch.
- `Mac/` — the Mac app: `MacPage.swift` is the window, `MacBoxes.swift` its
  boxes and the moving of them, `MacBackdrop.swift` what is behind it (the
  sky or glass) and the choice of it, `MenuBarClass.swift` the menu bar's
  class and its panel, `MacSettings.swift` Settings, and `MacModel.swift`
  what they share. It compiles `Page/`, `Shared/` and
  `Common/` too, leaving out `ClassActivity.swift` and `DeviceLink.swift`
  (no ActivityKit, no WatchConnectivity). Its widget, `TimetableMacWidget`,
  is `Widget/` without `ClassLiveActivity.swift`.

The folders are synchronised groups, so a file dropped into one in Finder or
Xcode is picked up by that folder's targets without editing the project.

## License

MIT — see [LICENSE](LICENSE).

The timetable logic is a port of the TIMETABLE section of the
[ManageBac Reimagined](https://github.com/Tiger0821/ManageBac-Reimagined)
userscript, written by Arstoien and extended by Tiger0821.
