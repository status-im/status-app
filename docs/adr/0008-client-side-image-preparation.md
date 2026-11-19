# ADR-0008: Chat images are prepared in the client, status-go passes compliant images through

## Status
- **Accepted**
- **Date**: 2026-11-16

## Why

Sending an Image message was slow and lossy. status-go decoded every attachment and re-encoded it as JPEG
(`internal/images`): up to 16 full encodes per photo (quality 80→50 in steps of 2 against a 50 KB "ideal"),
each on Go's generic slow path because the resize produced `image.NRGBA`. Measured on a Ryzen AI Max+ 395:
~1.27 s per phone photo, ~7.3 s for a 6-image Album. The same pipeline also turned transparent pixels black,
dropped GIF animation to frame 1, rejected animated WebP, and stripped the EXIF orientation without rotating
the pixels, so portrait photos arrived sideways.

Keeping the output identical, fixing status-go alone (RGBA + `draw.Src`, binary search over quality) brought a
phone photo to ~450 ms and an 8000×6000 image to ~1.16 s. Most of what remains is Go's full-resolution JPEG
decode and resize, which has no reduced-size decode or SIMD. That misses the target of a 6-image Album in ≤ 1 s.

## Decision

- **The client prepares each Attachment** (StatusQ, worker thread) as soon as it is attached:
  decode at reduced size with `QImageReader` (libjpeg-turbo, `setScaledSize`), apply EXIF orientation,
  keep transparency as PNG (white-background JPEG fallback over the size limit), pass animated GIF/WebP
  through unchanged within the limits (reject them in the chat input beyond), rasterise SVG to PNG,
  and encode photos with the existing rules (long side ≤ 2000 px, quality ladder 80→50 by binary search,
  50 KB ideal, 350 KB max). Picked, dropped and pasted images share this path. If preparation fails, the
  original goes to status-go (except SVG, which only the client can rasterise).
- **status-go stays the authority on limits and metadata.** An image that is already a supported format
  within the limits, and has no EXIF orientation other than 1, is passed through untouched apart from
  stripping metadata (EXIF/GPS, XMP, text chunks, GIF comments). Anything else goes through its pipeline,
  which gets the same-output performance fix, EXIF rotation and transparency → PNG for all callers
  (chat, community logos/banners, group-chat images, link previews); animation pass-through is chat-only.
- **Receivers** decide whether to animate an Image message from its actual format, not from a `.gif` URL suffix.

## Considered options

- **status-go only**: one place for the logic, but measured too slow even after the fixes (~300 ms/photo
  estimated with prediction), and Go has no reduced-size JPEG decode.
- **libjpeg-turbo in status-go via cgo**: fast, but makes every platform's build (including mobile
  cross-compiles) heavier for what Qt already ships.

## Consequences

- Image processing logic exists in two places (client preparation, status-go safety net) and must follow the
  same rules; client output is not byte-identical to status-go's (different JPEG encoders).
- Older clients receive PNG/GIF/WebP payloads; status-go already accepts them, but their UI shows animations
  as stills until they update.
- Measure with the `perf: send-images begin/end` log markers (debug level) around each send.
