# Design — collectible media loading

How the change sits in the existing layering, and where each seam is cut.
Terms are the ones in [`../../CONTEXT.md`](../../CONTEXT.md).

## The path today

```
Rarible / Alchemy  →  thirdparty.CollectibleData  →  collectible_data_cache
                                                          ↓
                                            wallet RPC (getOwnedCollectiblesAsync)
                                                          ↓
                            backend/collectibles.nim  →  collectibles_entry.nim
                                                          ↓
                                     model role `mediaUrl` = animationUrl ?? imageUrl
                                                          ↓
                        CollectiblesView delegate  →  CollectibleMedia  →  StatusRoundedMedia
                                                          ↓
                              AnimatedImage → (on error) Image → (on error) fallback
```

Three independent multipliers sit on that path: the provider mappers pick the
largest representation, the model prefers the animation over the image, and the
view is destroyed and rebuilt on every tab switch. They compound, which is why
the reported figure is in hundreds of megabytes rather than tens.

## Seam 1 — provider mappers (status-go)

`thirdparty.CollectibleData` gains `ThumbnailURL`. The mappers stop reaching for
the biggest asset:

- **Rarible.** `contentTypeValue` already ranks the representations. A
  thumbnail selector reuses that ranking in the opposite direction, preferring
  `PREVIEW`, then `PORTRAIT`, then whatever remains. `getImageURL` keeps its
  current meaning (`BIG`, `ORIGINAL` only as a last resort).
- **Alchemy.** `Image` gains the `thumbnailUrl` field and the asset mapper
  reads it.
- **Honest animation.** The `animationURL = imageURL` line goes away. In
  `fillAnimationMediatype`, where the content type is already known from the
  `HEAD` request, an animation URL whose media type is `image/*` and whose value
  equals the image URL is cleared.

This is the layer the decision belongs in: every client of status-go gets the
right URL without repeating the selection logic, and the app never learns what
a Rarible representation is.

**Persistence.** `collectibleDataColumns` (`collectible_data_db.go:34`) lists
the persisted columns, so the new field needs a migration under
`internal/db/walletdatabase/migrations/sql/`. Rows written before the migration
carry an empty thumbnail and fall through the chain below — no backfill, the
value is refreshed by the normal fetch cycle.

## Seam 2 — model role (status-app)

`CollectibleData` in `backend/collectibles_types.nim` gains the field,
`collectibles_entry.nim` exposes a `thumbnailUrl` property next to the existing
`imageUrl` / `mediaUrl`, and the collectibles model gains the matching role.
`mediaUrl` keeps its current meaning exactly — it is the detail-view concept and
nothing about it changes.

An older backend simply returns an empty string, which the fallback chain
already handles, so no version negotiation is needed.

## Seam 3 — consumers (status-app)

Small renders bind `thumbnailUrl`; the fallback chain is
`thumbnailUrl → imageUrl → placeholder`, and no list ever reaches for
`animationUrl`.

| Consumer | Today | After |
|---|---|---|
| `CollectiblesView.qml:502` | `model.mediaUrl` | thumbnail chain |
| `CollectiblesSelectionAdaptor.qml:114` | `model.imageUrl \|\| model.mediaUrl` | thumbnail chain |
| `SearchableCollectiblesPanel.qml:123` | `model.imageUrl \|\| model.mediaUrl` | thumbnail chain |
| `ProfileShowcaseCollectiblesView.qml` | image / media url | thumbnail chain |
| `CollectibleDetailView.qml:361` | `mediaUrl` | unchanged |
| `SendSignModal.qml:173` | `mediaUrl` | unchanged |

## Seam 4 — the media component (StatusQ)

`StatusRoundedMedia` gains `allowAnimation`, default `true`, so no existing
consumer changes behaviour. With `false`, `updateMediaLoader()` goes straight to
`StatusImage` and the animated-image branch is never taken. The retry ladder in
`processError()` is left alone: the comment at `StatusRoundedMedia.qml:237` is
right that `AnimatedImage` fails on files `Image` can read, and the detail view
still needs that recovery. The grid no longer reaches the ladder because it no
longer instantiates `AnimatedImage`.

## Seam 5 — tab view lifetime (status-app)

`RightTabView.qml` replaces the single `Loader` with one `Loader` per tab inside
the existing `StackLayout`. Each becomes `active` the first time its tab is
shown and stays active. Scroll position and filter state survive a tab switch,
which is a visible improvement on its own.

`Component.onDestruction: saveSortSettings()` moves onto the tab change, because
destruction now happens when the wallet section closes rather than when the tab
is left.

## Seam 6 — HTTP statistics (status-app)

The counter belongs where the network access manager is already created:
`StatusQNetworkAccessFactory` in `externc.cpp`. The manager it returns becomes a
subclass whose `createRequest()` wraps each reply, accumulating per host:

- requests and bytes served **from the network**,
- requests and bytes served **from the cache**
  (`QNetworkRequest::SourceIsFromCacheAttribute`),
- a prominent grand total.

Bytes are taken from `QNetworkReply::downloadProgress` rather than
`Content-Length`, which is absent on some responses and wrong on chunked ones.
Counters are process-lifetime with a reset button, and are not persisted — a
measurement run starts from a cold start anyway.

The screen sits next to RPC statistics in `AdvancedView.qml`, shaped like
`RPCStatsModal`, and adds a cache indicator built from
`QNetworkDiskCache::cacheSize()` against the configured maximum, with a clear
button. Without that button a cold-cache measurement cannot be reproduced
without reinstalling the app.

The screen states what it does **not** cover: status-go, waku, the web engine,
and the two `thread_local` managers in `systemutilsinternal.cpp:269` and
`clipboardutils.cpp:101`. Routing those two through the shared counter was
considered and dropped — two service requests are not worth the lifetime
plumbing, and an honest note is better than a silent gap.

## Slices

| Slice | Repository | Content |
|---|---|---|
| A | status-app | HTTP statistics, cache indicator, clear button. No loading behaviour changes. **Baseline is measured here.** |
| B | status-go | Seam 1, with mapper unit tests and the migration. Branch off `upstream/master`, pull request into `status-im/status-go`. |
| C | status-app | Pin bump, seams 2–5, cache limit. **"After" is measured here.** |

Slice C is developed locally against the fork pin and goes upstream with the
status-im pin once B has merged.
