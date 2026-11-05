
# Architecture of the Status App

## Architecture Decision Records (ADRs)

- [docs/adr/0001-android-status-go-as-a-service.md](/docs/adr/0001-android-status-go-as-a-service.md): Android architecture where `status-go` runs in a separate Service process and the UI talks to it via Binder IPC.

## Top level architecture

This shows the flow from the UI all the way to the backend.

We do not use servers. [status-go](https://github.com/status-im/status-go) is what our app considers the backend and as such, it has it's own local databases to contain the user data.


```mermaid
flowchart LR
    qml["Frontend (QML)"] --> statusq(["StatusQ"])
    qml --> seaqt{{"nimqml-seaqt"}}
    seaqt --> nimqml{{"NimQML"}}
    nimqml --> nim["Middleware (Nim)"]
    nim --> statusgo{{"Backend (status-go)"}}
    nim --> nimstatusgo(["status-go Nim bindings"])
    nimstatusgo --> statusgo
    statusgo --> waku{{"Waku"}}
    statusgo --> providers[["Wallet providers"]]
    statusgo --> db[(Local Databases)]
    subgraph Legend
      direction LR
      box["Status Desktop code"]
      roundedbox(["In-repo Library"])
      hexagon{{"Out of repo libraries"}}
      barbox[["External providers"]]
    end
    click qml "https://github.com/status-im/status-app/tree/master/ui" "Link to the UI folder containing the QML code"
    click statusq "https://github.com/status-im/status-app/tree/master/ui/StatusQ" "Link to the StatusQ folder"
    click seaqt "https://github.com/status-im/nimqml-seaqt" "Link to the nimqml-seaqt repo"
    click nimqml "https://github.com/status-im/nimqml" "Link to the NimQML repo"
    click nim "https://github.com/status-im/status-app/tree/master/src" "Link to the Nim code"
    click statusgo "https://github.com/status-im/status-go" "Link to the Status-Go repo"
    click waku "https://github.com/waku-org" "Link to the Waku org"
    click nimstatusgo "https://github.com/status-im/status-app/tree/master/src/status_go.nim" "Link to the status-go Nim bindings"
```

## Standard Nim module

This is the way how most of our Nim modules are assembled.

```mermaid
flowchart LR
    ui(("UI")) --> view
    subgraph modulegroup ["Module"]
    view -->|"talks to the module through the interface"| interface
    interface --> module
    module["Module"] --> view["View"]
    module --> controller["Controller"]
    controller -->|"same as view"| interface
    end
    controller --> services(["Services"])
    services --> statusgo(("statusgo"))
```

## Nim Middleware architecture

Shows how the Nim modules are connected. The Nim modules are more often than not associated with the UI view they represent.

```mermaid
classDiagram
  Main "1"*--"*" ChatSection
  Main "1"*--"1" CommunitiesModule
  Main "1"*--"1" ActivityCenterModule
  Main "1"*--"1" ProfileSection
  Main "1"*--"n" OtherSections
  Main "1"*--"1" WalletSection
  ChatSection "1"*--"*" ChatContent
  ChatContent "1"*--"1" InputArea
  ChatContent "1"*--"1" MessagesModule
  ChatContent "1"*--"1" UsersModule
  WalletSection *-- Accounts
  WalletSection *-- Activity
  WalletSection *-- Collectibles
  WalletSection *-- Tokens
  WalletSection *-- Assets
  WalletSection *-- BuySellCrypto
  WalletSection *-- Networks
  WalletSection *-- Overview
  WalletSection *-- SavedAddresses
  WalletSection *-- SendModule
```

### Local message reads

The shared Nim `ThreadPool.start` dispatcher also runs synchronous network RPCs.
Message pages (including thread history), pinned messages, reactions, message
lookups, search, thread lists/summaries, and first-unseen-message reads use
`ThreadPool.startLocalRead` instead. It owns a lazily started native worker with
a FIFO queue, so exhausted network workers cannot prevent local history from
loading. Completion delivery still uses the existing queued Qt signals.

Submit tasks from the GUI thread. Only local, read-only operations belong on
this worker; do not enqueue network requests or mutations that can sync with
peers. Teardown drains accepted reads and joins the worker before sweeping
typed completions. A second `taskpools.Taskpool` on the GUI thread is not an
equivalent implementation: taskpools uses a thread-local submitting-worker
context that would be replaced by the second pool.

The contacts service also coalesces concurrent profile-information requests by
public key. All callers share the existing keyed completion event; success or
failure releases the key so a later request can refresh or retry. This avoids
occupying multiple general workers waiting for the same store-node lookup.
