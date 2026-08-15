// Mock of src/app/modules/main/wallet_section/following_addresses/view.nim
import QtQuick

QtObject {
    id: root

    readonly property string contextPropertyName: "walletSectionFollowingAddresses"

    // address / ensName / tags / name / avatar — remotely fetched and paginated,
    // so the model is replaced page by page, not accumulated.
    property ListModel model: ListModel {}

    property int totalFollowingCount: 0

    // Set by WalletSectionMock; supplies the generated pages.
    property var profile: null

    // Last request, so a page or test can assert what the store asked for.
    property var lastRequest: null

    signal followingAddressesUpdated()
    // Raised for consumers that serve their own pages instead of the profile's.
    signal fetchRequested(string userAddress, string search, int limit, int offset)

    function fetchFollowingAddresses(userAddress, search, limit, offset) {
        root.lastRequest = ({
            userAddress: userAddress, search: search, limit: limit, offset: offset
        })
        if (root.profile) {
            root.totalFollowingCount = root.profile.followingAddressesTotal(search)
            setPage(root.profile.followingAddresses(search, limit, offset))
        }
        root.fetchRequested(userAddress, search, limit, offset)
    }

    function setPage(rows) {
        root.model.clear()
        for (let i = 0; i < rows.length; ++i)
            root.model.append(rows[i])
        root.followingAddressesUpdated()
    }
}
