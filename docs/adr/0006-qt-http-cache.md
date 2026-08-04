# HTTP caching for third-party media stays in the Qt network layer, and list-sized media is asked for by rewriting the CDN URL

Collectible media is fetched by QML `Image` / `AnimatedImage` straight from the
provider CDN, and the obvious place to put a cache — the status-go media server,
which already serves community collectible images from `collectible_data_cache`
over `/wallet/collectibleImages` — turns out to buy far less than it looks like,
because **status-go runs on the same device**: by the time it could resize,
deduplicate or evict anything, the bytes have already crossed the mobile
network, so a proxy saves traffic only through caching and a size cap, not
through anything it does to the payload. We therefore keep HTTP caching where it
already is, in the `QNetworkDiskCache` installed by
`Status::NetworkAccessFactory` (`ui/StatusQ/src/networkaccessfactory.cpp`) on
the QML engine's network access manager, configure it (an explicit maximum size instead of the Qt
default), and make its behaviour observable through an in-app HTTP statistics
screen that separates bytes served from the network from bytes served from the
cache. _Rejected: proxying third-party collectible media through the status-go
media server_ — it costs a new blob store, an eviction policy and a schema
migration in exchange for cache-and-cap only, and the traffic problem it was
proposed to solve is better addressed upstream of the download by asking the
provider for its own preview instead of the original (`thumbnailUrl`); the
option stays open and becomes attractive again if a hard size cap
(status-im/status-app#21506) needs to be enforced for both clients in one place,
since the `HEAD` request status-go already issues per animation URL is where a
`Content-Length` check naturally sits. _Rejected: forcing responses that carry no
cache headers into the disk cache_ — the same network access manager also serves
`https://localhost:<port>/…` from the status-go media server, where the content
behind a stable URL legitimately changes (account and community images), so
forced caching would produce stale images that are painful to diagnose, and the
size of the win is unmeasured; the statistics screen exists precisely so that
this can be decided from data if the CDNs turn out to be uncooperative.

Caching only decides how often the bytes cross the network; how many bytes
there are is decided by which derivative we ask for, and Alchemy — the provider
behind the wallets we measured — serves its derivatives from its own Cloudinary
cloud, `res.cloudinary.com/alchemyapi/…`, pointing the client at one sized for
something other than a list. Measured on a real wallet, one switch to the
Collectibles tab issued 554 image requests, 539 of them for Alchemy's
`convert-png` derivative, which averages 43 KB and runs past 370 KB for a tile
roughly 150pt wide. Asking the same CDN for the same asset at 300 pixels in
WebP returns 9 KB: between 2.1x and 17.6x smaller across a sample of eight,
7.7x in aggregate. We therefore **rewrite the delivery URL where the render size
is known**: `Utils.resizedMediaSource` inserts `w_<width>,c_limit,f_auto,q_auto`
after `/image/upload/` — or after `/video/fetch/`, which serves the still frame
of an animated collectible and is the single most expensive thing the CDN hands
us: one measured at 2.85 MB against 31 KB for the same frame at 300 pixels. That
path already carries a chained `f_png,so_0`, and a transformation placed ahead
of it chains rather than replaces it. `Status::withAcceptedImageFormats` sends
`Accept: image/webp,image/png,image/jpeg` on both delivery paths so `f_auto` has
something to resolve against. `c_limit` bounds the width without
enlarging anything smaller — plain `w_300` re-encodes a small PNG upwards and
made one sample larger than the original. The Accept list is narrow on purpose:
`f_auto` will return AVIF or JPEG XL to a client that claims them and Qt decodes
neither, so `image/*` would trade a large file for an unreadable one. The
untransformed URL stays available as the media component's fallback, so the
worst case if Cloudinary or Alchemy changes its mind is today's file size rather
than an empty tile.

_Scope: the rewrite reaches Alchemy's derivatives and nothing else._ It matches
on the delivery host, so it is a no-op for every URL that does not come from
Cloudinary — and that is more of them than the figures above suggest. Only
Alchemy's derived URLs (`pngUrl`, `thumbnailUrl`, and the `/video/fetch/` still
of an animated asset) live there; its `cachedUrl` and `originalUrl` — the
animation and the original — are served from `nft-cdn.alchemy.com` or the
asset's own host, and Rarible serves everything from its own hosts
(`ipfs.raribleuserdata.com`, `lh3.googleusercontent.com`, `i.seadn.io` in the
responses status-go records as fixtures). The measured 7.7x is therefore about
Alchemy-sourced still media, which is what a wallet's list view mostly draws.
Everything outside that scope is bounded only by whatever the provider chose to
serve, which is what a hard size cap (status-im/status-app#21506) exists to
address.

_Rejected: asking the provider for a smaller derivative instead._ This is the
honest version and it is what `thumbnailUrl` already does. It is not enough on
its own: Alchemy's own `thumbnailv2` derivative measured 16.7 KB against 9.4 KB
for the same asset requested at 300 pixels, and a provider that offers no
preview at all leaves the client holding the original. The two compose — we pick
the smallest derivative the provider offers, then ask for it at the size we will
draw.

_Rejected: doing the rewrite in status-go at mapping time._ status-go knows the
provider but not the render size, and the same URL feeds a 150pt grid tile, a
32pt row in the send modal and a full-bleed detail view. A hint chosen once for
all three is wrong for two of them. Keeping it in `Utils` puts the decision next
to the only code that knows how large the image will be drawn.

_Rejected: rewriting inside `CountingNetworkAccessManager` instead of in QML._
It would catch every consumer in one place, including ones added later, but at
that layer the render size is gone — the manager sees a URL and nothing else,
and would have to assume a single size for the detail view and the grid alike.
The Accept header does live there, because it is a statement about the client's
decoders and is true of every request regardless of who made it.

_Accepted risk: several disk caches share one directory._ The QML engine asks
the factory for a network access manager per thread that needs one — measured
with a probe in `create()`: two in Storybook's remote mode, and a third in the
application, where XHR from QML takes the engine's own manager. Each gets its
own `QNetworkDiskCache` pointed at the same directory, which Qt documents as
unsupported: "Currently you cannot share the same cache files with more than one
disk cache." The consequences are real but small. Each instance counts only its
own writes, so none of them knows the size of the directory and the 512 MB cap
is enforced against a partial view — the directory can grow past it. Entries are
written to a temporary file and renamed, so two managers fetching the same URL
at the same time overwrite rather than corrupt. We keep one directory because
the alternative — a subdirectory per manager — turns one budget for the QML
layer into one per manager and stores the same image twice, and because the
question the statistics screen answers is what is on disk, which the screen
measures directly rather than asking any cache. Worth revisiting if a hard size
cap (status-im/status-app#21506) has to be enforced rather than merely reported.

_Accepted risk: the delivery hints are an unwritten contract._ Cloudinary
documents `f_auto`, `q_auto` and `c_limit` as ordinary URL transformations, but
nothing obliges Alchemy to keep arbitrary transformations enabled on its cloud;
Cloudinary's strict-transformations mode would reject them. It is currently off
— a bare `w_300` returns a differently sized image rather than an error. The
fallback above is what makes this an acceptable bet rather than a fragile one.
