---
name: qml-dev
description: Use when developing, fixing, or visually verifying a QML component on macOS — iterate against a live Storybook with hot reload, driving and inspecting the UI through the macOS Accessibility API instead of running the full Status app.
---

# QML dev loop via Storybook + macOS Accessibility

Iterate on production QML with a seconds-long feedback cycle: edit the file →
Storybook hot-reloads it → inspect and interact through the accessibility (AX)
tree → confirm. The Status client itself never runs.

## Prerequisites (one-time)

- Storybook built: `make storybook-build`. The build (and
  `storybook-agent.sh`) picks up whatever `qmake` is first on your `PATH`
  (`which qmake`), so no path is hardcoded — a Homebrew Qt
  (`/opt/homebrew/bin/qmake`), an official installer, or a `qmake6` symlink
  all work as long as it resolves to a **desktop macOS Qt 6** kit.
  - Only override when the `qmake` on `PATH` is the wrong kit (e.g. it
    resolves to an Android/iOS Qt and CMake would find the wrong Qt). Point
    `QMAKE` at the desktop kit's qmake for that one invocation:
    `QMAKE=$(command -v qmake6 || command -v qmake) make storybook-build`,
    or give the explicit path to your desktop kit's `bin/qmake`.
  - Sanity-check the kit before building: `qmake -query QT_VERSION` and
    `qmake -query QMAKE_XSPEC` (want a `macx-*` spec, not `android-*` /
    `macx-ios-*`). The build tree lands in `storybook/build/Qt<version>/`,
    keyed off that `QT_VERSION`.
- Permissions: `scripts/storybook-agent.sh start` runs `tools/ax/ax preflight`
  automatically (and builds the CLI if needed) — it verifies Accessibility
  AND Screen Recording for the terminal, triggers the system grant prompts,
  and **fails hard if either is missing**.

### If preflight fails — permission protocol

1. **Check your memory first**: if a memory records that the human already
   declined this permission, do NOT ask again — skip straight to step 4.
2. **Ping the human** and wait: tell them which permission is missing and
   where to grant it (System Settings → Privacy & Security → Accessibility /
   Screen Recording → enable the terminal app; the system prompt fires only
   once, and the grant takes effect after the terminal app restarts). Use a
   desktop notification if available (`cmux notify --title "QML dev loop"
   --body "<permission> needed"`) plus a direct question in the conversation.
   Do not silently continue.
3. **If the human grants**: re-run preflight and proceed with the full loop.
4. **If the human declines (once is enough)**: save a memory recording the
   refusal (e.g. `<permission>-declined — do not ask again`), then continue
   without that channel:
   - No Accessibility → the loop is unusable; stop and say so.
   - No Screen Recording → proceed AX-only (`ax screenshot` will fail; skip
     visual verification and say you did).
   Never re-ask in later sessions — the saved memory is the source of truth.

## The loop

1. **Start** (or reuse) the harness on the page for your component:

   ```bash
   PID=$(scripts/storybook-agent.sh start SwapModal)   # page name WITHOUT "Page" suffix
   ```

   Pages live in `storybook/pages/<Name>Page.qml` and wire the component with
   mocked stores/models. If none exists for your component, create one
   (copy a similar page).

2. **Inspect** the AX tree:

   ```bash
   tools/ax/ax tree --pid $PID --filter SwapModal   # subtree containing matches
   tools/ax/ax find --pid $PID --id signButton      # locate by identifier substring
   tools/ax/ax read --pid $PID --id signButton      # all attributes of one element
   ```

3. **Interact**:

   ```bash
   tools/ax/ax press --pid $PID --id editSlippageButton
   tools/ax/ax set   --pid $PID --id "payPanel.amountToSendInput.amountToSend_textField" --value "0.2"
   tools/ax/ax click --pid $PID --id someId          # synthesized mouse fallback
   tools/ax/ax screenshot --pid $PID --out /tmp/sb.png   # visual verification
   ```

