---
name: qml-dev
description: Use when developing, fixing, or visually verifying a QML component on macOS — iterate against a live Storybook with hot reload, driving and inspecting the UI through the macOS Accessibility API instead of running the full Status app.
---

# QML dev loop via Storybook + macOS Accessibility

Iterate on production QML with a seconds-long feedback cycle: edit the file →
Storybook hot-reloads it → inspect and interact through the accessibility (AX)
tree → confirm. The Status client itself never runs.

## Prerequisites (one-time)

- Storybook built: `QMAKE=$HOME/Qt/<ver>/macos/bin/qmake make storybook-build`
  — the `QMAKE` override matters: the ambient env often points at an
  Android/iOS Qt kit and CMake will find the wrong Qt.
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
- `press` works on AbstractButton-derived controls. If a press has no
  effect, check `read … | grep Enabled` first, then fall back to `click`
  (needs the window unobstructed; synthesized events go to screen coords).
- **Page knobs can pin state**: storybook pages often install `Binding`
  elements tying component state to the page's own controls (combos, text
  knobs). Interactions that imperatively write the same properties (e.g.
  SwapModal's exchange button swapping form values) are silently re-asserted
  by the binding — the component isn't broken; drive that state through the
  page knobs instead, or check the page QML before concluding a bug.
- Reload errors and QML warnings land in `$TMPDIR/storybook-agent.log` —
  check it whenever the tree looks stale or empty.
- The AX tree also contains Storybook's own chrome (sidebar, knobs pane).
  Filter with `--filter <Component>` or match identifier substrings under
  your component's objectName.
