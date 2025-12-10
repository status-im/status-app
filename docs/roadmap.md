# Status Roadmap

## Table of Contents
- [Status Roadmap](#status-roadmap)
  - [Table of Contents](#table-of-contents)
  - [2026 H1](#2026-h1)
    - [2.38](#238)
      - [Features](#features)
    - [2.39](#239)
      - [Features](#features-1)
  - [2025 H2](#2025-h2)
    - [2.35](#235)
      - [Features](#features-2)
    - [2.36](#236)
      - [Features](#features-3)
    - [2.37](#237)
      - [Features](#features-4)

## 2026 H1

### 2.38

Release Epic: https://github.com/status-im/status-desktop/issues/19509

Estimated release: Early February

#### Features

- [Mobile feature parity](https://github.com/status-im/status-desktop/issues/19530)
  - Includes:
    - [Keycard support](https://github.com/status-im/status-app/issues/19531): In Progress ⏳🟩🟩🟩⬜⬜ 50%
    - [Push Notifications](https://github.com/status-im/status-app/issues/19532)
    - [Deep Links Support](https://github.com/status-im/status-app/issues/19533)
    - [QR Code scanning](https://github.com/status-im/status-app/issues/19534)
    - [UI Zoom setting](https://github.com/status-im/status-app/issues/18265)
- [Mobile Dapp Browser](https://github.com/status-im/status-desktop/issues/19535)
  - In Progress ⏳
- Polish [Desktop Dapp Browser](https://github.com/status-im/status-desktop/issues/19246)
  - [FURPS](/docs/FURPS/dapp-browser.md)
  - In Progress ⏳ 🟩🟩🟩⬜⬜ 68%
- [Privacy mode](https://github.com/status-im/status-desktop/issues/17619)
  - [FURPS](/docs/FURPS/privacy-mode.md)
  - In Progress ⏳ 🟩🟩🟩🟩⬜ 88%
- [Improve Token List and Support custom tokens](https://github.com/status-im/status-desktop/issues/19517)
  - In Progress ⏳
  - Merged. Testing and fixing is in progress
- [Chat Input Field UX Improvements](https://github.com/status-im/status-desktop/issues/19524)
- [Activity Center revamp](https://github.com/status-im/status-app/issues/18516)
  - In Progress ⏳ 🟩🟨⬜⬜⬜ 33%
- [Unified Adaptive Navigation System](https://github.com/status-im/status-desktop/issues/19458)
- [Standardized approach for Popups / Menus / Dropdowns](https://github.com/status-im/status-desktop/issues/19493)
- [Color System Revamp](https://github.com/status-im/status-desktop/issues/19455) - Improved Dark Mode & Updated Palettes
- [Nimbus Verification Proxy](https://github.com/status-im/status-desktop/issues/19538)
- [Memory and Performance improvements](https://github.com/status-im/status-desktop/issues/18296)
  - No provided FURPS at the moment as this is mostly about profiling and fixing issues found.
  - In Progress ⏳ 🟩🟩🟩⬜⬜ 64%
- [Private Transactions POC](https://github.com/status-im/status-desktop/issues/19539)
- [Backend refactor](https://github.com/status-im/status-go/issues/6435) 
  - Runs parallel to other features and doesn't need to be shipped to any particular milestones
  - No API changes are expected until the Chat SDK is integrated
  - [Roadmap, Documentation and FURPS](https://zealous-polka-dc7.notion.site/Backend-Refactoring-2078f96fb65c80d8954ae8fc651b3a33)
  - In Progress ⏳ 🟩🟩🟨⬜⬜ 55% (estimated progress as not all subtasks are created)

### 2.39

Release Epic: https://github.com/status-im/status-desktop/issues/19529

Estimated release: Mid March

#### Features

- [Full SDS integration](https://github.com/logos-messaging/pm/issues/194)
  - Enabling of the SDS wrapping feature flag
  - Breaking change for people in 2.36 or lower (first supported release is 2.37)
- News Feed on Waku
- File sending over Codex
  - Dependant on Codex being available in Light mode for mobile and having a C library
- [UI modularization](https://github.com/status-im/status-desktop/issues/17872)
  - [FURPS](/docs/FURPS/ui-modularization.md)
  - In Progress ⏳ 🟩⬜⬜⬜⬜ 27%
- Keycard Shell Integration
- Private Transactions
  - Follow-up of [Private Transactions POC](https://github.com/status-im/status-desktop/issues/19539)
  - Enabling of the feature flag
- [Ethereum Follow Protocol](https://github.com/status-im/status-desktop/issues/18685)
  - In Progress ⏳ 🟨⬜⬜⬜⬜ 10%


## 2025 H2

### 2.35

Release Epic: https://github.com/status-im/status-app/issues/17966

#### Features

- [QT6 migration](https://github.com/status-im/status-app/issues/17622)
  - No provided FURPS at the moment
    - This is about maintaing the same level of quality as with QT5 but with QT6 instead.
  - Done ✅ 🟩🟩🟩🟩🟩 100%
- [Tablet Build](https://github.com/status-im/status-app/issues/17941)
  - [FURPS](/docs/FURPS/tablet-build.md)
  - Done ✅ 🟩🟩🟩🟩🟩 100%
- [Jump to screen (Shell)](https://github.com/status-im/status-app/issues/17971)
  - [FURPS](/docs/FURPS/jump-to-screen-shell.md)
  - Done ✅ 🟩🟩🟩🟩🟩 100%
- [Backup user data locally](https://github.com/status-im/status-app/issues/18106)
  - [FURPS](/docs/FURPS/local-user-backups.md)
  - Done ✅ 🟩🟩🟩🟩🟩 100%

### 2.36

Release Epic: https://github.com/status-im/status-app/issues/18029

Estimated release: End of November

#### Features

- [Mobile build](https://github.com/status-im/status-app/issues/18082)
  - [FURPS](/docs/FURPS/mobile-build.md)
  - Progress is also inherited from the Tablet Epic above
  - In Progress ⏳ 🟩🟩🟩🟩⬜ 83%
- MVP [Dapp Browser](https://github.com/status-im/status-desktop/issues/19246)
  - [FURPS](/docs/FURPS/dapp-browser.md)
  - Done ✅ 🟩🟩🟩🟩🟩 100%
- [Local Backup finishing touches](https://github.com/status-im/status-desktop/issues/18583)
  - Done ✅ 🟩🟩🟩🟩🟩 100%
- [Opt-in Messages local backup](https://github.com/status-im/status-app/issues/18527)
  - Done ✅ 🟩🟩🟩🟩🟩 100%
- [Opt-in Messages Sync during local pairing](https://github.com/status-im/status-app/issues/18892)
  - Done ✅ 🟩🟩🟩🟩🟩 100%
- [External Activity fetching](https://github.com/status-im/status-app/issues/17188)
  - Done ✅ 🟩🟩🟩🟩🟩 100%
- [Translation initiative](https://github.com/status-im/status-desktop/issues/18293)
  - Done ✅ 🟩🟩🟩🟩🟩 100%
- [Full Emoji list in Reactions](https://github.com/status-im/status-desktop/issues/18766)
  - Done ✅ 🟩🟩🟩🟩🟩 100%


### 2.37

Release Epic: https://github.com/status-im/status-app/issues/18528

Small end of year release.

Estimated release: Early January

#### Features

- Followed list from [Ethereum Follow Protocol](https://github.com/status-im/status-desktop/issues/18685)
  - Done ✅ 🟩🟩🟩🟩🟩 100%
- [New translations](https://github.com/status-im/status-desktop/issues/19512)
  - In Progress ⏳
- First phase of [SDS](https://github.com/logos-messaging/pm/issues/194)
  - In Progress ⏳
  - Support for SDS message unwrapping
  - Planned support for SDS message wrapping (full support) in 2.39
