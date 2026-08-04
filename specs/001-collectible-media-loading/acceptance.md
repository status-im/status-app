# Acceptance — collectible media loading

Two kinds of evidence. Scenarios 1–6 are automated and gate the pull requests.
Scenarios 7–9 are read off the HTTP statistics screen and are what closes
[status-im/status-app#21497]; they need a wallet that owns collectibles.

[status-im/status-app#21497]: https://github.com/status-im/status-app/issues/21497

## Automated

### 1. Rarible prefers the smallest representation for the thumbnail

- **Given** a Rarible item whose contents include `PREVIEW`, `BIG` and
  `ORIGINAL` representations of the same image
- **When** the item is mapped to collectible data
- **Then** the thumbnail url is the `PREVIEW` content, and the image url is
  still the `BIG` content

### 2. Rarible falls through when no preview exists

- **Given** a Rarible item whose only image content is `ORIGINAL`
- **When** the item is mapped
- **Then** the thumbnail url is empty rather than the original, so the consumer
  chain decides what to show

### 3. Alchemy maps its thumbnail

- **Given** an Alchemy asset whose `image` object carries `thumbnailUrl`,
  `pngUrl` and `cachedUrl`
- **When** the asset is mapped
- **Then** the thumbnail url is `thumbnailUrl` and the image url is `pngUrl`

### 4. A still image is not reported as an animation

- **Given** a collectible with no animation, whose provider payload would
  previously have copied the image url into the animation url
- **When** the item is mapped and its media type is resolved
- **Then** the animation url is empty

### 5. The grid renders a thumbnail and never an animation

- **Given** a collectibles model whose entries carry a thumbnail url, an image
  url and an animation url
- **When** the wallet collectibles grid is instantiated
- **Then** each tile's media source is the thumbnail url, and no animated image
  component is created
- **And** an entry with an empty thumbnail url falls back to the image url
- **And** an entry with neither shows the placeholder without requesting the
  animation url

### 6. Switching tabs does not rebuild the views

- **Given** the wallet with the Collectibles tab open and its grid scrolled
- **When** the user switches to Assets and back to Collectibles
- **Then** the collectibles view instance is the same object as before
- **And** its scroll position is unchanged
- **And** the sort settings written on the tab change match what the previous
  behaviour wrote on destruction

### 10. The send picker renders previews, not originals

Numbered after the measured scenarios because it was written later; it belongs
with the render scenarios above. It is decision D8 made checkable.

- **Given** the send modal's collectibles picker, whose rows come from the Nim
  `CollectiblesSelectorModel` and not from the retired QML adaptor
- **When** a group row, a sublist row or the selected-token header is rendered
- **Then** the url each one renders is the thumbnail url, falling back to the
  image url and then the animation url
- **And** the model hands over that url unsized — the delegate that knows its
  own render size is the only place that asks the CDN for a width
- **And** a delegate binding a role the model does not expose is a test failure,
  not a silent fallback to the full-size asset

**Met.** `collectibles_selector_builder_test` pins the pick and that the builder
never sizes a url; `collectibles_selector_model_test` pins the `thumbnailUrl`
role on both views; the host integration test reads the roles back through a
real QML scene and fails on a missing role instead of rendering `undefined`.

## Measured on the HTTP statistics screen

The baseline is taken on a build that contains slice A and none of slice C. It
was measured on branch `claude/collectible-media-baseline` and is recorded in
[`.scratch/collectible-media-loading/issues/03-baseline-measurement.md`](../../.scratch/collectible-media-loading/issues/03-baseline-measurement.md):
45.8 MB of network traffic in 149 requests, of which 38.9 MB in 65 requests is
collectible media at roughly 600 KB apiece, with the 50 MB disk cache 91% full
and evicting. That ticket also records what the baseline does not cover.

### 7. Repeated tab switching costs nothing

- **Given** a restored profile whose wallet owns collectibles, the Collectibles
  tab already loaded, and the statistics counters reset
- **When** the user switches Assets ↔ Collectibles ↔ History ten times
- **Then** network bytes attributed to collectible media hosts are zero
- **And** any requests that do appear are served from the cache

**Met.** `res.cloudinary.com` served 3484 requests for zero network bytes over
a warm session; total network traffic was 1.5 MB against the baseline's 45.8 MB,
and nearly all of what remains is the status-go media server on localhost,
which is deliberately not cached. Measured with ticket 11 reverted, so the disk
cache limit carries this on its own. Recorded in
[`.scratch/collectible-media-loading/issues/13-after-measurement-and-acceptance.md`](../../.scratch/collectible-media-loading/issues/13-after-measurement-and-acceptance.md).

### 8. First paint of the grid costs preview-sized images

- **Given** a cold start with the cache cleared from the statistics screen
- **When** the Collectibles tab is opened and the grid finishes loading
- **Then** the network bytes for that step are an order of magnitude below the
  same measurement on the baseline build, on the same wallet and device

**Partly evidenced, not signed off.** A cold run — cache cleared, grid opened
— fetched 101.4 MB across 551 requests, which is **188 KB per image** against
the roughly 4.5 MB original Rarible offers for the same collectibles. Previews
are reaching the grid. But it is not the baseline's wallet: 551 images here
against 65 there, and a different provider. Per image the improvement is 3.3×
(612 KB → 188 KB), not the order of magnitude this scenario asks for. Either
rerun both halves on one wallet, or restate the scenario in per-image terms
against what the provider would otherwise have sent.

### 9. The screen accounts for what it claims

- **Given** the HTTP statistics screen after any browsing session
- **When** the totals are read
- **Then** per-host rows separate network bytes from cache bytes, the grand
  total is shown without having to add the rows up, and the screen names the
  traffic it does not observe

## Not proven here

Absolute traffic of the whole application. status-go, waku and the web engine
stay outside the counter, so this feature can only claim the share that passes
through the Qt client. Attributing the rest is its own piece of work — the
original report mixes both, and that distinction is recorded in `decisions.md`.
