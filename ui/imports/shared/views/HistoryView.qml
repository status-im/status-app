import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Popups

import SortFilterProxyModel

import utils

import "../panels"
import "../popups"
import "../controls"

import shared.stores as SharedStores

import AppLayouts.Communities.stores
import AppLayouts.Wallet.popups
import AppLayouts.Wallet.controls
import AppLayouts.Wallet.panels

ColumnLayout {
    id: root

    property var overview

    property var activityStore
    property CommunitiesStore communitiesStore
    property SharedStores.CurrenciesStore currencyStore
    required property SharedStores.NetworksStore networksStore
    property bool showAllAccounts: false
    property bool displayValues: true
    property bool filterVisible
    property bool disableShadowOnScroll: false
    property bool hideVerticalScrollbar: false
    property int firstItemOffset: 0

    // banner component to be displayed on top of the list
    property alias bannerComponent: banner.sourceComponent

    property real yPosition: transactionListRoot.visibleArea.yPosition * transactionListRoot.contentHeight

    function resetView() {
        if (!!filterPanelLoader.item) {
            filterPanelLoader.item.resetView()
        }
    }

    Component.onCompleted: {
        if (root.activityStore.transactionActivityStatus.isFilterDirty) {
            root.activityStore.currentActivityFiltersStore.applyAllFilters()
        }

        root.activityStore.currentActivityFiltersStore.updateCollectiblesModel()
        root.activityStore.currentActivityFiltersStore.updateRecipientsModel()
    }

    Connections {
        target: root.activityStore.transactionActivityStatus
        enabled: root.visible
        function onIsFilterDirtyChanged() {
            root.activityStore.updateTransactionFilterIfDirty()
        }
        function onFilterChainsChanged() {
            root.activityStore.currentActivityFiltersStore.updateCollectiblesModel()
            root.activityStore.currentActivityFiltersStore.updateRecipientsModel()
        }
    }

    QtObject {
        id: d
        readonly property bool isInitialLoading: root.activityStore.loadingHistoryTransactions && transactionListRoot.count === 0

        readonly property int loadingSectionWidth: 56

        property bool firstSectionHeaderLoaded: false

        readonly property int maxSecondsBetweenRefresh: 3
    }

    StyledText {
        id: nonArchivalNodeError
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: root.firstItemOffset
        visible: root.activityStore.isNonArchivalNode
        text: qsTr("Status Desktop is connected to a non-archival node. Transaction history may be incomplete.")
        font.pixelSize: Theme.primaryTextFontSize
        color: Theme.palette.dangerColor1
        wrapMode: Text.WordWrap
    }

    Loader {
        id: filterPanelLoader
        active: root.filterVisible && (d.isInitialLoading || transactionListRoot.count > 0 || root.activityStore.currentActivityFiltersStore.filtersSet)
        visible: active && !noTxs.visible
        Layout.fillWidth: true
        sourceComponent: ActivityFilterPanel {
            activityFilterStore: root.activityStore.currentActivityFiltersStore
            store: root.activityStore
            hideNoResults: newTransactions.visible
            isLoading: d.isInitialLoading
        }
    }

    Loader {
        id: banner
        Layout.fillWidth: true
    }

    ShapeRectangle {
        id: noTxs
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        Layout.topMargin: !nonArchivalNodeError.visible? root.firstItemOffset : 0
        visible: !d.isInitialLoading && !root.activityStore.currentActivityFiltersStore.filtersSet && transactionListRoot.count === 0
        font.pixelSize: Theme.primaryTextFontSize
        text: qsTr("Activity for this account will appear here")
    }

    Item {
        id: transactionListWrapper
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: nonArchivalNodeError.visible || noTxs.visible ? Theme.padding : 0
        Layout.fillWidth: true
        Layout.fillHeight: true

        Rectangle { // Shadow behind delegates when scrolling
            anchors.top: parent.top
            width: parent.width
            height: 4
            color: Theme.palette.separator
            visible: !root.disableShadowOnScroll && !transactionListRoot.atYBeginning
        }

        StatusListView {
            id: transactionListRoot
            objectName: "walletAccountTransactionList"
            anchors.fill: parent

            model: SortFilterProxyModel {
                id: txModel

                sourceModel: root.activityStore.historyTransactions

                // LocaleUtils is not accessable from inside expression, but local function works
                property var daysTo: (d1, d2) => LocaleUtils.daysTo(d1, d2)
                property var daysBetween: (d1, d2) => LocaleUtils.daysBetween(d1, d2)
                property var getFirstDayOfTheCurrentWeek: () => LocaleUtils.getFirstDayOfTheCurrentWeek()
                proxyRoles: ExpressionRole {
                    name: "date"
                    expression: {
                        if (!model.activityEntry || model.activityEntry.timestamp === 0)
                            return ""
                        const currDate = new Date()
                        const timestampDate = new Date(model.activityEntry.timestamp * 1000)
                        const daysDiff = txModel.daysBetween(currDate, timestampDate)
                        const daysToBeginingOfThisWeek = txModel.daysTo(timestampDate, txModel.getFirstDayOfTheCurrentWeek())

                        if (daysDiff < 1) {
                            return qsTr("Today")
                        } else if (daysDiff < 2) {
                            return qsTr("Yesterday")
                        } else if (daysToBeginingOfThisWeek >= 0) {
                            return qsTr("Earlier this week")
                        } else if (daysToBeginingOfThisWeek > -7) {
                            return qsTr("Last week")
                        } else if (currDate.getMonth() === timestampDate.getMonth() && currDate.getYear() === timestampDate.getYear()) {
                            return qsTr("Earlier this month")
                        }

                        const previousMonthDate = (new Date(new Date().setDate(0)))
                        // Special case for the end of the year
                        if ((timestampDate.getMonth() === previousMonthDate.getMonth() && timestampDate.getYear() === previousMonthDate.getYear())
                            || (previousMonthDate.getMonth() === 11 && timestampDate.getMonth() === 0 && Math.abs(timestampDate.getYear() - previousMonthDate.getYear()) === 1))
                        {
                            return qsTr("Last month")
                        }

                        return timestampDate.toLocaleDateString(Qt.locale(), "MMM yyyy")
                    }
                }
            }

            delegate: transactionDelegateComponent

            headerPositioning: ListView.OverlayHeader
            footer: footerComp

            ScrollBar.vertical: StatusScrollBar {
                policy: root.hideVerticalScrollbar? ScrollBar.AlwaysOff : ScrollBar.AsNeeded
            }

            visibleArea.onYPositionChanged: {
                tryFetchMoreTransactions()
            }

            Connections {
                target: root.activityStore

                function onLoadingHistoryTransactionsChanged() {
                    // Calling timer instead directly to not cause binding loop
                    if (!root.activityStore.loadingHistoryTransactions)
                        fetchMoreTimer.start()
                }
            }

            function tryFetchMoreTransactions() {
                if (d.isInitialLoading || !footerItem || !root.activityStore.historyTransactions.hasMore)
                    return
                const footerYPosition = footerItem.height / contentHeight
                if (footerYPosition >= 1.0) {
                    return
                }

                // On startup, first loaded ListView will have heightRatio equal 0
                if (footerYPosition + visibleArea.yPosition + visibleArea.heightRatio > 1.0) {
                    root.activityStore.fetchMoreTransactions()
                }
            }

            Timer {
                id: fetchMoreTimer
                interval: 1
                onTriggered: transactionListRoot.tryFetchMoreTransactions()
            }
        }

        StatusButton {
            id: newTransactions
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.halfPadding

            text: qsTr("New transactions")

            visible: root.activityStore.newDataAvailable && !root.activityStore.loadingHistoryTransactions
            onClicked: root.activityStore.resetActivityData()

            icon.name: "arrow-up"

            radius: 36
            type: StatusButton.Primary
            size: StatusBaseButton.Size.Tiny
        }
    }

    Component {
        id: txContextMenu

        TransactionContextMenu {
            required property var modelData

            readonly property string networkShortName: Utils.getNetworkShortName(modelData.transaction.chainId)
            readonly property bool isNetworkTestnet: Utils.isChainIDTestnet(modelData.transaction.chainId)

            hideDisabledItems: true

            networkExplorerName: Utils.getChainExplorerName(networkShortName)

            onClosed: destroy()

            onCopyTxHashRequested: {
                ClipboardUtils.setText(modelData.transaction.hash)
            }

            onViewTxOnExplorerRequested: {
                let link = Utils.getUrlForTxOnNetwork(networkShortName, isNetworkTestnet, modelData.transaction.hash)
                Global.requestOpenLink(link)
            }
        }
    }

    Component {
        id: transactionDelegateComponent
        ColumnLayout {
            id: transactionDelegate

            required property var model
            required property int index

            readonly property bool displaySectionHeader: index === 0 || model.date !== txModel.get(index - 1).date
            readonly property bool displaySectionFooter: index === txModel.count-1  || model.date !== txModel.get(index + 1).date

            width: ListView.view.width
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.firstItemOffset
                visible: transactionDelegate.index === 0 && root.firstItemOffset > 0
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                visible: transactionDelegate.displaySectionHeader
                color: Theme.palette.statusModal.backgroundColor

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    width: parent.width
                    spacing: Theme.halfPadding

                    Separator {
                        Layout.fillWidth: true
                        implicitHeight: 1
                    }

                    StatusBaseText {
                        leftPadding: Theme.padding
                        bottomPadding: Theme.halfPadding
                        text: transactionDelegate.model.date
                        font.pixelSize: Theme.additionalTextSize
                    }
                }
            }

            TransactionDelegate {
                Layout.fillWidth: true
                modelData: transactionDelegate.model.activityEntry
                timeStampText: isModelDataValid ? LocaleUtils.formatRelativeTimestamp(modelData.timestamp * 1000, true) : ""
                flatNetworks: root.networksStore.allNetworks
                currenciesStore: root.currencyStore
                activityStore: root.activityStore
                showAllAccounts: root.showAllAccounts
                displayValues: root.displayValues
                community: isModelDataValid && !!communityId && !!root.communitiesStore ? root.communitiesStore.getCommunityDetailsAsJson(communityId) : null
                onClicked: function(itemId, mouse) {
                    if (mouse.button === Qt.RightButton) {
                        txContextMenu.createObject(this, { modelData }).popup(mouse.x, mouse.y)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                visible: transactionDelegate.displaySectionFooter
                color: Theme.palette.statusModal.backgroundColor
            }
        }
    }

    Component {
        id: footerComp
        ColumnLayout {
            id: footerColumn
            readonly property bool allActivityLoaded: !root.activityStore.historyTransactions.hasMore && transactionListRoot.count !== 0
            width: root.width
            spacing: d.isInitialLoading ? 6 : 12

            Separator {
                Layout.fillWidth: true
                Layout.topMargin: Theme.halfPadding
                visible: d.isInitialLoading
            }

            StatusTextWithLoadingState {
                Layout.alignment: Qt.AlignLeft
                Layout.leftMargin: Theme.padding
                text: "01.01.2000"
                width: d.loadingSectionWidth
                font.pixelSize: Theme.primaryTextFontSize
                loading: visible
                visible: d.isInitialLoading
            }

            Repeater {
                model: {
                    if (!root.visible)
                        return 0
                    if (!noTxs.visible) {
                        const delegateHeight = 64 + footerColumn.spacing
                        if (d.isInitialLoading) {
                            return Math.floor(transactionListRoot.height / delegateHeight)
                        } else if (root.activityStore.historyTransactions.hasMore) {
                            return Math.max(3, Math.floor(transactionListRoot.height / delegateHeight) - 3)
                        }
                    }
                    return 0
                }
                TransactionDelegate {
                    Layout.fillWidth: true

                    flatNetworks: root.networksStore.allNetworks
                    currenciesStore: root.currencyStore
                    activityStore: root.activityStore
                    loading: true
                }
            }

            Separator {
                Layout.topMargin: Theme.bigPadding
                Layout.fillWidth: true
                visible: footerColumn.allActivityLoaded
            }
            StatusBaseText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("You have reached the beginning of the activity for this account")
                font.pixelSize: Theme.additionalTextSize
                color: Theme.palette.baseColor1
                visible: footerColumn.allActivityLoaded
                horizontalAlignment: Text.AlignHCenter
            }
            StatusButton {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Back to most recent transaction")
                visible: footerColumn.allActivityLoaded && transactionListRoot.contentHeight > transactionListRoot.height
                onClicked: transactionListRoot.positionViewAtBeginning()
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.halfPadding
            }
        }
    }
}
