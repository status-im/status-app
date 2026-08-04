# Collectible media loading

Status: active
Stage: build

## Outcome

A collectible tile stops being a delivery channel for the NFT original. Lists
render the provider's own preview, a tile that has already been shown does not
re-request anything, and the HTTP traffic of the Qt client becomes visible
inside the app instead of being guessed at from the phone's data counter.

## User scenario

A person restores a profile that owns collectibles, opens Wallet on mobile data
and switches between Assets, Collectibles and History for twenty minutes. Today
that costs hundreds of megabytes ([status-im/status-app#21497]). After this
feature the first paint of the grid costs preview-sized images, and every
subsequent switch between the three tabs costs nothing.

[status-im/status-app#21497]: https://github.com/status-im/status-app/issues/21497

## In scope

**status-go** (`vendor/status-go`, fork `friofry/status-go`)

- `ThumbnailURL` on `thirdparty.CollectibleData`, persisted in
  `collectible_data_cache` (new wallet-DB migration).
- Rarible mapper selects `PREVIEW` / `PORTRAIT` for the thumbnail instead of
  discarding them.
- Alchemy mapper maps `image.thumbnailUrl`, which is currently unmapped.
- Animation URL becomes honest: the Rarible `animationURL = imageURL` fallback
  goes away, and a `cachedUrl` whose media type is `image/*` is no longer
  reported as an animation.

**status-app**

- `thumbnailUrl` role through the Nim entry into the collectibles model.
- Four small-render consumers rebound to the thumbnail with the fallback chain
  from `decisions.md`; the detail view and the sign modal keep `mediaUrl`.
- `allowAnimation` on `StatusRoundedMedia`, set to `false` by the grid.
- The three wallet tab views survive tab switches instead of being destroyed.
- `QNetworkDiskCache` maximum size raised from the Qt default.
- An **HTTP statistics** screen next to the existing RPC statistics, plus a
  cache-size indicator and a cache-clear button.

## Out of scope

- A hard cap on collectible media size — [status-im/status-app#21506].
- Proxying third-party collectible media through the status-go media server —
  rejected for now, see ADR `0006-qt-http-cache`.
- Attributing traffic that does not pass through the QML network access
  manager: status-go, waku, the web engine, and the two `thread_local`
  managers in `systemutilsinternal.cpp` and `clipboardutils.cpp`.
- Playing animations in the grid on hover or tap.

[status-im/status-app#21506]: https://github.com/status-im/status-app/issues/21506

## Domain concepts

`Thumbnail URL`, `Image URL`, `Animation URL` — defined in
[`../../CONTEXT.md`](../../CONTEXT.md). The three-field contract is the heart of
this feature; do not restate it here.

## Acceptance examples

Given / When / Then scenarios live in [`./acceptance.md`](./acceptance.md).

## Constraints

- **Persisted shape.** Adding `thumbnail_url` to `collectible_data_cache`
  changes a persisted data shape, which
  [`../../AGENTS.md`](../../AGENTS.md) lists as needing explicit human
  approval. It is called out here so the approval is deliberate rather than
  implied by the diff.
- **Two repositories.** The backend change ships first as a pull request from a
  branch off `upstream/master` into `status-im/status-go`; status-app follows
  with a pin bump made through `scripts/bump-status-go.sh`.
- **Baseline before behaviour.** The instrumentation slice must be in the build
  that measures "before". If the cache limit or the tab keep-alive lands in the
  same build, the baseline is already improved and the before/after number that
  closes the ticket cannot be produced.

## Known

Every line below was read in the tree at pin `88d7048`.

- `rarible/types.go:368-411` ranks representations `PREVIEW=1, PORTRAIT=2,
  BIG=3, ORIGINAL=4` and returns the **largest**. `getImageURL` takes `BIG`;
  `getAnimationURL` takes video `ORIGINAL`, falling back to image `ORIGINAL`.
- `rarible/types.go:441` sets `animationURL = imageURL` when no animation
  exists, so `AnimationURL` is almost never empty.
- `alchemy/types.go:127-130, 227-228` maps `ImageURL` from `image.pngUrl` and
  `AnimationURL` from `image.cachedUrl`; `image.thumbnailUrl` is never read.
- `collectibles_entry.nim:158-163` prefers `animationUrl` over `imageUrl` for
  the `mediaUrl` property.
- `CollectiblesView.qml:502` binds the grid delegate to `model.mediaUrl`, so a
  tile roughly 150 px wide renders the original asset.
- `RightTabView.qml:295-300` drives all three tab views through a single
  `Loader`, destroying and recreating the view on every tab switch.
- `StatusRoundedMedia.qml:216-253` tries `StatusAnimatedImage` first and, on
  error, retries the **same URL** with `StatusImage` before falling back — up
  to three downloads of one asset.
- `externc.cpp:44-58` already installs a `QNetworkDiskCache`; no maximum size
  is set, so the Qt default applies. Its directory is `<dataDir>/tmp/netcache`
  (`constants.nim:47`, `nim_status_client.nim:316`) and nothing in the tree
  deletes it, so it does survive restarts.
- `manager.go:910-918` already issues a `HEAD` request per animation URL to
  learn its content type, and clears the URL when that request fails.
- `server/handlers.go:47` exposes `/wallet/collectibleImages`, but the payload
  it serves is only ever populated for community collectibles
  (`services/ext/service.go:533`).
- `AdvancedView.qml:367-372` is where RPC statistics is reached from; it is not
  gated by a build flag.

## Assumed

- Rarible returns a `PREVIEW` or `PORTRAIT` representation for the large
  majority of collectibles, and Alchemy populates `image.thumbnailUrl`. Where
  neither exists the fallback chain degrades to today's behaviour, so the
  feature is safe but the saving is smaller than expected.
- Third-party CDNs send cache headers good enough for `QNetworkDiskCache` to
  store responses. If they do not, the tab keep-alive still removes the
  re-request that this ticket is about; only cross-restart reuse is lost.

## Unknown

- What share of a real wallet's collectibles end up with an empty
  `thumbnailUrl`. The HTTP statistics screen answers this on the first
  measurement; nothing in the design depends on the number.
- Whether raising the cache limit changes anything measurable once the two
  larger levers are in place. Deliberately shipped as insurance, not as a
  lever — see `decisions.md`.

## Risks

- **Visible quality change in the detail view.** Making `animationUrl` honest
  means collectibles whose "animation" is a large still image now render
  `imageUrl` instead of the original. On Rarible that is `BIG` rather than
  `ORIGINAL`, which can look slightly softer on a large desktop window.
- **Three live tab views instead of one.** Memory grows by the delegates of
  three lists rather than one. `GridView` recycles delegates, so the cost is
  the visible area, not the whole list — but it is a real change on mobile.
- **Settings write timing.** `RightTabView.qml:469` saves sort settings in
  `Component.onDestruction`. Once views live, that fires when the wallet
  closes; it has to be moved onto the tab change or settings persist later
  than they do today.
- **Cross-repository ordering.** If the pin bump lands before the status-go
  pull request merges upstream, the app points at fork-only backend code. The
  branch strategy in `design.md` exists to keep that from happening silently.

## Related

- Design: [`./design.md`](./design.md)
- Acceptance: [`./acceptance.md`](./acceptance.md)
- Decisions: [`./decisions.md`](./decisions.md)
- ADR: [`../../docs/adr/0006-qt-http-cache.md`](../../docs/adr/0006-qt-http-cache.md)
- Tickets: [`../../.scratch/collectible-media-loading/`](../../.scratch/collectible-media-loading/)

## Approval

Meaning and architecture approved on 2026-07-30, including the persisted-shape
change called out under Constraints. The decisions behind it are in
[`./decisions.md`](./decisions.md); the one with a life beyond this feature is
ADR `0006-qt-http-cache`.
