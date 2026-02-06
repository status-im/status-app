import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Controls.Validators

import SortFilterProxyModel

import utils
import shared.controls
import shared.stores as SharedStores
import AppLayouts.stores as AppLayoutStores

import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.Wallet.controls

Item {
    id: root

    required property AppLayoutStores.ContactsStore contactsStore
    required property SharedStores.NetworkConnectionStore networkConnectionStore
    required property SharedStores.NetworksStore networksStore
    required property var followingAddressesModel
    required property int totalFollowingCount
    required property WalletStores.RootStore rootStore  // Wallet-specific RootStore for delegates

    /* The wallet account address to fetch followings for */
    property string selectedAddress

    signal sendToAddressRequested(string address)
    signal refreshRequested(string address, string search, int limit, int offset)
    signal followingAddressesUpdated()

    readonly property bool showPagination: !d.currentSearch && root.totalFollowingCount > d.pageSize
    readonly property int pageSize: d.pageSize
    readonly property int totalCount: root.totalFollowingCount
    readonly property int currentPage: d.currentPage
    readonly property bool isPaginationLoading: d.isPaginationLoading

    function goToPage(pageNumber) {
        d.goToPage(pageNumber)
    }

    function refresh(address) {
        d.refresh(address || root.selectedAddress)
    }

    QtObject {
        id: d

        property string currentSearch: ""
        property int pageSize: 10
        property int currentPage: 1
        property bool isPaginationLoading: false

        function reset() {
            currentSearch = ""
            searchBox.text = ""
            currentPage = 1
        }

        function performSearch() {
            const offset = (currentPage - 1) * pageSize
            isPaginationLoading = true
            root.refreshRequested(root.selectedAddress, currentSearch, pageSize, offset)
        }

        function goToPage(pageNumber) {
            currentPage = pageNumber
            performSearch()
        }

        function refresh(address) {
            currentPage = 1
            currentSearch = ""
            searchBox.text = ""
            isPaginationLoading = true
            root.refreshRequested(address, "", pageSize, 0)
        }
    }

    // Called from parent when following addresses are updated
    onFollowingAddressesUpdated: {
        d.isPaginationLoading = false
    }

    Component.onCompleted: {
        d.refresh()  // Load data when user navigates to this page
    }

    Timer {
        id: searchDebounceTimer
        interval: 250
        repeat: false
        onTriggered: d.performSearch()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SearchBox {
            id: searchBox
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.padding
            visible: true
            placeholderText: qsTr("Search for name, ENS or address")

            onTextChanged: {
                d.currentSearch = text
                d.currentPage = 1
                searchDebounceTimer.restart()
            }

            validators: [
                StatusValidator {
                    property bool isEmoji: false

                    name: "check-for-no-emojis"
                    validate: (value) => {
                                  if (!value) {
                                      return true
                                  }

                                  isEmoji = Constants.regularExpressions.emoji.test(value)
                                  if (isEmoji){
                                      return false
                                  }

                                  return Constants.regularExpressions.alphanumericalExpanded1.test(value)
                              }
                    errorMessage: isEmoji?
                                      qsTr("Your search is too cool (use A-Z and 0-9, single whitespace, hyphens and underscores only)")
                                    : qsTr("Your search contains invalid characters (use A-Z and 0-9, single whitespace, hyphens and underscores only)")
                }
            ]
        }

        ShapeRectangle {
            id: emptySearchResult
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            visible: root.followingAddressesModel && root.followingAddressesModel.count > 0 && listView.count === 0 && !d.isPaginationLoading
            text: qsTr("No following addresses found. Check spelling or whether the address is correct.")
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StatusListView {
                id: listView
                objectName: "FollowingAddressesView_followingAddresses"
                anchors.fill: parent
                spacing: Theme.halfPadding
                visible: !d.isPaginationLoading

                model: root.followingAddressesModel

                delegate: FollowingAddressesDelegate {
                    id: followingAddressDelegate
                    objectName: "followingAddressView_Delegate_" + model.name
                    width: ListView.view.width
                    title: model.name
                    address: model.address
                    ensName: model.ensName
                    tags: model.tags
                    avatar: model.avatar
                    networkConnectionStore: root.networkConnectionStore
                    activeNetworksModel: root.networksStore.activeNetworks
                    rootStore: root.rootStore
                    onClicked: {
                        Global.openSavedAddressActivityPopup({
                            name: model.name,
                            address: model.address,
                            mixedcaseAddress: model.address,
                            ens: model.ensName,
                            colorId: "",
                            avatar: model.avatar,
                            isFollowingAddress: true
                        })
                    }
                    onOpenSendModal: root.sendToAddressRequested(recipient)
                    onMenuRequested: (name, address, ensName, tags) => {
                        followingAddressMenu.openMenu(followingAddressDelegate, 
                            followingAddressDelegate.width - followingAddressMenu.width,
                            followingAddressDelegate.height + Theme.halfPadding,
                            {name: name, address: address, ensName: ensName, tags: tags})
                    }
                }
            }

            StatusLoadingIndicator {
                anchors.centerIn: parent
                visible: d.isPaginationLoading
                color: Theme.palette.directColor4
            }
        }

        FollowingAddressMenu {
            id: followingAddressMenu
            activeNetworksModel: root.networksStore.activeNetworks
            rootStore: root.rootStore
        }
    }

    ColumnLayout {
        id: noFollowingAddresses
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.bigPadding
        visible: root.totalFollowingCount === 0 && !d.isPaginationLoading
        spacing: Theme.halfPadding

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 161
            Layout.preferredHeight: 160

            source: (Theme.style === Theme.Light) ? Assets.png("wallet/onchain-friends-empty-light") :
                                                    Assets.png("wallet/onchain-friends-empty-dark")
            fillMode: Image.PreserveAspectFit
            mipmap: true
            cache: false
        }

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.primaryTextFontSize
            textFormat: Text.RichText
            color: Theme.palette.directColor1
            text: qsTr("No onchain follows yet. Find and follow Ethereum accounts on %1 to see them here.")
                .arg(Utils.getStyledLink(qsTr("Ethereum Follow Protocol"), "https://efp.app", hoveredLink, Theme.palette.primaryColor1, Theme.palette.primaryColor1))
            onLinkActivated: (link) => Global.requestOpenLink(link)
            HoverHandler {
                cursorShape: !!parent.hoveredLink ? Qt.PointingHandCursor : undefined
            }
        }
    }
}
