# Decisions — collectible media loading

Local decisions, in the order they were settled. The one decision that outlives
this feature was promoted to ADR `0006-qt-http-cache`.

## D1 — the scope is collectible media, not the reported 400 MB

The report measures the whole application's mobile data over twenty-two
minutes, and at least four unrelated sources feed it (waku, community fetching,
history scanning, media). This feature owns media only. Attribution of the rest
is not attempted here; the statistics screen from D9 is the first tool that
makes it possible at all.

## D2 — lists show a still preview, never an animation

_Rejected: hover- or tap-to-play in the grid._ There is no hover on mobile, and
a tap already means "open the detail view", so play-on-tap is a user-experience
question of its own rather than a traffic fix. The detail view keeps animation.

## D3 — the three URL fields get one written contract

`thumbnailUrl` for lists, `imageUrl` for the detail view, `animationUrl` only
when an animation genuinely exists. Recorded in
[`../../CONTEXT.md`](../../CONTEXT.md).

Making the animation url honest is part of this, not a nicety. While
`animationUrl` silently holds a still original, every future consumer that
reads the field by its name gets an original, and we would fix the grid only
until the next such consumer appeared.

## D4 — the thumbnail is chosen in status-go, not in the app

_Rejected: selecting a representation in the app._ The provider vocabulary
(`PREVIEW`, `BIG`, `ORIGINAL`; `pngUrl`, `cachedUrl`, `thumbnailUrl`) has no
business crossing into the client, and a second client would have to repeat the
choice. The cost is a persisted-shape migration, called out for approval in
`spec.md`.

## D5 — caching stays in the Qt layer

Promoted to ADR `0006-qt-http-cache`, which also records why proxying media
through the status-go media server was rejected for now.

The cache limit is raised as insurance, not as a lever. Its value dropped once
D2 and D6 were decided: a preview weighs tens of kilobytes, and a tab switch
stops issuing requests at all.

_Rejected: forcing responses without cache headers into the cache._ The same
network access manager also serves `https://localhost:<port>/…` from the
status-go media server, where content behind a stable URL does change. Serving
those from a forced cache would produce stale avatars and community images, and
the size of the win is unknown because we have never measured what the CDNs
send.

## D6 — the three wallet tab views survive tab switches

_Rejected: relying on the disk cache to make the re-request cheap._ That leaves
us depending on headers we do not control and on a limit shared with every
other image in the app; on a miss the full download returns. Removing the
request beats making it cheaper, and it also preserves scroll position and
filter state.

_Rejected: keeping only Collectibles alive._ History re-fetches too, and a rule
that applies to one tab out of three has to be explained forever.

## D7 — the grid opts out of the animated-image component

`allowAnimation` defaults to `true`, so nothing else changes. _Rejected:
removing the retry ladder for everyone._ The ladder exists because
`AnimatedImage` genuinely fails on files `Image` can read; deleting it would
regress the detail view to fix a grid problem that D2 already removed.

## D8 — every small render moves to the thumbnail, not just the grid

The send flow renders collectibles into list icons from `imageUrl`, which is a
full-size asset. Leaving it behind would keep a second leak of the same kind
open for the same user.

_Rejected: redefining `mediaUrl` so every consumer improves at once._ That is
precisely the implicit redefinition that made `animationUrl` untrustworthy in
the first place.

## D9 — the number comes from the product, not from `adb`

Acceptance is automated tests plus a measurement read off a new HTTP statistics
screen, rather than a one-off `dumpsys netstats` run by whoever happens to have
the device.

_Rejected: a manual device measurement as the acceptance criterion._ It is not
reproducible by anyone else, it dies with the ticket, and it cannot separate
cache hits from network fetches — which is the one distinction that shows the
work landed.

The screen aggregates per host with a prominent grand total. Per-URL detail was
considered and dropped: an NFT wallet produces thousands of distinct URLs, and
the question being answered is where the bytes went, not which token.

## D10 — the two `thread_local` network managers stay uncounted

`systemutilsinternal.cpp:269` and `clipboardutils.cpp:101` build their own
managers. Routing them through the shared counter is not worth the lifetime
plumbing for a handful of service requests; the screen names the gap instead of
hiding it.

## D11 — instrumentation ships before behaviour

The cache limit and the tab keep-alive are deliberately held out of slice A. If
they shipped alongside the statistics screen, the baseline would already be
improved and the before/after comparison that closes the ticket could not be
produced on one build.

## D12 — one specification, three slices, two repositories

The instrumentation is reusable beyond this ticket and could have been its own
feature, but splitting it would put its acceptance in a second document while
the number it produces belongs to this one. It stays here as slice A.

## D13 — the counter is a StatusQ QML singleton, not a Nim service

_Taken while implementing ticket 01, and it deviates from what that ticket
described._ The ticket proposed reaching QML through the `extern "C"` bridge and
a Nim service, mirroring how `getRpcStats()` travels. That mirror is the wrong
one: RPC statistics live in status-go, so the Nim chain is how they must
travel. HTTP statistics are produced in the same C++ file that builds the
network access manager, and pushing them through Nim would add three layers
that only forward.

`HttpStats` is therefore registered as a QML singleton in
`typesregistration.cpp` alongside `ClipboardUtils`, and the settings screen
reads it directly. The counter is a process-lifetime singleton with
`CppOwnership`, because the network access managers write into it and must not
outlive-or-be-outlived by a QML engine.

_Rejected: exposing a live `QAbstractListModel`._ Rows would churn once per
finished reply. The screen takes a snapshot and coalesces refreshes on a
timer instead, which is also what the existing RPC statistics screen does.

## D14 — the wallet tests run against a real `libsds`, built from source

_Taken while implementing ticket 04._ Wallet packages transitively import
`sds-go-bindings`, whose cgo file needs `libsds` — a native library built by
Nim. Two ways past it, and we now know both work:

- `-tags lint`. The bindings mark their cgo file `//go:build !lint` and ship a
  pure-Go stub, so the whole tree compiles without the native library. Cheap,
  and enough for packages where sds is a never-called transitive import.
- Building it. `make -C vendor/status-go build-libsds USE_SYSTEM_NIM=0` with
  `NIM_SDS_SOURCE_DIR` pointing at a `v0.3.3` checkout of nim-sds builds its own
  Nim through nimbus-build-system and produces `build/libsds.so`. No system Nim
  is needed, which matters because the distribution's Nim is far too old.

The collectibles and mapper tests pass both ways, which is the point worth
keeping: the stub is not hiding a linking problem, and the `-tags lint` result
that came first was not a false positive.
