import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QtModelsToolkit

import StatusQ.Core
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Wallet.controls

import utils

ItemDelegate {
    id: root

    objectName: "tokenSelectorAssetDelegate_" + name

    required property string name
    required property string symbol
    required property string currencyBalanceAsString
    required property string iconSource
    required property bool isAutoHovered

    property var balancesModel
    property real currentBalance: 0

    /** when >= 0 the row stands for this single chain (the list isn't scoped to
        one chain, so each holding is listed per chain) instead of the aggregate **/
    property int chainId: -1

    property string networkIconUrl: {
        root.balancesTracker.revision
        if (!root.balancesModel || !root.balancesModel.ModelCount.count)
            return ""
        if (root.chainId >= 0)
            return SQUtils.ModelUtils.getByKey(root.balancesModel, "chainId", root.chainId, "iconUrl") ?? ""
        return SQUtils.ModelUtils.get(root.balancesModel, 0, "iconUrl") ?? ""
    }

    property string cryptoBalanceStr: currentBalance > 0
        ? LocaleUtils.currencyAmountToLocaleString({amount: currentBalance, displayDecimals: 2}, {noSymbol: true})
        : ""
    property var tokensModel

    property int fallbackChainId: -1

    signal contractAddressClicked()

    readonly property int resolvedChainId: {
        root.balancesTracker.revision
        // only its revision re-triggers this lookup
        root.tokensTracker.revision
        const tokensCount = !!tokensModel ? tokensModel.ModelCount.count : 0
        if (!tokensCount)
            return -1
        let chain = root.chainId
        if (chain < 0 && !!balancesModel && balancesModel.ModelCount.count > 0)
            chain = SQUtils.ModelUtils.get(root.balancesModel, 0, "chainId")
        if (chain < 0)
            chain = root.fallbackChainId
        if (chain < 0 && tokensCount === 1)
            chain = SQUtils.ModelUtils.get(tokensModel, 0, "chainId")
        return chain
    }

    property string tokenAddress: {
        root.tokensTracker.revision
        if (root.resolvedChainId < 0 || !tokensModel || !tokensModel.ModelCount.count)
            return ""
        const key = SQUtils.ModelUtils.getByKey(tokensModel, "chainId", root.resolvedChainId, "key")
        return !!key ? Utils.getChainAndAddressFromTokenKey(key).address : ""
    }
    property string defaultNetworkIcon

    readonly property SQUtils.ModelChangeTracker balancesTracker: SQUtils.ModelChangeTracker {
        model: root.balancesModel
    }

    readonly property SQUtils.ModelChangeTracker tokensTracker: SQUtils.ModelChangeTracker {
        model: root.tokensModel
    }

    readonly property string effectiveNetworkIcon: !!networkIconUrl ? networkIconUrl : defaultNetworkIcon
    readonly property bool hasNetworkBadge: !!effectiveNetworkIcon
    readonly property bool hasAddressChip: !!tokenAddress && tokenAddress !== Constants.zeroAddress

    spacing: Theme.halfPadding
    horizontalPadding: Theme.padding
    verticalPadding: 4

    opacity: enabled ? 1 : 0.3
    implicitHeight: 60

    icon.width: 40
    icon.height: 40
    icon.source: iconSource

    background: Rectangle {
        radius: Theme.radius
        color: root.hovered || root.isAutoHovered
               ? Theme.palette.baseColor2
               : root.highlighted
                 ? Theme.palette.statusListItem.highlightColor
                 : "transparent"

        HoverHandler {
            cursorShape: root.enabled ? Qt.PointingHandCursor : undefined
        }
    }

    contentItem: RowLayout {
        spacing: root.spacing

        TokenIconWithNetworkBadge {
            Layout.preferredWidth: root.icon.width
            Layout.preferredHeight: root.icon.height

            image.source: root.icon.source
            networkIcon: root.hasNetworkBadge ? Assets.svg(root.effectiveNetworkIcon) : ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StatusBaseText {
                objectName: "tokenName"
                Layout.fillWidth: true
                text: root.name
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.halfPadding

                StatusBaseText {
                    text: root.symbol
                    color: Theme.palette.baseColor1
                }

                Rectangle {
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: addressRow.implicitWidth + 12
                    radius: Theme.radius
                    color: Theme.palette.baseColor2
                    visible: root.hasAddressChip

                    RowLayout {
                        id: addressRow
                        anchors.centerIn: parent
                        spacing: 4

                        StatusBaseText {
                            text: SQUtils.Utils.elideAndFormatWalletAddress(root.tokenAddress)
                            color: Theme.palette.baseColor1
                            font.pixelSize: Theme.tertiaryTextFontSize
                            font.family: Fonts.monoFont.family
                        }
                        StatusIcon {
                            width: 12
                            height: 12
                            icon: "external"
                            color: Theme.palette.baseColor1
                        }
                    }

                    MouseArea {
                        objectName: "addressChipMouseArea"
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.contractAddressClicked()
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            visible: !!root.currencyBalanceAsString || !!root.cryptoBalanceStr

            StatusBaseText {
                Layout.alignment: Qt.AlignRight
                text: root.cryptoBalanceStr
                font.weight: Font.Medium
                visible: !!text
            }
            StatusBaseText {
                Layout.alignment: Qt.AlignRight
                text: root.currencyBalanceAsString
                color: Theme.palette.baseColor1
                font.pixelSize: Theme.additionalTextSize
                visible: !!text
            }
        }
    }
}
