# `StatusRoundedMedia` binding-loops on its own error path

Context: `docs/investigations/wallet-load-benchmarks.md`, "On-screen pass on the collectibles
path". Found in `issues/0019`; production code.

## What to build

```
QML Binding: Binding loop detected for property "when"   StatusRoundedMedia.qml:132
```

The `Binding on isError` has `when: mediaLoader.status === Loader.Ready`. It feeds
`onIsErrorChanged` → `processError()` → a reload, which moves the loader's status again,
which re-evaluates the `when`. Break the cycle.

It needs a collectible whose media fails to load, which is why nothing had hit it before: the
storybook mock's artwork happens to trigger it, because the image branch goes through
`AnimatedImage`, which cannot read a `QQuickImageProvider` image. That is a harness quirk, but
the loop it exposes is real product code on a real error path — media genuinely fails to load
in production.

While fixing it, check what `processError()`'s reload is for and whether it can loop in the
app too, not just warn. A retry that re-triggers its own trigger is a spin risk, not only a
log line.

## Acceptance criteria

- [ ] No binding-loop warning when a media item fails to load
- [ ] Error state still reached and rendered — the fallback image still shows
- [ ] Whether `processError()`'s reload can spin in production is determined and stated
- [ ] Covered by a test with a deliberately failing media source
- [ ] Storybook functional suite unchanged against its recorded baseline

## Blocked by

None - can start immediately. Note `issues/0019` also recorded that the storybook mock's
artwork is not animatable (`StatusAnimatedImage: Error Reading Animated Image File
image://walletmock/nft-...`); that is harness-only, but it is the trigger, so it is useful for
reproducing this.
