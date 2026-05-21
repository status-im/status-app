import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme

import utils

import QtModelsToolkit

DropArea {
    id: root
    objectName: "manageTokensDelegate-%1".arg(index)

    // expected roles: key, symbol, name, communityId, communityName, communityImage, collectionUid, collectionName, imageUrl
    // + enabledNetworkBalance, enabledNetworkCurrencyBalance

    property var controller
    property int visualIndex: index
    property alias dragParent: delegate.dragParent
    property alias dragEnabled: delegate.dragEnabled
    property alias bgColor: delegate.bgColor
    property bool isHidden // inside the "Hidden" section
    property int count
    property bool isCollectible

    readonly property alias title: delegate.title
    readonly property var balances: model.balances
    readonly property bool isCommunityToken: !!model.communityId

    readonly property var priv: QtObject {
        id: priv
        readonly property int iconSize: root.isCollectible ? 44 : 32
        readonly property int bgRadius: root.isCollectible ? Theme.radius : iconSize/2
    }

    property var getCurrencyAmount: function (balance, key) {}
    property var getCurrentCurrencyAmount: function(balance){}

    SequentialAnimation {
        id: removeAnimation
        PropertyAction { target: root; property: "ListView.delayRemove"; value: true }
        NumberAnimation { target: root; property: "scale"; to: 0; easing.type: Easing.InOutQuad }
        PropertyAction { target: root; property: "ListView.delayRemove"; value: false }
    }

    ListView.onRemove: removeAnimation.start()

    keys: isCommunityToken ? ["x-status-draggable-community-token-item"] : ["x-status-draggable-regular-token-item"]
    width: ListView.view ? ListView.view.width : 0
    height: delegate.height

    onEntered: function(drag) {
        const from = drag.source.visualIndex
        const to = delegate.visualIndex
        if (to === from)
            return

        ListView.view.model.moveItem(from, to)
        drag.accept()
    }

    StatusDraggableListItem {
        id: delegate
        objectName: "draggableDelegate"

        visualIndex: index
        Drag.keys: root.keys
        Drag.hotSpot.x: root.width/2
        Drag.hotSpot.y: root.height/2
        draggable: true

        width: root.width
        title: model.name

        readonly property real totalBalance: aggregator.value/(10 ** model.decimals)

        secondaryTitle: root.isCollectible ? (root.isCommunityToken ? qsTr("Community minted") : model.collectionName || model.collectionUid) :
                                             hovered || menuBtn.menuVisible ? "%1 • %2".arg(LocaleUtils.currencyAmountToLocaleString(root.getCurrencyAmount(totalBalance, model.key)))
                                                                              .arg(!model.communityId ? LocaleUtils.currencyAmountToLocaleString(root.getCurrentCurrencyAmount(totalBalance * model.marketDetails.currencyPrice.amount)):
                                                                                                        LocaleUtils.currencyAmountToLocaleString(root.getCurrentCurrencyAmount(0)))
                                                                            : LocaleUtils.currencyAmountToLocaleString(root.getCurrencyAmount(totalBalance, model.key))
        bgRadius: priv.bgRadius
        hasImage: true
        icon.source: {
            // TODO unify via backend model for both assets and collectibles; handle communityPrivilegesLevel
            let source = model.imageUrl
            if (source === "")
                source = Constants.tokenIcon(model.symbol)
            return source
        }
        icon.width: priv.iconSize
        icon.height: priv.iconSize
        spacing: 12
        assetBgColor: model.backgroundColor

        actions: [
            ManageTokensCommunityTag {
                Layout.maximumWidth: delegate.width *.4
                visible: !!model.communityId
                communityImage: model.communityImage
                communityName: model.communityName
                communityId: model.communityId
            },
            ManageTokenMenuButton {
                id: menuBtn
                objectName: "btnManageTokenMenu-%1".arg(currentIndex)
                currentIndex: root.visualIndex
                count: root.count
                inHidden: root.isHidden
                groupId: isCollection ? model.collectionUid : model.communityId
                isCommunityToken: root.isCommunityToken
                isCollectible: root.isCollectible
                isCollection: isCollectible && !model.isSelfCollection && !isCommunityToken
                onMoveRequested: (from, to) => root.ListView.view.model.moveItem(from, to)
                onShowHideRequested: function(key, flag) {
                    if (isCommunityToken)
                        root.controller.showHideCommunityToken(key, flag)
                    else
                        root.controller.showHideRegularToken(key, flag)
                    if (!flag) {
                        const msg = isCollectible ? qsTr("%1 was successfully hidden").arg(delegate.title)
                                                  : qsTr("%1 (%2) was successfully hidden").arg(delegate.title).arg(key)
                        Global.displayToastMessage(msg, "", "checkmark-circle", false, Constants.ephemeralNotificationType.success, "")
                    }
                }
                onShowHideGroupRequested: function(groupId, flag) {
                    if (isCommunityToken)
                        root.controller.showHideGroup(groupId, flag)
                    else
                        root.controller.showHideCollectionGroup(groupId, flag)
                }
            }
        ]

        SumAggregator {
            id: aggregator
            model: root.balances ?? null
            roleName: "balance"
        }
    }
}
