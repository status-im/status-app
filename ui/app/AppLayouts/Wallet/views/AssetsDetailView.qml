import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window

import StatusQ
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core
import StatusQ.Controls

import utils
import shared.views
import shared.controls
import shared.stores as SharedStores

import AppLayouts.Wallet.helpers
import AppLayouts.Wallet.stores as WalletStores

import QtModelsToolkit
import SortFilterProxyModel

import "../controls"

/// \beware: heavy shortcuts here, refactor to match the requirements when touching this again
/// \todo split into token history and balance views; they have different requirements that introduce unnecessary complexity
/// \todo take a declarative approach, move logic into the typed backend and remove multiple source of truth (e.g. time ranges)
Item {
    id: root

    property var tokenGroup: ({})

    property WalletStores.TokensStore tokensStore
    property SharedStores.CurrenciesStore currencyStore
    property SharedStores.NetworkConnectionStore networkConnectionStore
    property var allNetworksModel
    property var networkFilters
    onNetworkFiltersChanged: d.forceRefreshBalanceStore = true
    /*required*/ property string address: ""

    TokenMarketValuesData {
        id: marketValueData
    }

    QtObject {
        id: d

        readonly property string symbol: !!root.tokenGroup? root.tokenGroup.symbol?? "" : ""
        property bool marketDetailsLoading: !!root.tokenGroup? root.tokenGroup.marketDetailsLoading?? false : false
        property bool tokenDetailsLoading: !!root.tokenGroup? root.tokenGroup.detailsLoading?? false: false
        property bool isCommunityAsset: !!root.tokenGroup && !!tokenGroup.communityId

        readonly property LeftJoinModel addressPerChainModel: LeftJoinModel {
            leftModel: tokenGroup && tokenGroup.tokens ? tokenGroup.tokens: null
            rightModel: root.allNetworksModel
            joinRole: "chainId"
        }

        property bool forceRefreshBalanceStore: false
        readonly property var splitAddresses: root.networkFilters.split(":")

        readonly property SortFilterProxyModel enabledNetworksModel: SortFilterProxyModel {
            sourceModel: root.allNetworksModel
            filters: ValueFilter {
                roleName: "isEnabled"
                value: true
            }
        }
    }

    Connections {
        target: walletSectionAllTokens
        function onTokenHistoricalDataReady(tokenDetails: string) {
            let response = JSON.parse(tokenDetails)
            if (response === null) {
                console.debug("error parsing json message for tokenHistoricalDataReady")
                return
            }
            if(response.historicalData === null || response.historicalData <= 0)
                return

            marketValueData.setTimeAndValueData(response.historicalData, response.range)
        }
    }

    AssetsDetailsHeader {
        id: tokenDetailsHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        asset.name: {
            if (!tokenGroup)
                return ""
            if (tokenGroup.logoUri)
                return tokenGroup.logoUri
            return Constants.tokenIcon(tokenGroup.symbol)
        }
        asset.isImage: true
        primaryText: tokenGroup && tokenGroup.name ? tokenGroup.name : Constants.dummyText
        secondaryText: tokenGroup ? tokenGroup.balanceText : Constants.dummyText
        tertiaryText: {
            if (!d.isCommunityAsset) {
                let totalCurrencyBalance = tokenGroup ? tokenGroup.balance * tokenGroup.marketPrice : 0
                return root.currencyStore.formatCurrencyAmount(totalCurrencyBalance, root.currencyStore.currentCurrency)
            }
            return ""
        }
        decimals: tokenGroup && tokenGroup.decimals ? tokenGroup.decimals : 4
        balances: tokenGroup && tokenGroup.balances ? tokenGroup.balances: null
        networksModel: d.enabledNetworksModel
        isLoading: d.marketDetailsLoading
        address: root.address
        errorTooltipText: tokenGroup && tokenGroup.balances ? networkConnectionStore.getBlockchainNetworkDownTextForToken(tokenGroup.balances): ""
        formatBalance: function(balance){
            return LocaleUtils.currencyAmountToLocaleString(root.currencyStore.getCurrencyAmount(balance, tokenGroup.key))
        }
        communityTag.visible: d.isCommunityAsset
        communityTag.tagPrimaryLabel.text: d.isCommunityAsset ? tokenGroup.communityName: ""
        communityTag.asset.name: d.isCommunityAsset ? tokenGroup && !!tokenGroup.communityImage ? tokenGroup.communityImage : "" : ""
        communityTag.asset.isImage: true
    }

    enum GraphType {
        Price = 0
    }

    StatusScrollView {
        id: scrollView
        anchors.top: tokenDetailsHeader.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: 47

        width: parent.width
        contentWidth: availableWidth
        padding: 0

        ColumnLayout {
            width: scrollView.availableWidth
            spacing: 40

            Loader {
                id: graphDetailLoader
                Layout.fillWidth: true
                Layout.preferredHeight: 290
                active: root.visible
                sourceComponent: StatusChartPanel {
                    id: graphDetail

                    property int selectedGraphType: AssetsDetailView.GraphType.Price
                    property TokenMarketValuesData selectedStore: marketValueData

                    function dataReady() {
                        return typeof selectedStore != "undefined"
                    }
                    function timeRangeSelected() {
                        return dataReady() && graphDetail.timeRangeTabBarIndex >= 0 && graphDetail.selectedTimeRange.length > 0
                    }

                    readonly property var labelsData: {
                        return timeRangeSelected()
                                ? selectedStore.timeRange[graphDetail.timeRangeTabBarIndex][graphDetail.selectedTimeRange]
                                : []
                    }
                    readonly property var dataRange: {
                        return timeRangeSelected()
                                ? selectedStore.dataRange[graphDetail.timeRangeTabBarIndex][graphDetail.selectedTimeRange]
                                : []
                    }
                    readonly property var maxTicksLimit: {
                        return timeRangeSelected() && typeof selectedStore.maxTicks != "undefined"
                                ? selectedStore.maxTicks[graphDetail.timeRangeTabBarIndex][graphDetail.selectedTimeRange]
                                : 0
                    }

                    graphsModel: [
                        {text: qsTr("Price"), enabled: true, id: AssetsDetailView.GraphType.Price, visible: !d.isCommunityAsset},
                    ]
                    defaultTimeRangeIndexShown: ChartDataBase.TimeRange.All
                    timeRangeModel: dataReady() && selectedStore.timeRangeTabsModel
                    onHeaderTabClicked: (privateIdentifier, isTimeRange) => {
                                            if(!isTimeRange && graphDetail.selectedGraphType !== privateIdentifier) {
                                                graphDetail.selectedGraphType = privateIdentifier
                                            }

                                            if(!isTimeRange) {
                                                graphDetail.selectedStore = marketValueData
                                            }

                                            chart.refresh()
                                        }

                    chart.type: 'line'
                    chart.labels: root.tokensStore.marketHistoryIsLoading ? [] : graphDetail.labelsData
                    chart.datasets: {
                        return [{
                            xAxisId: 'x-axis-1',
                            yAxisId: 'y-axis-1',
                            backgroundColor: (Theme.palette.name === "dark") ? 'rgba(136, 176, 255, 0.2)' : 'rgba(67, 96, 223, 0.2)',
                            borderColor: (Theme.palette.name === "dark") ? 'rgba(136, 176, 255, 1)' : 'rgba(67, 96, 223, 1)',
                            borderWidth: graphDetail.selectedGraphType === AssetsDetailView.GraphType.Price ? 3 : 2,
                            pointRadius: 0,
                            data: root.tokensStore.marketHistoryIsLoading ? [] : graphDetail.dataRange,
                            parsing: false,
                        }]
                    }

                    chart.options: {
                        return {
                            maintainAspectRatio: false,
                            responsive: true,
                            animation: {
                                duration: 0
                            },
                            legend: {
                                display: false
                            },
                            elements: {
                                line: {
                                    cubicInterpolationMode: 'monotone' // without it interpolation makes the line too curvy that can extend horizontally farther then data points
                                }
                            },
                            //TODO enable zoom
                            //zoom: {
                            //  enabled: true,
                            //  drag: true,
                            //  speed: 0.1,
                            //  threshold: 2
                            //},
                            //pan:{enabled:true,mode:'x'},
                            tooltips: {
                                intersect: false,
                                displayColors: false,
                                callbacks: {
                                    label: function(tooltipItem, data) {
                                        let label = data.datasets[tooltipItem.datasetIndex].label || '';
                                        if (label) {
                                            label += ': ';
                                        }

                                        const value = root.currencyStore.formatCurrencyAmount(
                                                        tooltipItem.yLabel, root.currencyStore.currentCurrency)

                                        return label + value
                                    }
                                }
                            },
                            scales: {
                                xAxes: [{
                                        id: 'x-axis-1',
                                        position: 'bottom',
                                        type: graphDetail.selectedGraphType === AssetsDetailView.GraphType.Price ? 'category' : 'time',
                                        gridLines: {
                                            drawOnChartArea: false,
                                            drawBorder: false,
                                            drawTicks: false,
                                        },
                                        ticks: {
                                            fontSize: Theme.asideTextFontSize,
                                            fontColor: (Theme.palette.name === "dark") ? '#909090' : '#939BA1',
                                            padding: 16,
                                            maxRotation: 0,
                                            minRotation: 0,
                                            maxTicksLimit: graphDetail.maxTicksLimit,
                                        },
                                        time: {
                                            minUnit: 'day' // for '7days' timeframe, otherwise labels are '10PM', '10AM', '10PM', etc
                                        }
                                    }],
                                yAxes: [{
                                        position: 'left',
                                        id: 'y-axis-1',
                                        gridLines: {
                                            borderDash: [8, 4],
                                            drawBorder: false,
                                            drawTicks: false,
                                            color: (Theme.palette.name === "dark") ? '#909090' : '#939BA1'
                                        },
                                        beforeDataLimits: (axis) => {
                                            axis.paddingTop = 25;
                                            axis.paddingBottom = 0;
                                        },
                                        afterDataLimits: (axis) => {
                                            if(axis.min < 0)
                                            axis.min = 0;
                                        },
                                        ticks: {
                                            fontSize: Theme.asideTextFontSize,
                                            fontColor: (Theme.palette.name === "dark") ? '#909090' : '#939BA1',
                                            padding: 8,
                                            callback: function(value, index, ticks) {
                                                return LocaleUtils.numberToLocaleString(value)
                                            },
                                        }
                                    }]
                            }
                        }
                    }

                    LoadingGraphView {
                        anchors.fill: chart
                        active: root.tokensStore.marketHistoryIsLoading
                    }

                }
            }

            Flow {
                id: infoFlow

                Layout.fillWidth: true
                visible: !d.isCommunityAsset
                spacing: 5

                InformationTile {
                    id: i1

                    objectName: "marketCapInformationTile"
                    primaryText: qsTr("Market Cap")
                    secondaryText: tokenGroup && tokenGroup.marketDetails && tokenGroup.marketDetails.marketCap
                                   ? LocaleUtils.currencyAmountToLocaleString(tokenGroup.marketDetails.marketCap)
                                   : Constants.dummyText
                    isLoading: d.marketDetailsLoading
                }
                InformationTile {
                    id: i2

                    objectName: "dayLowInformationTile"
                    primaryText: qsTr("Day Low")
                    secondaryText: tokenGroup && tokenGroup.marketDetails && tokenGroup.marketDetails.lowDay
                                   ? LocaleUtils.currencyAmountToLocaleString(tokenGroup.marketDetails.lowDay)
                                   : Constants.dummyText
                    isLoading: d.marketDetailsLoading
                }

                // Wrapper for adding extra space in the middle of the Flow
                Item {
                    readonly property int centralSpacing:
                        Math.max(0, infoFlow.width
                                 - i1.width - i2.width - i3.width - i4.width - i5.width - i6.width
                                 - (infoFlow.children.length - 1) * infoFlow.spacing)

                    width: i3.width + centralSpacing
                    height: i3.height

                    InformationTile {
                        id: i3

                        objectName: "dayHighInformationTile"
                        primaryText: qsTr("Day High")
                        secondaryText: tokenGroup && tokenGroup.marketDetails && tokenGroup.marketDetails.highDay
                                       ? LocaleUtils.currencyAmountToLocaleString(tokenGroup.marketDetails.highDay)
                                       : Constants.dummyText
                        isLoading: d.marketDetailsLoading
                    }
                }

                InformationTile {
                    id: i4

                    readonly property double changePctHour: tokenGroup && tokenGroup.marketDetails
                                                            ? tokenGroup.marketDetails.changePctHour : 0

                    objectName: "hourInformationTile"
                    primaryText: qsTr("Hour")
                    secondaryText: "%1%".arg(LocaleUtils.numberToLocaleString(changePctHour, 2))
                    secondaryLabel.customColor: changePctHour === 0 ? Theme.palette.directColor1 :
                                                                      changePctHour < 0 ? Theme.palette.dangerColor1 :
                                                                                          Theme.palette.successColor1
                    isLoading: d.marketDetailsLoading
                }
                InformationTile {
                    id: i5

                    readonly property double changePctDay: tokenGroup && tokenGroup.marketDetails
                                                           ? tokenGroup.marketDetails.changePctDay : 0

                    primaryText: qsTr("Day")
                    objectName: "dayInformationTile"
                    secondaryText: "%1%".arg(LocaleUtils.numberToLocaleString(changePctDay, 2))
                    secondaryLabel.customColor: changePctDay === 0 ? Theme.palette.directColor1 :
                                                                     changePctDay < 0 ? Theme.palette.dangerColor1 :
                                                                                        Theme.palette.successColor1
                    isLoading: d.marketDetailsLoading
                }
                InformationTile {
                    id: i6

                    readonly property double changePct24hour: tokenGroup && tokenGroup.marketDetails
                                                              ? tokenGroup.marketDetails.changePct24hour : 0

                    primaryText: qsTr("24 Hours")
                    objectName: "24HoursInformationTile"
                    secondaryText: "%1%".arg(LocaleUtils.numberToLocaleString(changePct24hour, 2))
                    secondaryLabel.customColor: changePct24hour === 0 ? Theme.palette.directColor1 :
                                                                        changePct24hour < 0 ? Theme.palette.dangerColor1 :
                                                                                              Theme.palette.successColor1
                    isLoading: d.marketDetailsLoading
                }
            }

            Flow {
                id: detailsFlow

                readonly property int rightSideWidth: 272
                readonly property bool isOverflowing:  !tokenDescriptionText.text || detailsFlow.width - detailsFlow.rightSideWidth - tokenDescriptionText.width < 24

                Layout.fillWidth: true
                spacing: 24

                StatusTextWithLoadingState {
                    id: tokenDescriptionText

                    width: Math.max(536 , scrollView.availableWidth - detailsFlow.rightSideWidth - 24)

                    font.pixelSize: Theme.primaryTextFontSize
                    lineHeight: 22
                    lineHeightMode: Text.FixedHeight
                    text: tokenGroup && tokenGroup.description ? tokenGroup.description : d.tokenDetailsLoading ? Constants.dummyText: ""
                    customColor: Theme.palette.directColor1
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                    textFormat: Qt.RichText
                    loading: d.tokenDetailsLoading
                    visible: !!text
                }

                GridLayout {
                    columnSpacing: 10
                    rowSpacing: 10
                    flow: detailsFlow.isOverflowing && detailsFlow.width > 400 ? GridLayout.LeftToRight: GridLayout.TopToBottom

                    InformationTileAssetDetails {
                        id: websiteBlock

                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: detailsFlow.isOverflowing ? -1 : detailsFlow.rightSideWidth
                        visible: !d.isCommunityAsset && tokenGroup.websiteUrl
                        primaryText: qsTr("Website")
                        content: InformationTag {
                            asset.name : "browser"
                            tagPrimaryLabel.text: SQUtils.Utils.stripHttpsAndwwwFromUrl(tokenGroup.websiteUrl)
                            visible: typeof tokenGroup != "undefined" && tokenGroup && tokenGroup.websiteUrl !== ""
                            customBackground: Component {
                                Rectangle {
                                    color: Theme.palette.baseColor2
                                    border.width: 1
                                    border.color: "transparent"
                                    radius: 36
                                }
                            }
                            StatusMouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Global.requestOpenLink(tokenGroup.websiteUrl)
                            }
                        }
                    }

                    InformationTileAssetDetails {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: detailsFlow.isOverflowing ? -1 : detailsFlow.rightSideWidth
                        visible:  d.isCommunityAsset
                        primaryText: qsTr("Minted by")
                        content: InformationTag {
                            tagPrimaryLabel.text: tokenGroup && tokenGroup.communityName ? tokenGroup.communityName : ""
                            asset.name: tokenGroup && tokenGroup.communityImage ? tokenGroup.communityImage : ""
                            asset.isImage: true
                            customBackground: Component {
                                Rectangle {
                                    color: Theme.palette.baseColor2
                                    border.width: 1
                                    border.color: "transparent"
                                    radius: 36
                                }
                            }
                            StatusMouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Global.switchToCommunity(tokenGroup.communityId)
                            }
                        }
                    }

                    InformationTileAssetDetails {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: detailsFlow.isOverflowing ? -1 : detailsFlow.rightSideWidth

                        primaryText: qsTr("Contract")
                        content: GridLayout {
                            columnSpacing: 10
                            rowSpacing: 10
                            flow: GridLayout.TopToBottom
                            Repeater {
                                model: SortFilterProxyModel {
                                    sourceModel: d.addressPerChainModel
                                    filters: FastExpressionFilter {
                                        expression: d.splitAddresses.includes(model.chainId+"")
                                        expectedRoles: ["chainId"]
                                    }
                                }
                                delegate: InformationTag {
                                    hoverEnabled: true
                                    asset.name: Assets.svg(model.iconUrl)
                                    asset.isImage: true
                                    tagPrimaryLabel.text: model.chainName
                                    tagSecondaryLabel.text: SQUtils.Utils.elideAndFormatWalletAddress(model.address)
                                    customBackground: Component {
                                        Rectangle {
                                            color: Theme.palette.baseColor2
                                            radius: 36
                                        }
                                    }
                                    rightComponent: CopyButton {
                                        width: 20
                                        height: 20
                                        textToCopy: model.address
                                    }

                                    StatusToolTip {
                                        text: qsTr("Copy contract address")
                                        visible: parent.hovered
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
