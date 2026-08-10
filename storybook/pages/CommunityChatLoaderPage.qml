import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import utils

import shared.stores as SharedStores
import shared.stores.send as SendStores

import AppLayouts.stores as AppStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Communities.stores as CommunitiesStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.stores.Messaging as MessagingStores

import mainui.adaptors
import mainui.sectionLoaders

import Models
import Storybook

// Exercises the real CommunityChatLoader against a fully configurable mock
// community (CommunitySectionMock): membership/join state, member role,
// categories, private channels and their members, token permissions and
// scale knobs for load benchmarks. Refresh recreates the whole loader.
SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    // With the extra "profile-exit" positional argument the app quits shortly
    // after the section loads, so an attached qmlprofiler saves its trace on
    // clean exit (storybook's CLI parser rejects unknown --options)
    readonly property bool profileExitMode: Qt.application.arguments.indexOf("profile-exit") >= 0

    // Benchmark configs are scriptable the same way: extra "key=value"
    // positionals override the knob defaults, e.g.
    //   Storybook CommunityChatLoader profile-exit members=5000 channels=20
    function argValue(name, fallback) {
        for (const arg of Qt.application.arguments) {
            if (arg.indexOf(name + "=") === 0)
                return parseInt(arg.substring(name.length + 1))
        }
        return fallback
    }

    Timer {
        id: profilerExitTimer
        interval: 4000
        onTriggered: Qt.exit(0)
    }

    QtObject {
        id: d

        property double loadStartTime: 0

        readonly property var joinStates: [
            { name: "Joined member", joined: true, banned: false, gated: true, requestState: Constants.RequestToJoinState.None, ownerOffline: false },
            { name: "Not joined — token gated", joined: false, banned: false, gated: true, requestState: Constants.RequestToJoinState.None, ownerOffline: false },
            { name: "Request pending", joined: false, banned: false, gated: true, requestState: Constants.RequestToJoinState.Requested, ownerOffline: false },
            { name: "Banned", joined: false, banned: true, gated: true, requestState: Constants.RequestToJoinState.None, ownerOffline: false },
            { name: "Owner offline (rejoin)", joined: false, banned: false, gated: true, requestState: Constants.RequestToJoinState.None, ownerOffline: true }
        ]

        readonly property var memberRoles: [
            { name: "Regular member", role: Constants.memberRole.none },
            { name: "Admin", role: Constants.memberRole.admin },
            { name: "Owner", role: Constants.memberRole.owner },
            { name: "Token master", role: Constants.memberRole.tokenMaster }
        ]

        function applyConfig() {
            const joinState = joinStates[ctrlJoinState.currentIndex]
            mock.joined = joinState.joined
            mock.amIBanned = joinState.banned
            mock.requiresTokenPermissionToJoin = joinState.gated
            mock.requestToJoinState = joinState.requestState
            mock.isWaitingOnNewCommunityOwnerToConfirmRequestToRejoin = joinState.ownerOffline
            mock.memberRole = memberRoles[ctrlRole.currentIndex].role

            mock.name = "Mock Community"
            mock.image = ModelsData.icons.status
            mock.membersCount = ctrlMembers.value
            mock.categoriesCount = ctrlCategories.value
            mock.channelsPerCategory = ctrlChannels.value
            mock.uncategorizedChannelsCount = 2
            mock.privateChannelsPerCategory = Math.min(ctrlPrivate.value, ctrlChannels.value)
            mock.privateChannelMembersCount = ctrlPrivateMembers.value
            mock.messagesPerChannel = ctrlMessages.value
            mock.canViewPrivateChannels = ctrlCanViewPrivate.checked
            mock.canPostInPrivateChannels = ctrlCanViewPrivate.checked
            mock.tokenCriteriaMet = ctrlCriteriaMet.checked
            mock.allTokenRequirementsMet = ctrlCriteriaMet.checked
        }
    }

    CommunitySectionMock { id: mock }

    // Non-visual store mocks (typed via the storybook stubs)
    AppStores.RootStore { id: appRootStoreMock }
    AppStores.ContactsStore { id: contactsStoreMock }
    AppStores.AccountSettingsStore {
        id: accountSettingsStoreMock
        showUsersList: ctrlMembersPanel.checked
    }
    AppStores.FeatureFlagsStore { id: featureFlagsStoreMock }
    SharedStores.RootStore { id: sharedRootStoreMock }
    SharedStores.CurrenciesStore { id: currenciesStoreMock }
    SharedStores.CommunityTokensStore { id: communityTokensStoreMock }
    SharedStores.NetworkConnectionStore { id: networkConnectionStoreMock }
    SharedStores.NetworksStore { id: networksStoreMock }
    SendStores.TransactionStore { id: transactionStoreMock }
    WalletStores.TokensStore { id: tokensStoreMock }
    WalletStores.WalletAssetsStore { id: walletAssetsStoreMock }
    ProfileStores.AdvancedStore { id: advancedStoreMock }
    CommunitiesStores.CommunitiesStore { id: communitiesStoreMock }
    MessagingStores.MessagingRootStore { id: messagingRootStoreMock }
    ChatStores.CreateChatPropertiesStore { id: createChatPropertiesStoreMock }
    ContactsModelAdaptor {
        id: contactsAdaptorMock
        allContacts: ListModel {}
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        // Hidden shared popup loaders the loader API requires
        Item {
            visible: false
            Loader { id: emojiPopupLoaderMock; active: false }
            Loader { id: stickersPopupLoaderMock; active: false }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.padding
            color: Theme.palette.statusAppLayout.backgroundColor
            border.color: Theme.palette.baseColor2

            Loader {
                id: harness
                anchors.fill: parent
                anchors.margins: 1
                active: false

                sourceComponent: CommunityChatLoader {
                    active: true

                    rootStore: appRootStoreMock
                    contactsStore: contactsStoreMock
                    accountSettingsStore: accountSettingsStoreMock
                    featureFlagsStore: featureFlagsStoreMock
                    sharedRootStore: sharedRootStoreMock
                    currencyStore: currenciesStoreMock
                    communityTokensStore: communityTokensStoreMock
                    networkConnectionStore: networkConnectionStoreMock
                    networksStore: networksStoreMock
                    transactionStore: transactionStoreMock
                    tokensStore: tokensStoreMock
                    walletAssetsStore: walletAssetsStoreMock
                    advancedStore: advancedStoreMock
                    communitiesStore: communitiesStoreMock
                    messagingRootStore: messagingRootStoreMock
                    createChatPropertiesStore: createChatPropertiesStoreMock
                    contactsAdaptor: contactsAdaptorMock
                    popupHandler: null
                    emojiPopupLoader: emojiPopupLoaderMock
                    stickersPopupLoader: stickersPopupLoaderMock
                    sectionId: mock.communityId
                    sectionItemModel: mock.sectionItemModel
                    createChatViewOpened: false
                    isPortraitMode: (Window.width ?? 0) < ThemeUtils.portraitBreakpoint.width

                    onStatusChanged: {
                        if (status === Loader.Ready) {
                            const ms = Date.now() - d.loadStartTime
                            logs.logEvent("CommunityChatLoader READY in " + ms + " ms")
                            console.info("CommunityChatLoader READY in", ms, "ms")
                            if (root.profileExitMode)
                                profilerExitTimer.start()
                        }
                    }
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 180
        SplitView.preferredHeight: 180
        SplitView.fillWidth: true

        logsView.logText: logs.logText

        ColumnLayout {
            anchors.fill: parent

            RowLayout {
                spacing: Theme.bigPadding

                Button {
                    objectName: "communityLoaderRefreshButton"
                    text: "Refresh"
                    onClicked: root.refresh()
                }

                RowLayout {
                    Label { text: "State:" }
                    ComboBox {
                        id: ctrlJoinState
                        objectName: "communityLoaderJoinStateCombo"
                        Layout.preferredWidth: 220
                        model: d.joinStates.map(s => s.name)
                    }
                }

                RowLayout {
                    Label { text: "Role:" }
                    ComboBox {
                        id: ctrlRole
                        objectName: "communityLoaderRoleCombo"
                        Layout.preferredWidth: 160
                        model: d.memberRoles.map(r => r.name)
                        currentIndex: root.argValue("role", 0)
                    }
                }

                Switch {
                    id: ctrlMembersPanel
                    objectName: "communityLoaderMembersPanelSwitch"
                    text: "Members panel"
                    checked: root.argValue("membersPanel", 0) === 1
                }

                Switch {
                    id: ctrlCriteriaMet
                    objectName: "communityLoaderCriteriaMetSwitch"
                    text: "Token criteria met"
                    checked: true
                }

                Switch {
                    id: ctrlCanViewPrivate
                    objectName: "communityLoaderPrivateUnlockedSwitch"
                    text: "Private channels unlocked"
                    checked: true
                }

                Item { Layout.fillWidth: true }
            }

            RowLayout {
                spacing: Theme.bigPadding

                RowLayout {
                    Label { text: "Members:" }
                    SpinBox {
                        id: ctrlMembers
                        objectName: "communityLoaderMembersSpinBox"
                        from: 0; to: 10000; stepSize: 50; editable: true
                        value: root.argValue("members", 500)
                    }
                }

                RowLayout {
                    Label { text: "Categories:" }
                    SpinBox {
                        id: ctrlCategories
                        from: 0; to: 50; stepSize: 1; editable: true
                        value: root.argValue("categories", 3)
                    }
                }

                RowLayout {
                    Label { text: "Channels/cat:" }
                    SpinBox {
                        id: ctrlChannels
                        from: 0; to: 100; stepSize: 1; editable: true
                        value: root.argValue("channels", 6)
                    }
                }

                RowLayout {
                    Label { text: "Private/cat:" }
                    SpinBox {
                        id: ctrlPrivate
                        from: 0; to: 100; stepSize: 1; value: 2; editable: true
                    }
                }

                RowLayout {
                    Label { text: "Private members:" }
                    SpinBox {
                        id: ctrlPrivateMembers
                        from: 0; to: 10000; stepSize: 10; value: 20; editable: true
                    }
                }

                RowLayout {
                    Label { text: "Msgs/chat:" }
                    SpinBox {
                        id: ctrlMessages
                        objectName: "communityLoaderMessagesSpinBox"
                        from: 0; to: 10000; stepSize: 100; editable: true
                        value: root.argValue("messages", 500)
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    function refresh() {
        harness.active = false
        mock.uninstall()
        const t0 = Date.now()
        d.applyConfig()
        const t1 = Date.now()
        mock.install()
        console.info("mock: applyConfig", t1 - t0, "ms, install", Date.now() - t1, "ms")
        d.loadStartTime = Date.now()
        harness.active = true
        logs.logEvent("refresh: %1 (%2) — %3 members, %4 channels, %5 msgs each"
                      .arg(d.joinStates[ctrlJoinState.currentIndex].name)
                      .arg(d.memberRoles[ctrlRole.currentIndex].name)
                      .arg(mock.membersCount)
                      .arg(mock.uncategorizedChannelsCount + mock.categoriesCount * mock.channelsPerCategory)
                      .arg(mock.messagesPerChannel))
    }

    Component.onCompleted: refresh()
}

// category: Panels
