import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml.Models

import StatusQ.Layout
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils

import AppLayouts.Wallet
import AppLayouts.Market.controls

StatusSectionLayout {
    id: root

    /** required property representing token model **/
    required property var tokensModel
    /** required property representing loading state **/
    required property bool loading
    /** required property representing total number of tokens **/
    required property int totalTokensCount
    /** required property representing currency symbol $/£/€ etc... **/
    required property string currencySymbol
    /** required function to format amount to locale string **/
    required property var fnFormatCurrencyAmount
    /** required property holds the current page set from the backend **/
    required property int currentPage
    /** property to enable/disable swap button **/
    property bool swapEnabled: true

    /** Number of items per page **/
    readonly property int pageSize: 100

    /** signal to request the launch of Swap Modal **/
    signal requestLaunchSwap()
    /** signal to request fetching tokens as per selected page and page size **/
    signal fetchMarketTokens(int pageNumber, int pageSize)

    function resetView() {
        listView.positionViewAtBeginning()
    }

    QtObject {
        id: d
        property int startIndex: ((root.currentPage - 1) * root.pageSize) + 1

        // Read-only flag that turns true when the component enters a “compact” layout automatically on resize.
        readonly property bool compactMode: root.width < 600
    }

    onCurrentPageChanged: listView.positionViewAtBeginning()
    Component.onCompleted: root.fetchMarketTokens(1, root.pageSize)

    centerPanel: ColumnLayout {
        anchors.fill: parent
        anchors.rightMargin: Theme.xlPadding * 2
        anchors.leftMargin: Theme.xlPadding * 2
        spacing: 18

        // Header
        RowLayout {
            Layout.alignment: Qt.AlignTop
            StatusBaseText {
                objectName: "heading"
                text: qsTr("Market")
                font.weight: Font.Bold
                font.pixelSize: Theme.fontSize(28)
            }
            Item { Layout.fillWidth: true }
            StatusButton {
                objectName: "swapButton"
                visible: root.swapEnabled
                text: qsTr("Swap")
                icon.name: "swap"
                type: StatusBaseButton.Type.Primary
                onClicked: root.requestLaunchSwap()
            }
        }

        StatusListView {
            id: listView
            objectName: "tokensList"

            Layout.fillWidth: true
            Layout.fillHeight: true

            ScrollBar.vertical {
                topPadding: headerItem.height
                bottomPadding: footerItem.height
            }

            headerPositioning: ListView.OverlayHeader
            header: MarketTokenHeader {
                compactMode: d.compactMode
                width: listView.width
            }

            footer: MarketFooter {
                objectName: "marketFooter"
                width: listView.width
                pageSize: root.pageSize
                totalCount: root.totalTokensCount
                currentPage: root.currentPage
                onSwitchPage: root.fetchMarketTokens(pageNumber, root.pageSize)
                visible: listView.count > 0 && !root.loading
                height: visible ? implicitHeight : 0
                compactMode: d.compactMode
            }

            model: root.loading ? loadingModel: regularModel
        }

        // loading items model
        DelegateModel {
            id: loadingModel

            objectName: "loadingModel"

            model: root.pageSize

            delegate: MarketLoadingTokenDelegate {
                width: listView.width
                isLastItem: index === (listView.count - 1)
            }
        }

        // tokens model
        DelegateModel {
            id: regularModel

            objectName: "regularModel"

            model: root.tokensModel

            delegate: MarketTokenDelegate {
                width: listView.width

                compactMode: d.compactMode
                indexString: d.startIndex + index
                tokenName: model.name
                tokenSymbol: model.symbol.toUpperCase()
                iconSource: model.image
                price: "%1%2"
                .arg(root.currencySymbol)
                .arg(root.fnFormatCurrencyAmount(model.currentPrice, {noSymbol: true}))
                changePct24Hour: qsTr("%1 %2%", "[up/down/none character depending on value sign] [localized percentage value]%")
                .arg(WalletUtils.getUpDownTriangle(model.priceChangePercentage24h))
                .arg(LocaleUtils.numberToLocaleString(model.priceChangePercentage24h, 2))
                changePct24HourColor: WalletUtils.getChangePct24HourColor(
                                          Theme.palette, model.priceChangePercentage24h)
                volume24Hour: "%1%2"
                .arg(root.currencySymbol)
                .arg(root.fnFormatCurrencyAmount(model.totalVolume, {noSymbol: true}))
                marketCap: "%1%2"
                .arg(root.currencySymbol)
                .arg(root.fnFormatCurrencyAmount(model.marketCap, {noSymbol: true}))
                isLastItem: index === (listView.count - 1)
            }
        }
    }
}