4. **Edit** the production QML (`ui/app/...`, `ui/imports/...`,
   `storybook/pages/...`, `storybook/src/...`). Storybook auto-reloads in a
   few seconds (page unload → QML cache clear → reload; popups relaunched by
   the page's `Component.onCompleted`). Re-run step 2/3 to verify. **No
   rebuild, no restart.**

## Addressing elements

Qt exposes every accessible element with an `AXIdentifier` built from the
QML `objectName` chain (falling back to `ClassName_QMLTYPE_NN` for unnamed
ancestors), e.g.:

```
QGuiApplication.ApplicationWindow_….SwapModal.StatusScrollView_….payPanel.amountToSendInput.amountToSend_textField
```

- Match by the *suffix* you care about: `--id "payPanel.amountToSendInput"`.
  This is the same handle family the mobile Appium e2e suite matches
  (resource-id / name).
- If `find` reports multiple matches, extend the substring with more of the
  ancestor chain.

## Tree membership — when an element is missing

Only elements with an accessible interface appear: Quick Controls (Button,
TextField, CheckBox, ComboBox…) automatically; plain `Item`/`Rectangle`/
`Text` do not, even with an objectName. If you need a missing element:

- Add `Accessible.role` (and `Accessible.name`) to the **production** QML.
  This is a real accessibility improvement and also helps mobile Appium
  tests — never hack it into the harness.

## Scope & gotchas

- Hot reload covers filesystem-loaded QML: `ui/app`, `ui/imports`, storybook
  pages/mocks. **StatusQ QML and `storybook/main.qml` are compiled into the
  binary** — changes there need `make storybook-build` (incremental, fast)
  and a restart via `scripts/storybook-agent.sh stop && … start <Page>`.
- Values render locale-formatted (decimal comma on European locales):
  setting `0.2` reads back as `0,2`.
- **Interaction hierarchy — pure AX first.** `press`, `set`, `scroll`,
  `read`, `tree`, `screenshot` are pure accessibility calls: they work on
  background windows, never move the cursor, never steal focus, and cannot
  conflict with the human using the machine. Use them for ~everything.
- The real-input commands (`click`, `rightclick`, `hover`, `key`, `type`,
  `mousedown/up/move`) inject global HID events: they require the app
  frontmost and are inherently disruptive. They self-protect — refusing when
  the human used mouse/keyboard in the last 2s, when the app can't become
  frontmost, or when another window covers the target — and restore the
  cursor position afterwards. Treat a refusal as "wait and retry", never
  pass --force on a machine a human is actively using. If a flow needs many
  real-input events while the human works, pause and coordinate with them.
- `press` works on AbstractButton-derived controls; if it has no effect,
  check `read … | grep Enabled` before reaching for `click`.
- **Page knobs can pin state**: storybook pages often install `Binding`
  elements tying component state to the page's own controls (combos, text
  knobs). Interactions that imperatively write the same properties (e.g.
  SwapModal's exchange button swapping form values) are silently re-asserted
  by the binding — the component isn't broken; drive that state through the
  page knobs instead, or check the page QML before concluding a bug.
- Reload errors and QML warnings land in `$TMPDIR/storybook-agent.log` —
  check it whenever the tree looks stale or empty.
- Hot reload can be unreliable for popup-heavy pages after production-QML
  edits (stale component cache; popups relaunch from old components). If a
  change doesn't show, restart the harness (`storybook-agent.sh stop` +
  `start <Page>`) instead of debugging ghosts.
- An occluded window defers Qt layout polish, so screenshots can capture a
  half-laid-out UI. Run `ax activate --pid P` (no cursor move) before
  `ax screenshot` when pixel-accuracy matters.
- The AX tree also contains Storybook's own chrome (sidebar, knobs pane).
  Filter with `--filter <Component>` or match identifier substrings under
  your component's objectName.
