import AppLayouts.Profile.popups
import AppLayouts.Profile.stores as ProfileStores

import utils

BackupSeedModal {
    id: root

    required property ProfileStores.PrivacyStore privacyStore
    required property ProfileStores.ProfileStore profileStore

    mnemonic: root.privacyStore.getMnemonic()
    onBackupSeedphraseFinished: function(removeSeedphrase) {
        if (removeSeedphrase)
            root.privacyStore.removeMnemonic()
        root.profileStore.setUserDeclinedBackupBanner() // remove the banner
        Global.displaySuccessToastMessage(removeSeedphrase ? qsTranslate("Popups", "Recovery phrase permanently removed from Status application storage")
                                                           : qsTranslate("Popups", "You backed up your recovery phrase. Access it in Settings"))
    }
}
