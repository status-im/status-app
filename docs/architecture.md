
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
    nim --> nimstatusgo{{"nim-status-go"}}
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
    click nimstatusgo "https://github.com/status-im/nim-status-go" "Link to nim-status-go repo"
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
