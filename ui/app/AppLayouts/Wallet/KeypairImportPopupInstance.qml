import shared.popups.keypairimport

// Loaded by URL (see WalletLayout), so KeypairImportPopup is not part of the wallet's type closure
KeypairImportPopup {
    id: root

    required property var keypairImportModule

    store.keypairImportModule: root.keypairImportModule
}
