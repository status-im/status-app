pragma Singleton

import QtQml

import StatusQ.Controls.Validators
import StatusQ.Core.Theme

QtObject {
    id: root

    readonly property var appState: ({
        startup: 0,
        appLoading: 1,
        main: 2,
        appEncryptionProcess: 3
    })

    enum CommunityFetchState {
        Idle,
        Fetching,
        Failed
    }

    readonly property QtObject chains: QtObject {
        readonly property int mainnetChainId: 1
        readonly property int sepoliaChainId: 11155111
        readonly property int optimismChainId: 10
        readonly property int optimismSepoliaChainId: 11155420
        readonly property int arbitrumChainId: 42161
        readonly property int arbitrumSepoliaChainId: 421614
        readonly property int baseChainId: 8453
        readonly property int baseSepoliaChainId: 84532
        readonly property int lineaMainnetChainId: 59144
        readonly property int lineaSepoliaChainId: 59141
        readonly property int unichainMainnetChainId: 130
        readonly property int unichainSepoliaChainId: 1301
        readonly property int katanaMainnetChainId: 747474
        readonly property int katanaBokutoChainId: 737373
        readonly property int inkMainnetChainId: 57073
        readonly property int inkSepoliaChainId: 763373
        readonly property int abstractMainnetChainId: 2741
        readonly property int abstractSepoliaChainId: 11124
        readonly property int zkSyncMainnetChainId: 324
        readonly property int zkSyncSepoliaChainId: 300
        readonly property int soneiumMainnetChainId: 1868
        readonly property int soneiumMinatoChainId: 1946
        readonly property int scrollMainnetChainId: 534352
        readonly property int scrollSepoliaChainId: 534351
        readonly property int blastMainnetChainId: 81457
        readonly property int blastSepoliaChainId: 168587773
        readonly property int robinhoodMainnetChainId: 4663
        readonly property int robinhoodTestnetChainId: 46630
        readonly property int hoodiChainId: 560048
        readonly property int binanceSmartChainMainnetChainId: 56
        readonly property int binanceSmartChainTestnetChainId: 97

        // Used for new chain advertisment
        readonly property var newChains: [chains.unichainMainnetChainId,
            chains.katanaMainnetChainId,
            chains.inkMainnetChainId,
            chains.abstractMainnetChainId,
            chains.zkSyncMainnetChainId,
            chains.soneiumMainnetChainId,
            chains.scrollMainnetChainId,
            chains.blastMainnetChainId,
            chains.robinhoodMainnetChainId
        ]
    }

    readonly property var predefinedKeycardData: ({
        wronglyInsertedCard: 1,
        hideKeyPair: 2,
        wrongSeedPhrase: 4,
        wrongPassword: 8,
        offerPukForUnlock: 16,
        disableSeedPhraseForUnlock: 32,
        useGeneralMessageForLockedState: 64,
        maxPUKReached: 128,
        copyFromAKeycardPartDone: 256,
        maxPairingSlotsReached: 512
    })

    readonly property var keycardSharedFlow: ({
        general: "General",
        factoryReset: "FactoryReset",
        setupNewKeycard: "SetupNewKeycard",
        setupNewKeycardNewSeedPhrase: "SetupNewKeycardNewSeedPhrase",
        setupNewKeycardOldSeedPhrase: "SetupNewKeycardOldSeedPhrase",
        importFromKeycard: "ImportFromKeycard",
        authentication: "Authentication",
        unlockKeycard: "UnlockKeycard",
        displayKeycardContent: "DisplayKeycardContent",
        renameKeycard: "RenameKeycard",
        changeKeycardPin: "ChangeKeycardPin",
        changeKeycardPuk: "ChangeKeycardPuk",
        changePairingCode: "ChangePairingCode",
        createCopyOfAKeycard: "CreateCopyOfAKeycard",
        migrateFromKeycardToApp: "MigrateFromKeycardToApp",
        migrateFromAppToKeycard: "MigrateFromAppToKeycard",
        sign: "Sign"
    })

    readonly property var keycardSharedState: ({
        keycardFlowStarted: "KeycardFlowStarted",
        biometrics: "Biometrics",
        noPCSCService: "NoPCSCService",
        noState: "NoState",
        pluginReader: "PluginReader",
        readingKeycard: "ReadingKeycard",
        insertKeycard: "InsertKeycard",
        keycardInserted: "KeycardInserted",
        createPin: "CreatePin",
        repeatPin: "RepeatPin",
        pinSet: "PinSet",
        pinVerified: "PinVerified",
        enterPin: "EnterPin",
        wrongPin: "WrongPin",
        enterPuk: "EnterPuk",
        wrongPuk: "WrongPuk",
        wrongKeychainPin: "WrongKeychainPin",
        maxPinRetriesReached: "MaxPinRetriesReached",
        maxPukRetriesReached: "MaxPukRetriesReached",
        maxPairingSlotsReached: "MaxPairingSlotsReached",
        factoryResetConfirmation: "FactoryResetConfirmation",
        factoryResetConfirmationDisplayMetadata: "FactoryResetConfirmationDisplayMetadata",
        factoryResetSuccess: "FactoryResetSuccess",
        keycardEmptyMetadata: "KeycardEmptyMetadata",
        keycardMetadataDisplay: "KeycardMetadataDisplay",
        keycardEmpty: "KeycardEmpty",
        keycardNotEmpty: "KeycardNotEmpty",
        keycardAlreadyUnlocked: "KeycardAlreadyUnlocked",
        notKeycard: "NotKeycard",
        unlockKeycardOptions: "UnlockKeycardOptions",
        unlockingKeycard: "UnlockingKeycard",
        unlockKeycardFailure: "UnlockKeycardFailure",
        unlockKeycardSuccess: "UnlockKeycardSuccess",
        wrongKeycard: "WrongKeycard",
        recognizedKeycard: "RecognizedKeycard",
        selectExistingKeyPair: "SelectExistingKeyPair",
        enterSeedPhrase: "EnterSeedPhrase",
        wrongSeedPhrase: "WrongSeedPhrase",
        seedPhraseAlreadyInUse: "SeedPhraseAlreadyInUse",
        seedPhraseDisplay: "SeedPhraseDisplay",
        seedPhraseEnterWords: "SeedPhraseEnterWords",
        keyPairMigrateSuccess: "KeyPairMigrateSuccess",
        keyPairMigrateFailure: "KeyPairMigrateFailure",
        migrateKeypairToApp: "MigrateKeypairToApp",
        migrateKeypairToKeycard: "MigrateKeypairToKeycard",
        migratingKeypairToApp: "MigratingKeypairToApp",
        migratingKeypairToKeycard: "MigratingKeypairToKeycard",
        enterPassword: "EnterPassword",
        wrongPassword: "WrongPassword",
        createPassword: "CreatePassword",
        confirmPassword: "ConfirmPassword",
        biometricsPasswordFailed: "BiometricsPasswordFailed",
        biometricsPinFailed: "BiometricsPinFailed",
        biometricsPinInvalid: "BiometricsPinInvalid",
        biometricsReadyToSign: "BiometricsReadyToSign",
        enterBiometricsPassword: "EnterBiometricsPassword",
        wrongBiometricsPassword: "WrongBiometricsPassword",
        enterKeycardName: "EnterKeycardName",
        renamingKeycard: "RenamingKeycard",
        keycardRenameSuccess: "KeycardRenameSuccess",
        keycardRenameFailure: "KeycardRenameFailure",
        changingKeycardPin: "ChangingKeycardPin",
        changingKeycardPinSuccess: "ChangingKeycardPinSuccess",
        changingKeycardPinFailure: "ChangingKeycardPinFailure",
        createPuk: "CreatePuk",
        repeatPuk: "RepeatPuk",
        changingKeycardPuk: "ChangingKeycardPuk",
        changingKeycardPukSuccess: "ChangingKeycardPukSuccess",
        changingKeycardPukFailure: "ChangingKeycardPukFailure",
        createPairingCode: "CreatePairingCode",
        changingKeycardPairingCode: "ChangingKeycardPairingCode",
        changingKeycardPairingCodeSuccess: "ChangingKeycardPairingCodeSuccess",
        changingKeycardPairingCodeFailure: "ChangingKeycardPairingCodeFailure",
        removeKeycard: "RemoveKeycard",
        sameKeycard: "SameKeycard",
        copyToKeycard: "CopyToKeycard",
        copyingKeycard: "CopyingKeycard",
        copyingKeycardFailure: "CopyingKeycardFailure",
        copyingKeycardSuccess: "CopyingKeycardSuccess",
        manageKeycardAccounts: "ManageKeycardAccounts",
        creatingAccountNewSeedPhrase: "CreatingAccountNewSeedPhrase",
        creatingAccountNewSeedPhraseSuccess: "CreatingAccountNewSeedPhraseSuccess",
        creatingAccountNewSeedPhraseFailure: "CreatingAccountNewSeedPhraseFailure",
        creatingAccountOldSeedPhrase: "CreatingAccountOldSeedPhrase",
        creatingAccountOldSeedPhraseSuccess: "CreatingAccountOldSeedPhraseSuccess",
        creatingAccountOldSeedPhraseFailure: "CreatingAccountOldSeedPhraseFailure",
        importingFromKeycard: "ImportingFromKeycard",
        importingFromKeycardSuccess: "ImportingFromKeycardSuccess",
        importingFromKeycardFailure: "ImportingFromKeycardFailure"
    })

    readonly property var keycardAnimations: ({})

    readonly property var keychain: ({
        errorType: {
            authentication: "authentication",
            keychain: "keychain"
        },
        storedValue: {
            store: "store",
            notNow: "notNow",
            never: "never"
        },
        dekPrefix: "dek:"
    })

    readonly property int chatSectionLeftColumnWidth: 304
    readonly property int chatSectionRightColumnWidth: 250

    // has to match section_item.nim#SectionType
    readonly property var appSection: ({
        chat: 2,
        community: 3,
        wallet: 1,
        profile: 4,
        qrCodeScanner: 5,
        communitiesPortal: 6,
        loadingSection: 7,
        swap: 8,
        market: 9,
        browser: 10,
        homePage: 0,
        dApp: 999
    })

    readonly property var appViewStackIndex: ({
        homePage: 0,
        chat: 1,
        community: 7,
        communitiesPortal: 2,
        wallet: 3,
        browser: 4,
        profile: 5,
        market: 6
    })

    readonly property var settingsSubsection: ({
        profile: 0,
        password: 1,
        contacts: 2,
        ensUsernames: 3,
        messaging: 4,
        wallet: 5,
        appearance: 6,
        language: 7,
        notifications: 8,
        syncingSettings: 9,
        browserSettings: 10,
        advanced: 11,
        about: 12,
        communitiesSettings: 13,
        keycardNew: 14,
        about_terms: 15,
        about_privacy: 16,
        privacyAndSecurity: 17,
        backupSettings: 18,
        logosNetworkSettings: 19,
        signout: 100,
        backUpSeed: 101
    })

    readonly property var walletSettingsSubsection: ({
        manageNetworks: 0,
        manageAccounts: 1,
        manageAssets: 2,
        manageCollectibles: 3,
        manageHidden: 4,
        manageAdvanced: 5
    })

    readonly property var currentUserStatus: ({
        unknown: 0,
        automatic: 1,
        doNotDisturb: 2,
        alwaysOnline: 3,
        inactive: 4
    })

    readonly property var onboarding: ({
        userImageWidth: 40,
        userImageHeight: 40,
        defaultPinAttempts: 3,
        defaultPukAttempts: 5
    })

    readonly property var onlineStatus: ({
        unknown: -1,
        inactive: 0,
        online: 1
    })

    readonly property var chatType: ({
        category: -1,
        unknown: 0,
        oneToOne: 1,
        publicChat: 2,
        privateGroupChat: 3,
        profile: 4,
        communityChat: 6
    })

    readonly property var profileType: ({
        regular: 0,
        self: 1,
        blocked: 2,
        bridged: 3
    })

    readonly property var memberRole: ({
        none: 0,
        owner: 1,
        admin: 4,
        tokenMaster: 5
    })

    readonly property var permissionType: ({
        none: 0,
        admin: 1,
        member: 2,
        read: 3,
        viewAndPost: 4,
        becomeTokenMaster: 5,
        becomeTokenOwner: 6
    })

    readonly property var messageContentType: ({
        newMessagesMarker: -3,
        fetchMoreMessagesButton: -2,
        chatIdentifier: -1,
        unknownContentType: 0,
        messageType: 1,
        stickerType: 2,
        statusType: 3,
        emojiType: 4,
        transactionType: 5,
        systemMessagePrivateGroupType: 6,
        imageType: 7,
        audioType: 8,
        communityInviteType: 9,
        gapType: 10,
        contactRequestType: 11,
        discordMessageType: 12,
        systemMessagePinnedMessage: 14,
        systemMessageMutualEventSent: 15,
        systemMessageMutualEventAccepted: 16,
        systemMessageMutualEventRemoved: 17,
        bridgeMessageType: 18
    })

    readonly property var messageModelRoles: ({
        responseToMessageWithId: 262
    })

    readonly property var contactType: ({
        nonContact: 0,
        contact: 1,
        contactRequestReceived: 2,
        contactRequestSent: 3
    })

    readonly property var trustStatus: ({
        unknown: 0,
        trusted: 1,
        untrustworthy: 2
    })

    readonly property var contactsPanelUsage: ({
        unknownPosition: -1,
        mutualContacts: 0,
        pendingContacts: 1,
        blockedContacts: 2,
        rejectedReceivedContactRequest: 3
    })

    readonly property var displayName: ({
        nameLengthMax: 20,
        nameLengthMin: 5
    })

    readonly property var keypair: ({
        nameLengthMax: 20,
        nameLengthMin: 1,
        type: {
            unknown: -1,
            profile: 0,
            seedImport: 1,
            privateKeyImport: 2,
            watchOnly: 3
        },
        operability: {
            nonOperable: "no",
            partiallyOperable: "partially",
            fullyOperable: "fully"
        },
        syncedFrom: {
            backup: "backup"
        }
    })

    readonly property QtObject validators: QtObject {
        readonly property list<StatusValidator> keypairName: [
            StatusValidator {
                name: "startsWithSpaceValidator"
                validate: function (t) { return !t.startsWith(" ") }
                errorMessage: qsTr("Key pair starting with whitespace are not allowed")
            },
            StatusMinLengthValidator {
                minLength: keypair.nameLengthMin
                errorMessage: qsTr("Key pair must be at least %n character(s)", "", keypair.nameLengthMin)
            },
            StatusRegularExpressionValidator {
                regularExpression: /^[\p{L}\p{M}\p{N}\-_ ]+$/
                errorMessage: errorMessages.alphanumericalExpandedRegExp
            }
        ]
    }

    readonly property QtObject settingsSection: QtObject {
        readonly property int itemSpacing: 10
        readonly property int radius: 8
        readonly property int itemHeight: 64

        readonly property QtObject notificationsBubble: QtObject {
            readonly property int previewAnonymous: 0
            readonly property int previewNameOnly: 1
            readonly property int previewNameAndMessage: 2
        }

        readonly property QtObject notifications: QtObject {
            readonly property string sendAlertsValue: "SendAlerts"
            readonly property string deliverQuietlyValue: "DeliverQuietly"
            readonly property string turnOffValue: "TurnOff"
        }

        readonly property QtObject exemptions: QtObject {
            readonly property int community: 0
            readonly property int oneToOneChat: 1
            readonly property int groupChat: 2
        }

        property string dotSepString: '<font size="3">  &#x2022; </font>'
    }

    readonly property var ephemeralNotificationType: ({
        normal: 0,
        success: 1,
        danger: 2
    })

    readonly property var translationsState: ({
        alpha: 0,
        beta: 1,
        stable: 2
    })

    readonly property var authenticationReason: ({
        enableBiometrics: "enable-biometrics",
        disableBiometrics: "disable-biometrics",
        enableStayLoggedIn: "enable-stay-logged-in",
        disableStayLoggedIn: "disable-stay-logged-in",
        migrateProfileEncryption: "migrate-profile-encryption",
        addAccount: "add-account",
        importKeypair: "import-keypair",
        syncDevice: "sync-device",
        signing: "signing"
    })

    readonly property var signingReason: ({
        communityTokens: "community-tokens",
        communitiesSignSharedAddresses: "communities-sign-shared-addresses",
        walletSend: "wallet-send",
        swap: "swap",
        walletConnect: "wallet-connect"
    })

    readonly property QtObject keycard: QtObject {
        readonly property int maxPinAttempts: 3
        readonly property int maxPukAttempts: 5

        readonly property QtObject general: QtObject {
            readonly property string purchasePage: "https://get.keycard.tech"
            readonly property int onboardingHeight: 460
            readonly property int imageWidth: 240
            readonly property int imageHeight: 240
            readonly property int seedPhraseWidth: 816
            readonly property int seedPhraseHeight: 228
            readonly property int enterSeedPhraseWordsWidth: 868
            readonly property int enterSeedPhraseWordsHeight: 60
            readonly property int keycardPinLength: 6
            readonly property int keycardPukLength: 12
            readonly property int keycardNameLength: keypair.nameLengthMax
            readonly property int keycardNameInputWidth: 448
            readonly property int keycardPukAdditionalSpacingOnEvery4Items: 4
            readonly property int keycardPukAdditionalSpacing: 32
            readonly property int seedPhraseCellWidth: 193
            readonly property int seedPhraseCellHeight: 60
            readonly property int seedPhraseCellNumberWidth: 24
            readonly property int pukCellWidth: 50
            readonly property int pukCellHeight: 60
            readonly property int popupWidth: 640
            readonly property int popupHeight: 500
            readonly property int popupBiggerHeight: 626
            readonly property int titleHeight: 60
            readonly property int messageHeight: 48
            readonly property int footerButtonsHeight: 44
            readonly property int loginInfoHeight1: 24
            readonly property int loginInfoHeight2: 44
        }

        readonly property QtObject keyPairType: QtObject {
            readonly property int unknown: -1
            readonly property int profile: 0
            readonly property int seedImport: 1
            readonly property int privateKeyImport: 2
        }

        readonly property QtObject shared: QtObject {
            readonly property int imageWidth: 240
            readonly property int imageHeight: 240
        }

        readonly property QtObject state: QtObject {
            readonly property string unknownReaderState: "unknown-reader-state"
            readonly property string noPCSC: "no-pcsc"
            readonly property string internalError: "internal-error"
            readonly property string noReadersFound: "no-readers-found"
            readonly property string readerConnectionError: "reader-connection-error"
            readonly property string waitingForReader: "waiting-for-reader"
            readonly property string waitingForCard: "waiting-for-card"
            readonly property string connectingCard: "connecting-card"
            readonly property string connectionError: "connection-error"
            readonly property string notKeycard: "not-keycard"
            readonly property string pairingError: "pairing-error"
            readonly property string emptyKeycard: "empty-keycard"
            readonly property string noAvailablePairingSlots: "no-available-pairing-slots"
            readonly property string blockedPIN: "blocked-pin"
            readonly property string blockedPUK: "blocked-puk"
            readonly property string factoryResetting: "factory-resetting"
            readonly property string ready: "ready"
            readonly property string authorized: "authorized"
            readonly property string cancelled: "cancelled"
            readonly property string untrustedKeycard: "untrusted-keycard"
        }

        readonly property QtObject flow: QtObject {
            readonly property string readKeycard: "read-keycard"
            readonly property string factoryReset: "factory-reset"
            readonly property string importSeedPhrase: "import-seed-phrase"
            readonly property string importNewKeyPair: "import-new-key-pair"
            readonly property string moveKeyPair: "move-key-pair"
            readonly property string moveProfileKeyPair: "move-profile-key-pair"
            readonly property string addKeyPairToStatus: "add-key-pair-to-status"
            readonly property string stopUsingKeycard: "stop-using-keycard"
            readonly property string stopUsingKeycardForProfile: "stop-using-keycard-for-profile"
            readonly property string startUsingProfileWithoutKeycard: "start-using-profile-without-keycard"
            readonly property string changePin: "change-pin"
            readonly property string setOrChangePuk: "set-or-change-puk"
            readonly property string rename: "rename"
            readonly property string unblockWithPuk: "unblock-with-puk"
            readonly property string unblockWithRecoveryPhrase: "unblock-with-recovery-phrase"

            readonly property string onboardingLoginWithKeycard: "onboarding-login-with-keycard"
            readonly property string onboardingImportNewKeyPair: "onboarding-import-new-key-pair"
            readonly property string onboardingImportSeedPhrase: "onboarding-import-seed-phrase"
        }
    }

    readonly property QtObject regularExpressions: QtObject {
        readonly property var alphanumerical: /^$|^[\p{L}\p{M}\p{N}]+$/
        // Adds space, dash, underscore and dot
        readonly property var alphanumericalExpanded: /^$|^[\p{L}\p{M}\p{N}\-_. ]+$/
        // Adds dash and underscore; words separated by a single space
        readonly property var alphanumericalExpanded1: /^[\p{L}\p{M}\p{N}\-_]+(?: [\p{L}\p{M}\p{N}\-_]+)*$/
        // Adds dash, underscore, dot space and ampersand
        readonly property var alphanumericalExpanded2: /^$|^[\p{L}\p{M}\p{N}\-_. &]+$/
        // Adds dash, underscore, dot, space, comma and ampersand
        readonly property var alphanumericalExpanded3: /^$|^[\p{L}\p{M}\p{N}\-_., &]+$/
        // Adds a newline (e.g. community description)
        readonly property var alphanumericalExpanded4: /^$|^[\p{L}\p{M}\p{N}\-_., &\r?\n]+$/
        readonly property var alphanumericalWithSpace: /^$|^[\p{L}\p{M}\p{N}\s]+$/
        readonly property var textWithEmoji: /^$|^[\x00-\x7F\p{L}\p{M}\p{N}\p{P}\p{S}\p{Z}\p{Cf}]+$/
        readonly property var asciiPrintable:         /^$|^[!-~]+$/
        readonly property var ascii:                  /^$|^[\x00-\x7F]+$/
        readonly property var capitalOnly: /^$|^[A-Z]+$/
        readonly property var numerical: /^$|^[0-9]+$/
        readonly property var emoji: /\ud83c\udff4(\udb40[\udc61-\udc7a])+\udb40\udc7f|(\ud83c[\udde6-\uddff]){2}|([\#\*0-9]\ufe0f?\u20e3)|(\u00a9|\u00ae|[\u203c\u2049\u20e3\u2122\u2139\u2194-\u2199\u21a9\u21aa\u231a\u231b\u2328\u23cf\u23e9-\u23fa\u24c2\u25aa\u25ab\u25b6\u25c0\u25fb-\u25fe\u2600-\u2604\u260e\u2611\u2614\u2615\u2618\u261d\u2620\u2622\u2623\u2626\u262a\u262e\u262f\u2638-\u263a\u2640\u2642\u2648-\u2653\u265f\u2660\u2663\u2665\u2666\u2668\u267b\u267e\u267f\u2692-\u2697\u2699\u269b\u269c\u26a0\u26a1\u26a7\u26aa\u26ab\u26b0\u26b1\u26bd\u26be\u26c4\u26c5\u26c8\u26ce\u26cf\u26d1\u26d3\u26d4\u26e9\u26ea\u26f0-\u26f5\u26f7-\u26fa\u26fd\u2702\u2705\u2708-\u270d\u270f\u2712\u2714\u2716\u271d\u2721\u2728\u2733\u2734\u2744\u2747\u274c\u274e\u2753-\u2755\u2757\u2763\u2764\u2795-\u2797\u27a1\u27b0\u27bf\u2934\u2935\u2b05-\u2b07\u2b1b\u2b1c\u2b50\u2b55\u3030\u303d\u3297\u3299]|\ud83c[\udc04\udccf\udd70\udd71\udd7e\udd7f\udd8e\udd91-\udd9a\udde6-\uddff\ude01\ude02\ude1a\ude2f\ude32-\ude3a\ude50\ude51\udf00-\udf21\udf24-\udf93\udf96\udf97\udf99-\udf9b\udf9e-\udff0\udff3-\udff5\udff7-\udfff]|\ud83d[\udc00-\udcfd\udcff-\udd3d\udd49-\udd4e\udd50-\udd67\udd6f\udd70\udd73-\udd7a\udd87\udd8a-\udd8d\udd90\udd95\udd96\udda4\udda5\udda8\uddb1\uddb2\uddbc\uddc2-\uddc4\uddd1-\uddd3\udddc-\uddde\udde1\udde3\udde8\uddef\uddf3\uddfa-\ude4f\ude80-\udec5\udecb-\uded2\uded5-\uded7\udedc-\udee5\udee9\udeeb\udeec\udef0\udef3-\udefc\udfe0-\udfeb\udff0]|\ud83e[\udd0c-\udd3a\udd3c-\udd45\udd47-\ude7c\ude80-\ude88\ude90-\udebd\udebf-\udec5\udece-\udedb\udee0-\udee8\udef0-\udef8])((\ud83c[\udffb-\udfff])?(\ud83e[\uddb0-\uddb3])?(\ufe0f?\u200d([\u2000-\u3300]|[\ud83c-\ud83e][\ud000-\udfff])\ufe0f?)?)*/g;
        readonly property var wholeNumbers: /^(0|[1-9][0-9]*)$/
        readonly property var positiveRealNumbers: /^(0|[1-9][0-9]*)([.,][0-9]+)?$/
    }

    readonly property QtObject errorMessages: QtObject {
        readonly property string alphanumericalRegExp: qsTr("Only letters and numbers allowed")
        readonly property string alphanumericalExpandedRegExp: qsTr("Only letters, numbers, underscores, periods, whitespaces and hyphens allowed")
        readonly property string alphanumericalExpanded1RegExp: qsTr("Invalid characters (letters and numbers, single whitespace, hyphens and underscores only)")
        readonly property string alphanumericalExpanded3RegExp: qsTr("Only letters, numbers, underscores, periods, commas, whitespaces and hyphens allowed")
        readonly property string alphanumericalWithSpaceRegExp: qsTr("Special characters are not allowed")
        readonly property string asciiRegExp: qsTr("Only letters, numbers and ASCII characters allowed")
        readonly property string emojRegExp: qsTr("Name is too cool (use letters and numbers, single whitespace, hyphens and underscores only)")
        readonly property string wholeNumbers: qsTr("Whole numbers only")
        readonly property string positiveRealNumbers: qsTr("Positive real numbers only")
    }

    readonly property var socialLinkType: ({
        custom: 0,
        twitter: 1,
        personalSite: 2,
        github: 3,
        youtube: 4,
        discord: 5,
        telegram: 6
    })

    readonly property int maxSocialLinkTextLength: 24

    readonly property var addAccountPopup: ({
        popupWidth: 480,
        contentHeight1: 554,
        itemHeight: 64,
        importPrivateKeyWarningHeight: 86,
        footerButtonsHeight: 44,
        keyPairNameMaxLength: 20,
        keyPairAccountNameMinLength: 1,
        stepperWidth: 242,
        keyPairType: {
            unknown: -1,
            profile: 0,
            seedImport: 1,
            privateKeyImport: 2
        },
        predefinedPaths: {
            custom: "m/44'",
            ethereum: "m/44'/60'/0'/0",
            ethereumLedger: "m/44'/60'/0'",
            ethereumLedgerLive: "m/44'/60'"
        },
        state: {
            noState: "NoState",
            main: "Main",
            selectMasterKey: "SelectMasterKey",
            enterSeedPhrase: "EnterSeedPhrase",
            enterSeedPhraseWord1: "EnterSeedPhraseWord1",
            enterSeedPhraseWord2: "EnterSeedPhraseWord2",
            enterPrivateKey: "EnterPrivateKey",
            enterKeypairName: "EnterKeypairName",
            displaySeedPhrase: "DisplaySeedPhrase",
            confirmAddingNewMasterKey: "ConfirmAddingNewMasterKey",
            confirmSeedPhraseBackup: "ConfirmSeedPhraseBackup"
        }
    })

    readonly property QtObject keypairImportPopup: QtObject {
        readonly property int popupWidth: 480
        readonly property int contentHeight: 626
        readonly property int footerButtonsHeight: 44
        readonly property string instructionsLabelForQr: qsTr("How to display the QR code on your other device")
        readonly property string instructionsLabelForEncryptedKey: qsTr("How to copy the encrypted key from your other device")

        readonly property QtObject mode: QtObject {
            readonly property int selectKeypair: 1
            readonly property int selectImportMethod: 2
            readonly property int importViaSeedPhrase: 3
            readonly property int importViaPrivateKey: 4
            readonly property int importViaQr: 5
            readonly property int exportKeypairQr: 6
        }

        readonly property QtObject state: QtObject {
            readonly property string noState: "NoState"
            readonly property string selectKeypair: "SelectKeypair"
            readonly property string selectImportMethod: "SelectImportMethod"
            readonly property string exportKeypair: "ExportKeypair"
            readonly property string importQr: "ImportQr"
            readonly property string importSeedPhrase: "ImportSeedPhrase"
            readonly property string importPrivateKey: "ImportPrivateKey"
            readonly property string displayInstructions: "DisplayInstructions"
        }
    }

    readonly property var localPairingAction: ({
        actionUnknown: 0,
        actionConnect: 1,
        actionPairingAccount: 2,
        actionSyncDevice: 3
    })

    readonly property var hiddenTokenLists: ({
        nativeList: "native",
        custom: "custom",
        community: "community"
    })

    enum LocalPairingState {
        Idle = 0,
        Transferring = 1,
        Error = 2,
        Finished = 3
    }

    readonly property var socialLinkPrefixesByType: [ // NB order must match the "socialLinkType" enum above
        "",
        "https://twitter.com/",
        "",
        "https://github.com/",
        "https://www.youtube.com/",
        "https://discordapp.com/users/",
        "https://t.me/"
    ]

    enum DiscordImportErrorCode {
        Unknown = 1,
        Warning = 2,
        Error = 3
    }

    readonly property int communityIdLength: 68

    readonly property int communityImported: 0
    readonly property int communityImportingInProgress: 1
    readonly property int communityImportingError: 2
    readonly property int communityImportingCanceled: 3

    readonly property int communityChatPublicAccess: 1
    readonly property int communityChatInvitationOnlyAccess: 2
    readonly property int communityChatOnRequestAccess: 3

    readonly property int maxNbDaysToFetch: 30
    readonly property int fetchRangeLast24Hours: 86400
    readonly property int fetchRangeLast2Days: 172800
    readonly property int fetchRangeLast3Days: 259200
    readonly property int fetchRangeLast7Days: 604800

    readonly property int limitLongChatText: 500
    readonly property int limitLongChatTextCompactMode: 1000

    readonly property int notificationPopupTTL: 5000

    readonly property string lightThemeName: "light"
    readonly property string darkThemeName: "dark"

    readonly property int notifyAllMessages: 0
    readonly property int notifyJustMentions: 1
    readonly property int notifyNone: 2


    readonly property string watchWalletType: "watch"
    readonly property string keyWalletType: "key"
    readonly property string seedWalletType: "seed"
    readonly property string generatedWalletType: "generated"

    readonly property string walletRootPath: "m/44'/60'/0'/0"


    readonly property var walletConnections: ({
        collectibles: "collectibles",
        blockchains: "blockchains",
        market: "market"
    })

    readonly property QtObject walletConstants: QtObject {
        readonly property string maxNumberOfAccountsTitle: qsTr("Limit of 20 accounts reached")
        readonly property string maxNumberOfAccountsContent: qsTr("Remove any account to add a new one.")

        readonly property string maxNumberOfKeypairsTitle: qsTr("Limit of 5 key pairs reached")
        readonly property string maxNumberOfKeypairsContent: qsTr("Remove key pair to add a new one.")

        readonly property string maxNumberOfWatchOnlyAccountsTitle: qsTr("Limit of 3 watched addresses reached")
        readonly property string maxNumberOfWatchOnlyAccountsContent: qsTr("Remove a watched address to add a new one.")

        readonly property string maxNumberOfSavedAddressesTitle: qsTr("Limit of 20 saved addresses reached")
        readonly property string maxNumberOfSavedAddressesContent: qsTr("Remove a saved address to add a new one.")
    }

    enum ConnectionStatus {
        Success = 0,
        Failure = 1,
        Retrying = 2,
        Unknown = 3
    }

    readonly property string defaultTokenIcon: "tokens/DEFAULT-TOKEN"

    readonly property string dummyText: "Dummy"

    // Transaction states
    readonly property int addressRequested: 1
    readonly property int declined: 2
    readonly property int addressReceived: 3
    readonly property int transactionRequested: 4
    readonly property int transactionDeclined: 5
    readonly property int pending: 6
    readonly property int confirmed: 7

    readonly property int maxTokens: 200

    readonly property string tokenKeyDelimiter: "-"
    readonly property string zeroAddress: "0x0000000000000000000000000000000000000000"
    readonly property string zeroAddress1: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

    readonly property string networkMainnet: "Mainnet"

    readonly property string ethToken: "ETH"
    readonly property string bnbToken: "BNB"
    readonly property string sntToken: "SNT"
    readonly property string sttToken: "STT"
    readonly property string usdcToken: "USDC"
    readonly property string gweiToken: "Gwei" // special "fake" token, added here to facilitate fee representation in locale

    readonly property string ethGroupKey: "eth-native"
    readonly property string bnbGroupKey: "bsc-native"
    readonly property string sntGroupKey: "status"
    readonly property string sttGroupKey: "status-test-token"
    readonly property string usdcGroupKeyEvm: "usd-coin"
    readonly property string usdcGroupKeyBsc: "usd-coin-bsc"
    readonly property string usdtGroupKeyEvm: "tether"
    readonly property string daiGroupKey: "dai"
    readonly property string aaveGroupKey: "aave"

    readonly property var rawDecimals: {
        "ETH": 18,
        "BNB": 18,
    }
    readonly property var gasTokenDecimals: {
        "ETH": 9,
        "BNB": 9,
    }

    // EIP-8037 TX_MAX_TOTAL_GAS_LIMIT (2^32 - 1); a transport bound, not a block fit.
    // Keep in sync with MaxTxGasAmount in src/app_service/service/eth/utils.nim.
    readonly property string maxTxGasAmount: "4294967295"
    // A custom gas amount above suggested * this factor gets a (non-blocking) warning.
    readonly property string highGasAmountWarningFactor: "2"

    readonly property var networkShortChainNames: ({
        mainnet: "eth",
        arbitrum: "arb1",
        optimism: "oeth",
        base: "base",
        linea: "linea",
        unichain: "unichain",
        katana: "katana",
        ink: "ink",
        aabstract: "abstract",
        zkSync: "zksync",
        soneium: "soneium",
        scroll: "scroll",
        blast: "blast",
        robinhood: "rhc",
        binanceSmartChain: "bsc"
    })

    readonly property var networkNames: ({
        mainnet: "Mainnet",
        hoodi: "Hoodi",
        sepolia: "Sepolia",
        arbitrum: "Arbitrum",
        sepoliaArbitrum: "Arbitrum Sepolia",
        optimism: "Optimism",
        sepoliaOptimism: "Optimism Sepolia",
        base: "Base",
        sepoliaBase: "Base Sepolia",
        linea: "Linea",
        sepoliaLinea: "Linea Sepolia",
        unichain: "Unichain",
        sepoliaUnichain: "Unichain Sepolia",
        katana: "Katana",
        bokutoKatana: "Katana Bokuto",
        ink: "Ink",
        sepoliaInk: "Ink Sepolia",
        aabstract: "Abstract",
        sepoliaAbstract: "Abstract Sepolia",
        zkSync: "ZKsync",
        sepoliaZkSync: "ZKsync Sepolia",
        soneium: "Soneium",
        minatoSoneium: "Soneium Minato",
        scroll: "Scroll",
        sepoliaScroll: "Scroll Sepolia",
        blast: "Blast",
        sepoliaBlast: "Blast Sepolia",
        robinhood: "Robinhood",
        testnetRobinhood: "Robinhood Testnet",
        binanceSmartChain: "BNB Smart Chain",
        testnetBinanceSmartChain: "BNB Smart Chain Testnet"
    })

    readonly property var networkExplorerLinks: ({
        etherscan: "https://etherscan.io",
        arbiscan: "https://arbiscan.io",
        optimism: "https://optimistic.etherscan.io",
        base: "https://basescan.org",
        linea: "https://lineascan.build",
        unichain: "https://unichain.blockscout.com",
        katana: "https://katanascan.com",
        ink: "https://explorer.inkonchain.com",
        aabstract: "https://abscan.org",
        zkSync: "https://explorer.zksync.io",
        soneium: "https://soneium.blockscout.com",
        scroll: "https://scrollscan.com",
        blast: "https://blastscan.io",
        robinhood: "https://robinhoodchain.blockscout.com",
        binanceSmartChain: "https://bscscan.com",
        hoodiEtherscan: "https://hoodi.etherscan.io",
        sepoliaEtherscan: "https://sepolia.etherscan.io",
        sepoliaArbiscan: "https://sepolia.arbiscan.io",
        sepoliaOptimism: "https://sepolia-optimism.etherscan.io",
        sepoliaBase: "https://sepolia.basescan.org",
        sepoliaLinea: "https://sepolia.lineascan.build",
        sepoliaUnichain: "https://unichain-sepolia.blockscout.com",
        bokutoKatana: "https://bokuto.katanascan.com",
        sepoliaInk: "https://explorer-sepolia.inkonchain.com",
        sepoliaAbstract: "https://sepolia.abscan.org",
        sepoliaZkSync: "https://sepolia.explorer.zksync.io",
        minatoSoneium: "https://soneium-minato.blockscout.com",
        sepoliaScroll: "https://sepolia.scrollscan.com",
        sepoliaBlast: "https://sepolia.blastscan.io",
        testnetRobinhood: "https://explorer.testnet.chain.robinhood.com",
        testnetBinanceSmartChain: "https://testnet.bscscan.com",
        addressPath: "address",
        txPath: "tx"
    })

    readonly property var openseaExplorerLinks: ({
        mainnetLink: "https://opensea.io",
        testnetLink: "https://testnets.opensea.io",
        ethereum: "ethereum",
        arbitrum: "arbitrum",
        optimism: "optimism",
        base: "base",
        linea: "linea",
        unichain: "unichain",
        katana: "katana",
        ink: "ink",
        aabstract: "abstract",
        zkSync: "zksync",
        soneium: "soneium",
        scroll: "scroll",
        blast: "blast",
        robinhood: "robinhood",
        binanceSmartChain: "binance-smart-chain",
        hoodiEthereum: "hoodi",
        sepoliaEthereum: "sepolia",
        sepoliaArbitrum: "arbitrum-sepolia",
        sepoliaOptimism: "optimism-sepolia",
        sepoliaBase: "base-sepolia",
        sepoliaLinea: "linea-sepolia"
    })

    readonly property string api_request: "api-request"
    readonly property string web3SendAsyncReadOnly: "web3-send-async-read-only"
    readonly property string web3DisconnectAccount: "web3-disconnect-account"

    readonly property string permission_web3: "web3"
    readonly property string permission_contactCode: "contact-code"

    readonly property string personal_sign: "personal_sign"
    readonly property string eth_sign: "eth_sign"
    readonly property string eth_signTypedData: "eth_signTypedData"
    readonly property string eth_signTypedData_v3: "eth_signTypedData_v3"

    readonly property string waku_sandbox: "waku.sandbox"
    readonly property string waku_test: "waku.test"
    readonly property string status_prod: "status.prod"
    readonly property string status_staging: "status.staging"

    readonly property int browserEthereumExplorerNone: 0
    readonly property int browserEthereumExplorerEtherscan: 1
    readonly property int browserEthereumExplorerEthplorer: 2
    readonly property int browserEthereumExplorerBlockchair: 3

    readonly property int repeatHeaderInterval: 2

    readonly property string deepLinkPrefix: 'status-app://'
    readonly property string externalStatusLink: 'status.app'
    readonly property string externalStatusLinkWithHttps: 'https://' + externalStatusLink
    readonly property string browserDefaultHomepage: externalStatusLinkWithHttps
    readonly property string communityLinkPrefix: externalStatusLinkWithHttps + '/c/'
    readonly property string userLinkPrefix: externalStatusLinkWithHttps + '/u/'
    readonly property string statusLinkPrefix: 'https://status.im/'
    readonly property string statusHelpLinkPrefix: `https://status.app/help/`
    readonly property string downloadLink: "https://status.im/get"
    readonly property string sendViaChatPrefix: '//send-via-personal-chat//'
    readonly property string statusDiscussPageUrl: 'https://discuss.status.app/'
    readonly property string statusThirdpartyServicesArticle: 'https://status.app/help/getting-started/privacy-with-status-third-parties'

    readonly property string statusSupportBotChatKey: typeof globalUtils !== "undefined"
                                                      ? globalUtils.getStatusSupportBotChatKey()
                                                      : ""

    readonly property int maxUploadFiles: 30
    readonly property double maxUploadFilesizeMB: 10
    readonly property int maxImgSizeBytes: maxUploadFilesizeMB * 1048576 /* 1 MB in bytes */

    readonly property int maxNumberOfPins: 3

    readonly property int maxThreadNameLength: 50

    readonly property string dataImagePrefix: "data:image"

    readonly property string ens_taken: "taken"
    readonly property string ens_taken_custom: "taken-custom"
    readonly property string ens_owned: "owned"
    readonly property string ens_available: "available"
    readonly property string ens_already_connected: "already-connected"
    readonly property string ens_connected: "connected"
    readonly property string ens_connected_dkey: "connected-different-key"

    readonly property string newBookmark: " "

    readonly property var ensState: {
        "taken": qsTr("Username already taken :("),
        "taken-custom": qsTr("Username doesn’t belong to you :("),
        "owned": qsTr("Continuing will connect this username with your chat key."),
        "available": qsTr("✓ Username available!"),
        "already-connected": qsTr("Username is already connected with your chat key and can be used inside Status."),
        "connected": qsTr("This user name is owned by you and connected with your chat key. Continue to set `Show my ENS username in chats`."),
        "connected-different-key": qsTr("Continuing will require a transaction to connect the username with your current chat key."),
    }

    readonly property var startupErrorType: ({
        unknownType: 0,
        importAccError: 1,
        setupAccError: 2,
        convertToRegularAccError: 3
    })

    readonly property string existingAccountError: "account already exists"
    readonly property string wrongDerivationPathError: "error parsing derivation path"

    readonly property int minPasswordLength: 10
    readonly property int maxPasswordLength: 100

    readonly property var suggestedRoutesExtraParamsProperties: ({
        packId: "packID",
        username: "username",
        publicKey: "publicKey"
    })

    enum SendType {
        Transfer,
        ENSRegister,
        ENSRelease,
        ENSSetPubKey,
        StickersBuy,
        Bridge,
        ERC721Transfer,
        ERC1155Transfer,
        Swap,
        CommunityBurn,
        CommunityDeployAssets,
        CommunityDeployCollectibles,
        CommunityDeployOwnerToken,
        CommunityMintTokens,
        CommunityRemoteBurn,
        CommunitySetSignerPubKey,
        Approve,
        Unknown
    }

    enum FeePriorityModeType {
        Normal,
        Fast,
        Urgent,
        Custom
    }

    enum ErrorType {
        SendAmountExceedsBalance,
        NoRoute,
        NoError
    }

    readonly property var routerErrorCodes: ({
        errInternal: "-1",
        errGeneric: "0",
        processor: {
            errFailedToParseBaseFee: "WPP-001",
            errFailedToParsePercentageFee: "WPP-002",
            errContractNotFound: "WPP-003",
            errNetworkNotFound: "WPP-004",
            errTokenNotFound: "WPP-005",
            errNoEstimationFound: "WPP-006",
            errNotAvailableForContractType: "WPP-007",
            errNoBonderFeeFound: "WPP-008",
            errContractTypeNotSupported: "WPP-009",
            errFromChainNotSupported: "WPP-010",
            errToChainNotSupported: "WPP-011",
            errTxForChainNotSupported: "WPP-012",
            errENSResolverNotFound: "WPP-013",
            errENSRegistrarNotFound: "WPP-014",
            errToAndFromTokensMustBeSet: "WPP-015",
            errCannotResolveTokens: "WPP-016",
            errPriceRouteNotFound: "WPP-017",
            errConvertingAmountToBigInt: "WPP-018",
            errNoChainSet: "WPP-019",
            errNoTokenSet: "WPP-020",
            errToTokenShouldNotBeSet: "WPP-021",
            errFromAndToChainsMustBeDifferent: "WPP-022",
            errFromAndToChainsMustBeSame: "WPP-023",
            errFromAndToTokensMustBeDifferent: "WPP-024",
            errTransferCustomError: "WPP-025",
            errERC721TransferCustomError: "WPP-026",
            errERC1155TransferCustomError: "WPP-027",
            errBridgeHopCustomError: "WPP-028",
            errBridgeCellerCustomError: "WPP-029",
            errSwapParaswapCustomError: "WPP-030",
            errENSRegisterCustomError: "WPP-031",
            errENSReleaseCustomError: "WPP-032",
            errENSPublicKeyCustomError: "WPP-033",
            errStickersBuyCustomError: "WPP-034",
            errContextCancelled: "WPP-035",
            errContextDeadlineExceeded: "WPP-036",
            errPriceTimeout: "WPP-037",
            errNotEnoughLiquidity: "WPP-038",
            errPriceImpactTooHigh: "WPP-039",
            errLiFiCustomError: "WPP-044",
            errRelayCustomError: "WPP-045",
            errNoRoutesFound: "WPP-046",
            errNoQuotesAvailable: "WPP-047",
            errSlippageExceeded: "WPP-048",
            errAmountTooLow: "WPP-049",
            errAmountTooHigh: "WPP-050",
            errUnsupportedCurrency: "WPP-051",
            errUnsupportedChain: "WPP-052"
        },
        router: {
            errENSRegisterRequiresUsernameAndPubKey: "WRR-001",
            errENSRegisterTestnetSTTOnly: "WRR-002",
            errENSRegisterMainnetSNTOnly: "WRR-003",
            errENSReleaseRequiresUsername: "WRR-004",
            errENSSetPubKeyRequiresUsernameAndPubKey: "WRR-005",
            errStickersBuyRequiresPackID: "WRR-006",
            errSwapRequiresToTokenID: "WRR-007",
            errSwapTokenIDMustBeDifferent: "WRR-008",
            errSwapAmountInAmountOutMustBeExclusive: "WRR-009",
            errSwapAmountInMustBePositive: "WRR-010",
            errSwapAmountOutMustBePositive: "WRR-011",
            errLockedAmountNotSupportedForNetwork: "WRR-012",
            errLockedAmountNotNegative: "WRR-013",
            errLockedAmountExceedsTotalSendAmount: "WRR-014",
            errLockedAmountLessThanSendAmountAllNetworks: "WRR-015",
            errDisabledChainFoundAmongLockedNetworks: "WRR-016",
            errENSSetPubKeyInvalidUsername: "WRR-017",
            errLockedAmountExcludesAllSupported: "WRR-018",
            errCannotCheckLockedAmounts: "WRR-019",
            errNotEnoughTokenBalance: "WR-001",
            errNotEnoughNativeBalance: "WR-002",
            errNativeTokenNotFound: "WR-003",
            errTokenNotFound: "WR-004",
            errNoBestRouteFound: "WR-005",
            errCannotCheckReceiverBalance: "WR-006",
            errLowAmountInForHopBridge: "WR-007",
            errNoPositiveBalance: "WR-008"
        }
    })

    enum FeesMode {
        Low,
        Medium,
        High
    }

    readonly property var txStatus: ({
        sending: "Sending",
        pending: "Pending",
        success: "Success",
        failed: "Failed"
    })

    enum AuthSignPurpose {
        General,
        AddAccount,
        AddAccountCustomPath
    }

    enum ComputeFeeErrorCode {
        Success,
        Infura,
        Balance,
        Revert,
        Other
    }

    enum ShowcaseVisibility {
        NoOne = 0,
        IdVerifiedContacts = 1,
        Contacts = 2,
        Everyone = 3
    }

    enum ShowcaseEntryType {
        Community = 0,
        Account = 1,
        Collectible = 2,
        Asset = 3
    }

    // refers to ContractTransactionStatus and DeployState in Nim
    enum ContractTransactionStatus {
        Failed,
        InProgress,
        Completed,
        None
    }

    enum ContactRequestState {
        None = 0,
        Mutual = 1,
        Sent = 2,
        Received = 3,
        Dismissed = 4
    }

    // these are in sync with app_service/common/types.nim
    enum TokenType {
        Native = 0,
        ERC20 = 1, // Asset
        ERC721 = 2, // Collectible
        ERC1155 = 3,
        Unknown = 4,
        ENS = 5
    }

    // in sync with app_service/service/token/token_lookup_cache.nim
    enum TokenLookupState {
        Resolved = 0,
        Pending = 1,
        Missing = 2
    }

    enum TokenPrivilegesLevel {
        Owner = 0,
        TMaster = 1,
        Community = 2
    }

    // Mirrors src/backend/activity.nim ActivityStatus
    enum TransactionStatus {
        Failed,
        Pending,
        Complete,
        Finalised
    }

    // Mirrors src/backend/activity.nim ActivityType
    enum TransactionType {
        Send,
        Receive,
        Buy,
        Swap,
        Bridge,
        ContractDeployment,
        Mint,
        Approve,
        ContractInteraction,
        Unknown,
        Sell,   // Not handled in backend yet
        Destroy // Not handled in backend yet
    }

    // To-do sync with backend
    enum TransactionTimePeriod {
        All,
        Today,
        Yesterday,
        ThisWeek,
        LastWeek,
        ThisMonth,
        LastMonth,
        Custom
    }

    readonly property var time: ({
        hoursIn7Days: 168,
        hoursInDay: 24,
        secondsIn7Days: 604800,
        secondsInHour: 3600
    })

    readonly property var walletSection: ({
        authenticationCanceled: "authenticationCanceled",
        // the route's gas changed, nothing was sent; keep in sync with RouteNeedsReviewError
        routeNeedsReview: "routeNeedsReview"
    })

    // list of symbols for which pngs are stored to avoid
    // accessing not existing resources and providing
    // default icon
    readonly property var knownTokenPNGs: [
        "aKNC", "AST", "BLT", "CND", "DNT", "EQUAD", "HEZ", "LOOM", "MTH",
        "PAY", "RCN", "SALT", "STRK", "TRST", "WBTC", "AKRO", "aSUSD", "BLZ",
        "COB", "DPY", "ETH2x-FLI", "HST", "LPT", "MTL", "PBTC", "RDN", "SAN",
        "STT", "TRX", "WETH", "0-native", "aLEND", "ATMChain", "BNB", "COMP",
        "DRT", "ETHOS", "HT", "LRC", "MYB", "PLR", "renBCH", "SNGLS", "STX",
        "TUSD", "WINGS", "0XBTC", "aLINK", "aTUSD", "BNT", "CUSTOM-TOKEN",
        "DTA", "ETH", "ICN", "MANA", "NEXO", "POE", "renBTC", "SNM", "SUB",
        "UBT", "WTC", "1ST", "aMANA", "aUSDC", "BQX", "CVC", "EDG", "EVX",
        "ICOS", "MCO", "NEXXO", "POLY", "REN", "SNT", "SUPR", "UKG", "XAUR",
        "aBAT", "AMB", "aUSDT", "BRLN", "DAI", "EDO", "FUEL", "IOST", "MDA",
        "NMR", "POWR", "renZEC", "SNX", "SUSD", "UNI", "XPA", "ABT", "aMKR",
        "aWBTC", "BTM", "DATA", "EKG", "FUN", "KDO", "MET", "NPXS", "PPP",
        "REP", "SOCKS", "TAAS", "UPP", "XRL", "aBUSD", "AMPL", "aYFI", "BTU",
        "DAT", "EKO", "FXC", "KIN", "MFG", "OGN", "PPT", "REQ", "SPANK",
        "TAUD", "USDC", "XUC", "ABYSS", "ANT", "aZRX", "CDAI", "DCN", "ELF",
        "GDC", "KNC", "MGO", "OMG", "PT", "RHOC", "SPIKE", "TCAD", "USDS",
        "ZRX", "aDAI", "APPC", "BAL", "CDT", "DEFAULT-TOKEN", "EMONA", "GEN",
        "Kudos", "MKR", "OST", "QKC", "RLC", "SPN", "TGBP", "USDT", "ZSC",
        "aENJ", "aREN", "BAM", "Centra", "DGD", "ENG", "GNO", "LEND", "MLN",
        "OTN", "QRL", "ROL", "STORJ", "TKN", "VERI", "AE", "aREP", "BAND",
        "CFI", "DGX", "ENJ", "GNT", "LINK", "MOC", "PAXG", "QSP", "R",
        "STORM", "TKX", "VIB", "aETH", "aSNX", "BAT", "CK", "DLT", "EOS",
        "GRID", "LISK", "MOD", "PAX", "RAE", "SAI", "ST", "TNT", "WABI",
        "EURC"
    ]

    function tokenIcon(symbol, useDefault=true) {
        if (!symbol) {
            return ""
        }
        let tmpSymbol = symbol
        let index = symbol.indexOf(" (EVM)")
        if (index === -1) {
            index = symbol.indexOf(" (BSC)")
        }
        if (index !== -1) {
            tmpSymbol = symbol.substring(0, index)
        }

        if (!!tmpSymbol && knownTokenPNGs.indexOf(tmpSymbol) !== -1)
            return Assets.png("tokens/" + tmpSymbol)

        if (useDefault)
            return Assets.png(root.defaultTokenIcon)
        return ""
    }

    function isDefaultTokenIcon(url) {
        return url.indexOf(root.defaultTokenIcon) !== -1
    }

    enum RecipientAddressObjectType {
        Address, // Just a string with the address information / default
        Account, // Wallet account object
        SavedAddress, // Saved addresses object
        RecentsAddress // Recent addresses object got from transactions history
    }

    // Message outgoing status
    readonly property var messageOutgoingStatus: ({
        sending: "sending",
        sent: "sent",
        delivered: "delivered",
        expired: "expired",
        failedResending: "failedResending"
    })

    readonly property var appTranslatableConstants: ({
        loginAccountsListAddNewUser: "LOGIN-ACCOUNTS-LIST-ADD-NEW-USER",
        loginAccountsListAddExistingUser: "LOGIN-ACCOUNTS-LIST-ADD-EXISTING-USER",
        loginAccountsListLostKeycard: "LOGIN-ACCOUNTS-LIST-LOST-KEYCARD",
        addAccountLabelNewWatchOnlyAccount: "LABEL-NEW-WATCH-ONLY-ACCOUNT",
        addAccountLabelWatchOnlyAccount: "LABEL-WATCH-ONLY-ACCOUNT",
        addAccountLabelExisting: "LABEL-EXISTING",
        addAccountLabelImportNew: "LABEL-IMPORT-NEW",
        addAccountLabelOptionAddNewMasterKey: "LABEL-OPTION-ADD-NEW-MASTER-KEY",
        addAccountLabelOptionAddWatchOnlyAcc: "LABEL-OPTION-ADD-WATCH-ONLY-ACC",
        keycardAccountNameOfUnknownWalletAccount: "KEYCARD-ACCOUNT-NAME-OF-UNKNOWN-WALLET-ACCOUNT",
        communityTokenTxErrorFailedToStart: "COMMUNITY-TOKEN-TX-ERROR-FAILED-TO-START",
        communityTokenTxErrorNoAccount: "COMMUNITY-TOKEN-TX-ERROR-NO-ACCOUNT",
        communityTokenTxErrorFailedToPrepare: "COMMUNITY-TOKEN-TX-ERROR-FAILED-TO-PREPARE",
        communityTokenTxErrorFailedToSend: "COMMUNITY-TOKEN-TX-ERROR-FAILED-TO-SEND",
        communityTokenTxErrorSigningIncomplete: "COMMUNITY-TOKEN-TX-ERROR-SIGNING-INCOMPLETE",
        communityTokenTxErrorFailedToPrepareSigning: "COMMUNITY-TOKEN-TX-ERROR-FAILED-TO-PREPARE-SIGNING"
    })

    enum CommunitySettingsSections {
        Overview,
        Members,
        Permissions,
        MintTokens,
        Airdrops
    }

    enum CommunityMembershipSubSections {
        Members,
        MembershipRequests,
        RejectedMembers,
        BannedMembers
    }

    enum CommunityMembershipRequestState {
        None = 0,
        Pending,
        Rejected,
        Accepted,
        Canceled,
        AcceptedPending,
        RejectedPending,
        AwaitingAddress,
        Banned,
        Kicked,
        BannedPending,
        UnbannedPending,
        KickedPending,
        Unbanned,
        BannedWithAllMessagesDelete
    }

    readonly property var walletAccountColors: ({
        primary: "primary",
        purple: "purple",
        orange: "orange",
        army: "army",
        turquoise: "turquoise",
        sky: "sky",
        yellow: "yellow",
        pink: "pink",
        copper: "copper",
        camel: "camel",
        magenta: "magenta",
        yinYang: "yinYang",
        undefinedAccount: "undefined"
    })

    enum MutingVariations {
        For15min = 1,
        For1hr = 2,
        For8hr = 3,
        For1week = 4,
        TillUnmuted = 5,
        For1min = 6,
        Unmuted = 7,
        For24hr = 8
    }

    enum LinkPreviewType {
        NoPreview = 0,
        Standard = 1,
        StatusContact = 2,
        StatusCommunity = 3,
        StatusCommunityChannel = 4
    }

    enum StandardLinkPreviewType {
        Link = 0,
        Image = 1
    }

    enum UrlUnfurlingMode {
        UrlUnfurlingModeAlwaysAsk = 1,
        UrlUnfurlingModeEnableAll = 2,
        UrlUnfurlingModeDisableAll = 3
    }

    enum RequestToJoinState {
        None = 0,
        InProgress = 1,
        Requested = 2
    }

    enum CommunityMemberReevaluationStatus {
        None = 0,
        InProgress = 1,
        Done = 2
    }

    readonly property var swap: ({
        paraswapName: "Velora",
        paraswapIcon: "paraswap",
        paraswapHostname: "app.velora.xyz",
        paraswapUrl: "https://www.velora.xyz/",
        paraswapV5ApproveContractAddress: "0x216B4B4Ba9F3e719726886d34a177484278Bfcae",
        paraswapV5SwapContractAddress: "0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57",
        paraswapV6_2ContractAddress: "0x6a000f20005980200259b80c5102003040001068",
        paraswapTermsAndConditionUrl: "https://www.velora.xyz/terms/terms-of-use",
        lifiName: "LI.FI",
        lifiIcon: "lifi",
        lifiHostname: "li.fi",
        lifiUrl: "https://li.fi/",
        lifiTermsAndConditionUrl: "https://li.fi/legal/terms-and-conditions/",
        lifiContractAddress: "0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE",
        relayName: "Relay",
        relayIcon: "relay",
        relayHostname: "relay.link",
        relayUrl: "https://relay.link/",
        relayTermsAndConditionUrl: "https://relay.link/terms",
        paraswapProcessorName: "Paraswap",
        lifiProcessorName: "LiFi",
        relayProcessorName: "Relay",
        routeOrderBestReturn: "RECOMMENDED",
        routeOrderFastest: "FASTEST",
        routeOrderLowestFee: "CHEAPEST"
    })

    // Mirrors src/app_service/service/transaction/service.nim -> EstimatedTime
    enum TransactionEstimatedTime {
        Unknown = 0,
        LessThanThirtySecs,
        LessThanOneMin,
        LessThanTwoMins,
        LessThanThreeMins,
        LessThanFourMins,
        LessThanFiveMins,
        MoreThanFiveMins
    }

    readonly property string navigationMetric: "navigation"

    enum DAppConnectors {
        WalletConnect = 1,
        StatusConnect = 2
    }

    property var dappImageByType: [
        "",
        Assets.svg("walletconnect"),
        Assets.png("status-logo")
    ]

    enum LimitWarning {
        Accounts,
        Keypairs,
        WatchOnlyAccounts,
        SavedAddresses
    }

    readonly property var rpcProviderTypes: ({
        embeddedEthRpcProxy: "embedded-eth-rpc-proxy",
        embeddedDirect: "embedded-direct",
        user: "user"
    })

    readonly property var rpcProviderAuthTypes: ({
        noAuth: "no-auth",
        basicAuth: "basic-auth",
        tokenAuth: "token-auth",
        puzzleAuth: "puzzle-auth"
    })

    readonly property int maxActiveNetworks: 5

    readonly property int maxEmojiReactionsPerMessage: 20

    enum BackupImportState {
        None,
        InProgress,
        Completed
    }

    readonly property var keycardChannelState: ({
        idle: "idle",
        waitingForKeycard: "waiting-for-keycard",
        reading: "reading",
        error: "error",
        notSupported: "not-supported",
        notAvailable: "not-available"
    })

    readonly property string bugReportUrl: "https://github.com/status-im/status-app/issues/new?template=bug.md"
}
