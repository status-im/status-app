import AppLayouts.Chat.popups

import shared.stores as SharedStores

PinnedMessagesPopup {
    id: root

    required property SharedStores.RootStore sharedRootStore

    // Unfurling related data:
    gifUnfurlingEnabled: root.sharedRootStore.gifUnfurlingEnabled
    neverAskAboutUnfurlingAgain: root.sharedRootStore.neverAskAboutUnfurlingAgain

    // Unfurling related requests:
    onSetNeverAskAboutUnfurlingAgain: neverAskAgain => root.sharedRootStore.setNeverAskAboutUnfurlingAgain(neverAskAgain)
    onPinMessageRequested: messageId => root.messageStore.pinMessage(messageId)
    onUnpinMessageRequested: messageId => root.messageStore.unpinMessage(messageId)
    onJumpToMessageRequested: messageId => root.messageStore.messageModule.jumpToMessage(messageId)
}
