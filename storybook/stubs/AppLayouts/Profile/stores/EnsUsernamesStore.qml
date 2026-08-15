import QtQuick

QtObject {
    id: root

    property var ensUsernamesModule: null

    readonly property ListModel ensUsernamesModel: ListModel {}
    readonly property ListModel currentChainEnsUsernamesModel: ListModel {}

    readonly property bool areTestNetworksEnabled: networksModule.areTestNetworksEnabled
    readonly property string chainId: mainModule.appNetworkId

    property string pubkey: userProfile.pubKey
    property string preferredUsername: ""
    property string username: "storybook.eth"
    property string ensRegisteredAddress: ""

    // Status token (SNT) on mainnet — the ens flows price registration in it
    function getStatusTokenGroupKey() { return "SNT" }
    function getEnsnameResolverAddress(ensName) { return "" }

    function setPrefferedEnsUsername(ensName) {}
    function checkEnsUsernameAvailability(ensName, isStatus) {}
    function numOfPendingEnsUsernames() { return 0 }
    function ensDetails(chainId, ensUsername) { return "" }
}
