# Status Mobile App Lifecycle

Vocabulary for how the mobile app behaves across background/foreground transitions, established while investigating wake-time UI stalls (issue #21395).

## Language

### External intake (share & link handling)

Established while designing OS share-sheet / default-browser integration (upstream #20439).

**External intake**:
Any content the OS hands to the app: a Status deep link, an arbitrary web URL, or shared content (text and/or images). The umbrella term for everything arriving through the platform intent/open-URL layer.

**Share target**:
The app's entry in the OS share sheet. Declaring content types there is a contract — only declare what chat can actually send.

**Direct-share shortcut**:
A recent postable destination published to the OS so it appears as a one-tap target in the share sheet, above the app row. Lives outside the app (name + avatar visible to the OS even while the app isn't running); must be cleared on logout.

**Send-message intent donation**:
The iOS analog of a direct-share shortcut: after each successful send, the destination (conversation id + name + avatar) is donated to the OS as an INSendMessageIntent, and iOS surfaces donated conversations as one-tap suggestion chips in the share sheet (the share extension declares INSendMessageIntent support). Same privacy rule: all donated interactions are deleted on logout; they repopulate organically as the user sends.

**Postable destination**:
A chat the logged-in user can post to: 1-1 chat, group chat, or community channel with post rights.

**Destination picker**:
The in-app screen where the user chooses a single postable destination for shared content — searchable, ranked like the shortcuts: destinations the user recently sent to first (by own-send recency), then never-sent-to ones by any-message recency.

**Pending intake slot**:
The single, last-wins buffer holding an external intake until the app can act on it (`mainWindowReady`, i.e. after login or onboarding completes). Shared image streams are copied to app-private cache at receipt — the slot holds copied paths, never OS-managed URIs (their read grants expire).

**Browser candidacy**:
The app declaring it can handle arbitrary http/https links, making it appear in the OS link-chooser and default-browser lists. Every externally received web URL opens as a new browser tab; Status deep links keep their existing routing.

### Lifecycle

**Wake**:
The moment a live, backgrounded app instance returns to the foreground. Distinct from a warm restart — no loading screen, same process.
_Avoid_: resume, reopen (ambiguous with restart)

**Warm restart**:
A fresh UI-process launch while device state (caches, DBs, service process) is still warm. Shows the loading screen.

**Frozen**:
UI-process state under the Android cached-app freezer — no threads run, so nothing in-process can execute or log. Distinct from merely backgrounded.

**Backgrounded**:
UI process alive and schedulable but not visible; the Qt main loop is suspended, so queued events accumulate in-process.

**Paused services**:
status-go services that suspend their periodic work while the app is backgrounded and resume on wake. The service process itself stays fully alive.

### Wake-stall investigation

**Inactivity**:
Decomposes into three independently accumulating dimensions: message backlog, elapsed wall-clock time, and OS clamping (Doze/freezer). Saying "inactive for N hours" without naming the dimension is imprecise.

**Signal**:
A JSON event emitted by the service process to the UI process over the oneway Binder listener.

**Binder queue**:
The kernel-side async binder buffer (~1MB) holding signals sent to a frozen UI process. Overflow drops signals — a delivery failure, not a delay.

**Qt event queue**:
The in-process, unbounded queue where delivered signals wait while the app is backgrounded; drained in a burst on wake.

**Queued backlog**:
Signals emitted *before* the wake moment and drained at wake. Bounded by the binder queue cap.

**Fresh wake storm**:
Signals generated *because of* the wake itself — service resume, catch-up fetches. Unbounded; scales with inactivity.

**Token stall**:
The dominant wake-stall component: wallet token-service async completions (refresh-tokens, fetch-all-token-lists) parsed on the GUI thread. Signal-driven — triggered by `wallet.token-lists.updated`. Distinct from the backlog drain.

**Backlog drain**:
The secondary wake-stall component: processing the queued backlog through the Qt event queue at wake.

**Token catalogue**:
The full token universe returned by `getAllTokens` (~3MB). Fetched only when it can change — init or `wallet.token-lists.updated` — never on a routine refresh (upstream #21452).

**Routine refresh**:
A refresh-tokens run triggered by anything other than init/token-lists-updated. Refreshes tokens of interest only; skips the catalogue fetch.

**Known-missing key** (upstream: *unresolvable token key*):
A token key the backend confirmed as "not found" — typically a delisted spam/scam token. Negative-cached so lookups stop re-hitting `wallet_getTokensByKeys`; invalidated when a refresh applies fresh token data. Upstream #21452's `notFoundKeys` is the same concept; this series' `knownMissingKeys` implementation supersedes it.

**View-bound churn**:
The cost class where a model `dataChanged` triggers work proportional to the *visible view* (delegate teardown + proxy-role re-derivation), not to the actual data delta. Measured on AssetsView: the same refresh costs 44–76ms with the wallet closed vs 1.6–2s profiled with it open, recurring on every ~2-minute periodic update.

### Wake benchmark

**Replay corpus**:
Real signal payloads captured at the emission point during an inactivity window plus the wake, stored as a fixture and re-injected for benchmark runs.

**Amplification**:
Offline cloning of corpus payloads to overnight volume with deterministic identity-field rewriting (message IDs, clocks). **Volume-type** signals (e.g. messages.new) are amplified; **trigger-type** signals (e.g. wallet.token-lists.updated, which fires expensive work per occurrence) are pinned at captured counts.

**Debug command signal**:
A synthetic signal (type `debug.command`) injected through the normal signal delivery path by a dev-build-only receiver, used to trigger benchmark actions in-app (e.g. fire the token refresh tasks).

**Wake-shaped run**:
A benchmark run that queues work while the app is backgrounded and measures from the wake moment — as opposed to a foreground fast-iteration run.

### Overheat investigation (issue #21470)

**Overheat repro (path 1)**:
The scoped reproduction for this hotfix: fresh empty profile → spectate the Status community → open `#general` → heat while the channel loads. The synced-profile Collectibles-tab path (path 2) is explicitly out of scope for the HF.

**Auto-repro driver**:
A dev-only, compile-gated in-app driver that walks the app to the repro state (create account → spectate Status community → open `#general`) with no human input, identically on desktop and Android. Never ships.

**Repro monitor**:
The on-device sampling loop recording per-process CPU (UI vs service process split), app network bytes, temperatures, and battery current during a repro session — device unplugged, wireless adb.

**Load window / post-load settle**:
The two measurement phases of a repro session: while the channel is loading (heat expected today) and after loading completes (usage must return to near-idle).

**Overheat gate**:
The absolute acceptance criterion — no version-baseline comparison. During the load window the device stays comfortably cool (skin ≈ ≤40 °C, no sustained pegged cores), and CPU/network settle to near-idle post-load.

**Investigation build**:
The build under test: `2.38` release-branch tip + cherry-picked profiling tooling + the auto-repro commit, installed under a distinct application id so its on-device profile never mixes with release-profile data.

### Curated directory (issue #21470 follow-up)

**Curated directory**:
The on-chain registry (Optimism directory contract) of community ids featured in the Discover/Communities-portal UI. Membership in the directory says nothing about whether the local node holds those communities' descriptions.

**Directory refresh**:
The act of resolving ALL directory entries to their latest community descriptions — fired solely on entry (or re-entry) into the curated-communities UI, with no TTL, staleness, or network-type exceptions and no manual-refresh affordance. Nothing refreshes the directory in the background; the expensive-network pause died with the background loop.

**Directory read**:
Returning locally stored directory data with no fetching side effect (`getCuratedCommunities` after this change).

**Refresh progress signal**:
The event stream emitted during a directory refresh so the UI can decide between skeleton and content states.

**Bounded resolve**:
Fetching the latest data for one community or contact from a store node: newest-first, page-capped, fixed time window (communities 7 days, contacts 31 days), terminating unconditionally with one of three outcomes — resolved, already-up-to-date, or unresolved. Replaces open-ended window draining everywhere; an unresolved outcome is never retried except by a new user-triggered action.

**Verified-only display**:
Nothing about a community is shown to the user (name, logo, description) unless its description passed owner verification. There is no unverified/display-only state anywhere — rejected candidates are never rendered. Closes the control-node impersonation window entirely.

**Owner hunt**:
The bounded extra store-node paging a resolve performs when the normal newest pages produced only rejected (not-authorized) description candidates: keep paging (hard cap) and synchronously validate queued candidates after each page, stopping the moment an owner-signed copy establishes the community. Success persists for the profile; failure leaves the entry unresolved until the next user-triggered resolve.

### Agent QML dev loop (POC)

Established while designing the accessibility-driven QML iteration POC (macOS, SwapModal pilot).

**Agent loop**:
The develop→verify cycle an agent runs against a live Storybook: edit a QML file → hot reload picks it up → inspect and interact through the accessibility tree → confirm via AX state and screenshot. No application rebuild or restart inside the loop.

**Harness**:
The live Storybook process hosting the component under work, launched directly on a page. It is the only running GUI process in the loop — the Status client itself never runs.

**Page**:
A Storybook QML file that instantiates one production component with mocked stores/models and interactive knobs (e.g. `SwapModalPage`). The unit of hot reload.

**Hot reload**:
Storybook local-mode behavior: a watched QML file change unloads the current page, clears the QML cache, and reloads. Covers filesystem-loaded production QML (`ui/app`, `ui/imports`); does *not* cover QML compiled into the StatusQ library, which still needs a rebuild.

**AX driver**:
The CLI through which the agent reads the accessibility tree and acts on it (find, press, type, read). The agent's only interaction channel besides screenshots.

**Identifier path**:
Qt's built-in accessibility identifier: `Accessible.id` if set, else the dotted objectName/className path up the ancestor chain. Exposed as AXIdentifier (macOS), resource-id (Android), name (iOS) — the same handle the Appium e2e suite already matches by substring. Elements are addressed by suffix/substring match on this path; no bridge code exists or is needed.

**Tree membership**:
Whether an item surfaces in the accessibility tree at all. Quick Controls get an accessible interface automatically; plain Items need an explicit `Accessible.role` in production QML. An objectName alone does not grant membership — membership gaps are fixed in production QML (and pay off on mobile Appium too), never in the harness.

**Visual channel**:
Per-window screenshots as the second verification signal — catches what AX structurally cannot (clipping, overlap, styling), cf. elements that exist in the tree but are unreachable on screen.

**Drill**:
The acceptance scenario for agent tooling: inject a known bug, then require a fresh agent — armed only with the documented workflow — to reproduce, fix, and verify it through the loop.

### User identity & naming

Established while making member/user name derivation item-owned (perf/mobile-section-extras).

**Preferred display name**:
The single name the UI shows and sorts by for a user, resolved by fixed precedence: local nickname → effective ENS name → display name → alias. Derived state — owned by the item, never supplied by callers.

**Effective ENS name**:
The ENS name only if ENS-verified, otherwise empty. All name derivations (preferred display name, uses-default-name) consume the effective form; an unverified ENS name counts as no name.

**Uses default name**:
True when the user has no chosen name of any kind (no local nickname, no effective ENS name, no display name) and is therefore shown their auto-generated alias. Same ownership rule as preferred display name.

**Nameless-last sentinel**:
The `"zzz"` value a preferred display name resolves to when every name source including the alias is empty, so nameless users sort last in name-ordered lists. Never rendered; in practice near-unreachable since the alias derives from the pubkey.

**Canonical member order**:
The one total order for member lists: online status descending (Online before Inactive), then preferred display name case-folded ascending, then pubkey as tie-break. An invariant of the member model itself — maintained at insert/update via granular moves, never re-derived by consumers. The tie-break is what makes the order total, so incremental repositioning has exactly one correct answer. Mentions ordering is a *different* order (pure alphabetical, "@everyone" injected) and stays consumer-side.

### Model data-flow (wallet model rework)

**Terminal model**:
A model that feeds its ListView directly — no proxy models, no expression roles between it and the view. Grouping, joins, filtering, search, sorting, and derived roles are computed inside the model (Nim). The terminal-model rule is what makes granular emissions safe: a per-row `dataChanged` reaches the view as exactly that, instead of being amplified.

**Emission amplification**:
The failure mode of stacked QML proxies: one granular source emission is multiplied into whole-model `dataChanged` → dynamic re-sort → `layoutChanged` → delegate churn by each proxy layer. Lesson: granular emissions are only as cheap as the dumbest proxy above them — replace the chain, don't incrementalize each layer.

**COW snapshot container**:
The service↔model hand-off for token state: the service publishes an immutable versioned container (a fresh array per update, row refs shared with the previous version — no deep copy). Consumers hold a ref to the version they rendered; `model_sync` diffs previous↔next to emit granular ops. Worker-built state (typed handoff) becomes the next version by move, never by re-parse or copy.

**Adaptor model (terminal)**:
The concrete terminal models of this rework: `AssetsAdaptorModel` (wallet assets list) and `TokenSelectorAdaptor` (shared token picker for send/swap/buy — search/chain-filter/sort in Nim). Named by transformation per the QML architecture guide, injected via context property behind a store.

### Logos integration (liblogos in Status)

Established while scoping the liblogos-on-mobile mission (wallet stack as proof target).

**Logos module**:
A unit of functionality loaded by liblogos: a manifest plus a loadable artifact (codegen-glued dylib for native modules), declaring dependencies on other modules and reached through inter-module calls. The wallet proof target: `wallet_backend` and its dependency modules (`eth_rpc`, `keystore`, `token_list`).

**Container**:
The liblogos seam deciding *where and how* a module executes; knows nothing about the module's format. Named implementations in our design: **subprocess container** (desktop, one OS process per module — status quo), **in-process container** (mobile v1, modules as supervised threads inside the app process), **web container** (future: wasm/JS modules in a webview).

**In-process container**:
The mobile v1 container. Modules are dlopened (`RTLD_LOCAL`) into the app's address space and supervised in-process; module binaries and glue stay identical to desktop, while transport switches to Local mode. Forced on iOS (no fork/exec, no non-embedded native code); chosen on Android over subprocess for singleness of implementation and process/battery economy.

**Panic containment contract**:
The in-process container's honest crash story: Rust panics are caught at the module boundary (module → Failed, supervised restart) and hangs are watchdogged; hard faults (SIGSEGV in unsafe/C code) and memory exhaustion remain shared fate — the same posture as every native library Status already links.

**Web container**:
The designated future container running wasm/JS-compiled modules inside a webview (WKWebView / Android WebView). The only sanctioned out-of-process execution *and* the only legal downloaded-code path on iOS (App Store 2.5.2). Home for third-party/downloaded modules; converges with the web-only mini-apps design. Requires per-module wasm targets and a postMessage-style transport — hence not v1.

**Transport**:
How inter-module calls travel (liblogos per-module transport seam). Desktop: QtRemoteObjects over LocalSocket, direct module-to-module, with only the capability token brokered. Mobile v1: **Local mode** (`LogosMode::Local`) — upstream's in-process transport where modules meet through a process-wide plugin registry and inter-module calls are direct in-process invocations, no sockets. Hardening Local mode (event-delivery gap, production entry point) is a mission deliverable.

**Walking skeleton (Logos)**:
Milestone 1: `eth_rpc_module` alone — zero module dependencies — loaded through the in-process container on device, proving core + container + loader before the full wallet stack.

### Chat message windowing (PR #21970)

**Message window**:
The contiguous slice of the message history the chat view actually holds rows for. Everything outside it is represented only by a placeholder. Sliding the window is the paging act; the history itself never changes because of it.

**Staged row**:
A row admitted to the message window whose real content is still being built. Staged rows occupy no visual space — the placeholder keeps covering their region — and the user never sees one.

**Atomic reveal**:
The moment a whole in-flight batch of staged rows becomes visible at once, replacing the placeholder space it was built under. All-or-nothing per batch: the view goes from placeholder to fully-formed rows in a single step, never through partially-built states. A live incoming message is not part of any batch and shows immediately.

**Prefetch margin**:
The distance ahead of the viewport at which paging is triggered, so a batch is usually revealed before the user ever scrolls its placeholder into view. The placeholder is the fallback for scrolling faster than the batch can build, not the normal experience.

### Surface load benchmarking (wallet perf)

Established while planning benchmarks for the wallet section, its popups and the asset detail page.

**Surface**:
A user-visible destination whose arrival is worth timing on its own: the wallet section, the send / receive / swap popups, the asset detail page. The unit a load benchmark is written against.

**Load staircase**:
The ordered stamps a surface passes through on its way in, measured from the moment the surface is requested. Three rungs: **time-to-skeleton** (placeholder chrome visible), **time-to-ready** (the surface's own async Loader reaches `Loader.Ready` — real tree built, nested content may still be placeholder), **time-to-content** (the surface has realised its content — no grey tiles left).

**Time-to-content**:
The headline load number for a surface — the top rung of the load staircase. Chosen as the headline because it is the only stop line that cannot be improved by deferring work deeper; the lower rungs are reported alongside it as attribution, never as the headline. A loader reporting `Loader.Ready` does not establish it: readiness can precede the surface's first layout pass, leaving a view that is ready and empty. The stop line must observe realised content — items the surface actually produced — and every surface has to have that verified rather than assumed.

**Stall probe**:
A fixed-interval timer running through a measurement window; its largest tick-to-tick gap is the GUI-thread stall. Attribution only — it explains a bad staircase, it is not the gate.

**Bite**:
One call to the incubation controller's `incubateFor(budget)`. Its budget is a *lower* bound on the GUI-thread block it produces: the call returns only after finishing the object it is midway through creating, so the block is the budget plus that **overshoot**. The overshoot is what sets a surface's stall floor, which is why a smaller budget does not buy a smaller stall.

**Duty cycle**:
Bite budget ÷ tick interval — the share of the GUI thread incubation may take while pacing is gentle. It is what a metered load's wall clock is divided by: work run in bites takes roughly `1 / duty cycle` times its own cost. Distinct from the bite, which sets latency, not throughput.

_Avoid_: "load time" unqualified — always name the rung. _Avoid_: "incubation budget" for either of the two above — say bite or duty cycle.
