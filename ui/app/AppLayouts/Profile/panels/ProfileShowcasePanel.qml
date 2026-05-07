import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml
import QtQml.Models

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Core.Theme
import StatusQ.Controls.Validators

import shared.controls
import utils

import AppLayouts.Profile.controls

import QtModelsToolkit
import SortFilterProxyModel

DoubleFlickableWithFolding {
    id: root

    property Component delegate: ProfileShowcasePanelDelegate {}

    // Expected roles:
    // - visibility: int
    property var inShowcaseModel
    property var hiddenModel

    property Component additionalFooterComponent

    // Placeholder text to be shown when the list is empty
    property string emptyInShowcasePlaceholderText
    property string emptyHiddenPlaceholderText
    property string emptySearchPlaceholderText

    property int showcaseLimit: 100

    // Searcher related properties:
    property string searchPlaceholderText
    readonly property alias searcherText: d.searcherText

    //SFPM filters to apply to both in showcase and hidden models
    property FastExpressionFilter filter

    // Signal to request position change of the visible items
    signal changePositionRequested(int from, int to)

    // Signal to request visibility change of the items
    signal setVisibilityRequested(var key, int toVisibility)

    ScrollBar.vertical: StatusScrollBar {
        policy: ScrollBar.AsNeeded
        visible: resolveVisibility(policy, root.height, root.contentHeight)
    }

    QtObject {
        id: d

        readonly property bool limitReached: root.showcaseLimit === inShowcaseCounterTracker.count
        readonly property bool searchActive: root.searcherText !== ""
        property string searcherText: ""

        readonly property var dragHiddenItemKey: ["x-status-draggable-showcase-item-hidden"]
        readonly property var dragShowcaseItemKey: ["x-status-draggable-showcase-item"]

        property bool isAnyShowcaseDragActive: false
        onIsAnyShowcaseDragActiveChanged: {
            if(!isAnyShowcaseDragActive) {
                // Sync the order of the visible items when the drag is finished
                // MovableModel is used only for DND operations. No interference needed when the DND is not active
                visibleModel.syncOrder()
            }
        }
        property bool isAnyHiddenDragActive: false

        property int additionalHeaderComponentWidth: 350 // by design
        property int additionalHeaderComponentHeight: 40 // by design

        property bool startAnimation: false

        property var dragItem: null

        signal setVisibilityInternalRequested(var key, int toVisibility)
        onSetVisibilityInternalRequested: {
            if(toVisibility !== Constants.ShowcaseVisibility.NoOne) {
                startAnimation = !startAnimation
            }
            root.setVisibilityRequested(key, toVisibility)
        }
    }

    ModelChangeTracker {
        id: inShowcaseCounterTracker

        property int count: {
            revision
            return model.rowCount()
        }

        model: root.inShowcaseModel
    }

    SortFilterProxyModel {
        id: inShowcaseSFPM

        sourceModel: root.inShowcaseModel
        delayed: true
        filters: root.filter
    }

    SortFilterProxyModel {
        id: hiddenSFPM

        sourceModel: root.hiddenModel
        delayed: true
        filters: root.filter
    }

    MovableModel {
        id: visibleModel

        sourceModel: inShowcaseSFPM
    }

    clip: true

    flickable1: EmptyShapeRectangleFooterListView {
        id: inShowcaseListView

        model: visibleModel
        width: root.width
        placeholderText: d.searchActive ? root.emptySearchPlaceholderText : root.emptyInShowcasePlaceholderText
        footerHeight: ProfileUtils.defaultDelegateHeight
        footerContentVisible: !dropAreaRow.visible
        spacing: Theme.halfPadding
        delegate: delegateWrapper
        header: ColumnLayout {
            width: ListView.view.width
            spacing: 0

            SearchBox {
                id: searcher

                Layout.fillWidth: true

                placeholderText: root.searchPlaceholderText
                validator: RXValidator {
                    regularExpression: Constants.regularExpressions.alphanumericalExpanded1
                }

                Binding {
                    target: d
                    property: "searcherText"
                    value: searcher.text
                    restoreMode: Binding.RestoreBindingOrValue
                }
            }

            FoldableHeader {
                readonly property bool isDropAreaVisible: root.flickable1Folded && d.isAnyHiddenDragActive

                Layout.fillWidth: true

                title: qsTr("In showcase")
                folded: root.flickable1Folded
                rightAdditionalComponent: isDropAreaVisible && d.limitReached ? limitReachedHeaderButton :
                                                                                isDropAreaVisible ? dropHeaderAreaComponent : counterComponent

                Component {
                    id: counterComponent
                    StatusBaseText {
                        id: counterText

                        width: d.additionalHeaderComponentWidth
                        height: d.additionalHeaderComponentHeight
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        text: "%1 / %2".arg(inShowcaseCounterTracker.count).arg(root.showcaseLimit)
                        font.pixelSize: Theme.tertiaryTextFontSize
                        color: Theme.palette.baseColor1

                        ColorAnimation {
                            id: animateColor
                            target: counterText
                            properties: "color"
                            from: Theme.palette.successColor1
                            to: Theme.palette.baseColor1
                            duration: 2000
                        }

                        Connections {
                            target: d
                            function onStartAnimationChanged() {
                                animateColor.start()
                            }
                        }
                    }
                }

                Component {
                    id: dropHeaderAreaComponent
                    VisibilityDropAreaButtonsRow {
                        margins: 0
                        width: d.additionalHeaderComponentWidth
                        height: d.additionalHeaderComponentHeight
                    }
                }

                Component {
                    id: limitReachedHeaderButton
                    VisibilityDropAreaButton {
                        width: d.additionalHeaderComponentWidth
                        height: d.additionalHeaderComponentHeight
                        rightInset: 1
                        text: qsTr("Showcase limit of %1 reached").arg(root.showcaseLimit)
                        enabled: false
                        textColor: Theme.palette.baseColor1
                        iconVisible: false
                    }
                }

                onToggleFolding: root.flip1Folding()
            }
        }

        // Overlaid showcase listview content drop area:
        DropArea {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.contentHeight
            keys: d.dragHiddenItemKey

            // Shown at the bottom of the listview
            VisibilityDropAreaButtonsRow {
                id: dropAreaRow

                width: parent.width
                height: ProfileUtils.defaultDelegateHeight
                anchors.bottom: parent.bottom
                visible: !d.limitReached &&
                         (d.isAnyHiddenDragActive ||
                          parent.containsDrag ||
                          everyoneContainsDrag ||
                          contactsContainsDrag)
            }
        }

        // Overlaid showcase listview content when limit reached:
        VisibilityDropAreaButton {
            id: limitReachedButton

            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.halfPadding
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Theme.padding
            height: ProfileUtils.defaultDelegateHeight - Theme.padding
            visible: d.isAnyHiddenDragActive && d.limitReached
            enabled: false
            text: qsTr("Showcase limit of %1 reached").arg(root.showcaseLimit)
            textColor: Theme.palette.baseColor1
            iconVisible: false
        }
    }

    flickable2: EmptyShapeRectangleFooterListView {
        id: hiddenListView

        model: hiddenSFPM
        width: root.width
        placeholderText: d.searchActive ? root.emptySearchPlaceholderText : root.emptyHiddenPlaceholderText
        footerHeight: ProfileUtils.defaultDelegateHeight
        footerContentVisible: !hiddenDropAreaButton.visible
        additionalFooterComponent: root.additionalFooterComponent
        spacing: Theme.halfPadding
        delegate: delegateWrapper

        header: FoldableHeader {
            width: ListView.view.width
            title: qsTr("Hidden")
            folded: root.flickable2Folded
            rightAdditionalComponent: VisibilityDropAreaButton {
                visible: root.flickable2Folded && (d.isAnyShowcaseDragActive || parent.containsDrag || containsDrag)
                width: d.additionalHeaderComponentWidth
                height: d.additionalHeaderComponentHeight
                rightInset: 1
                text: qsTr("Hide")
                dropAreaKeys: d.dragShowcaseItemKey
            }

            onToggleFolding: root.flip2Folding()
        }

        // Overlaid hidden listview content drop area:
        DropArea {
            anchors.top: parent.top
            width: parent.width
            height: parent.contentHeight
            keys: d.dragShowcaseItemKey

            // Shown at the top of the listview
            VisibilityDropAreaButton {
                id: hiddenDropAreaButton

                anchors.top: parent.top
                anchors.topMargin: hiddenListView.headerItem.height + Theme.padding
                anchors.horizontalCenter: parent.horizontalCenter

                visible: d.isAnyShowcaseDragActive || parent.containsDrag || hiddenDropAreaButton.containsDrag
                width: parent.width - Theme.padding
                height: ProfileUtils.defaultDelegateHeight - Theme.padding
                text: qsTr("Hide")
                dropAreaKeys: d.dragShowcaseItemKey
                
            }
        }
    }

    component VisibilityDropAreaButton: AbstractButton {
        id: visibilityDropAreaButton

        readonly property alias containsDrag: dropArea.containsDrag

        property bool iconVisible: true
        property string textColor: icon.color
        property int showcaseVisibility: Constants.ShowcaseVisibility.NoOne
        property var dropAreaKeys: []

        padding: Theme.halfPadding
        spacing: padding/2

        icon.color: Theme.palette.primaryColor1

        visible: d.dragItem && d.dragItem.showcaseMaxVisibility >= showcaseVisibility

        background: Rectangle {
            id: shapeWrapper

            color: dropArea.containsDrag ? Theme.palette.primaryColor3 : StatusColors.getColor(Theme.palette.baseColor4, 0.7)
            radius: Theme.radius
            
            ShapeRectangle {
                anchors.fill: parent
                anchors.margins: path.strokeWidth / 2
                radius: shapeWrapper.radius
                path.strokeColor: dropArea.containsDrag ? Theme.palette.primaryColor3 : Theme.palette.directColor7
                path.fillColor: "transparent"
                DropArea {
                    id: dropArea

                    anchors.fill: parent
                    keys: visibilityDropAreaButton.dropAreaKeys

                    onEntered: function(drag) {
                        drag.accept()
                    }

                    onDropped: function(drop) {
                        d.setVisibilityInternalRequested(drop.source.key, visibilityDropAreaButton.showcaseVisibility)
                    }
                }
            }
        }

        contentItem: Item {
            RowLayout {
                width: Math.min(parent.width, implicitWidth)
                anchors.centerIn: parent
                spacing: visibilityDropAreaButton.spacing

                StatusIcon {
                    visible: visibilityDropAreaButton.iconVisible
                    width: 20
                    height: width
                    icon: ProfileUtils.visibilityIcon(visibilityDropAreaButton.showcaseVisibility)
                    color: visibilityDropAreaButton.icon.color
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    color: visibilityDropAreaButton.textColor
                    text: visibilityDropAreaButton.text
                }
            }
        }
    }

    component VisibilityDropAreaButtonsRow: Item {
        id: visibilityDropAreaRow

        readonly property bool everyoneContainsDrag: dropAreaEveryone.containsDrag
        readonly property bool contactsContainsDrag: dropAreaContacts.containsDrag
        property int margins: Theme.halfPadding

        RowLayout {
            anchors.fill: parent
            anchors.margins: visibilityDropAreaRow.margins
            spacing: Theme.halfPadding

            VisibilityDropAreaButton {
                id: dropAreaEveryone
                Layout.fillWidth: true
                Layout.fillHeight: true
                showcaseVisibility: Constants.ShowcaseVisibility.Everyone
                text: qsTr("Everyone")
                dropAreaKeys: d.dragHiddenItemKey
            }

            VisibilityDropAreaButton {
                id: dropAreaContacts
                Layout.fillWidth: true
                Layout.fillHeight: true
                showcaseVisibility: Constants.ShowcaseVisibility.Contacts
                text: qsTr("Contacts")
                dropAreaKeys: d.dragHiddenItemKey
            }
        }
    }

    component ShadowDelegate: Rectangle {
        width: parent.width
        height: ProfileUtils.defaultDelegateHeight
        anchors.centerIn: parent
        color: Theme.palette.baseColor5
        radius: Theme.radius
    }

    Component {
        id: delegateWrapper
        DropArea {
            id: showcaseDelegateRoot

            required property var model
            required property int index
            readonly property int visualIndex: index
            readonly property bool isHiddenShowcaseItem: !model.showcaseVisibility || model.showcaseVisibility === Constants.ShowcaseVisibility.NoOne

            function handleEntered(drag) {
                if (!showcaseDelegateRoot.isHiddenShowcaseItem) {
                    var from = drag.source.visualIndex
                    var to = visualIndex
                    if (to === from)
                        return
                    
                    const sourceIndex = inShowcaseSFPM.mapToSource(visibleModel.order()[from])
                    const targetPosition = showcaseDelegateRoot.model.showcasePosition
                    visibleModel.move(from, to)
                    root.changePositionRequested(sourceIndex, targetPosition)
                }
                drag.accept()
            }
            function handleDropped(drop) {
                if (showcaseDelegateRoot.isHiddenShowcaseItem) {
                    d.setVisibilityInternalRequested(drop.source.key, Constants.ShowcaseVisibility.NoOne)
                }
            }

            SequentialAnimation {
                id: removeAnimation
                PropertyAction { target: showcaseDelegateRoot; property: "ListView.delayRemove"; value: true }
                NumberAnimation { target: showcaseDelegateRoot; property: "scale"; to: 0; easing.type: Easing.InOutQuad }
                PropertyAction { target: showcaseDelegateRoot; property: "ListView.delayRemove"; value: false }
            }

            ListView.onRemove: removeAnimation.start()

            width: ListView.view.width
            height: showcaseDraggableDelegateLoader.item ? showcaseDraggableDelegateLoader.item.height : 0
            keys: d.dragShowcaseItemKey

            onEntered: handleEntered(drag)
            onDropped: handleDropped(drop)

            // In showcase delegate item container:
            Loader {
                id: showcaseDraggableDelegateLoader

                property var modelData: showcaseDelegateRoot.model
                property var dragParentData: root
                property int visualIndexData: showcaseDelegateRoot.index
                property var dragKeysData: showcaseDelegateRoot.isHiddenShowcaseItem ?
                                               d.dragHiddenItemKey : d.dragShowcaseItemKey

                width: parent.width
                sourceComponent: root.delegate
                onItemChanged: {
                    if (item) {
                        item.showcaseVisibilityRequested.connect((toVisibility) => d.setVisibilityInternalRequested(showcaseDelegateRoot.model.showcaseKey, toVisibility))
                    }
                }
            }

            Binding {
                when: showcaseDelegateRoot.isHiddenShowcaseItem ? d.isAnyShowcaseDragActive : (d.isAnyHiddenDragActive ||
                                                                                               (d.isAnyHiddenDragActive && d.limitReached))
                target: showcaseDraggableDelegateLoader.item
                property: "blurState"
                value: true
                restoreMode: Binding.RestoreBindingOrValue
            }

            Binding {
                when: showcaseShadow.visible
                target: d
                property: showcaseDelegateRoot.isHiddenShowcaseItem ? "isAnyHiddenDragActive" : "isAnyShowcaseDragActive"
                value: true
                restoreMode: Binding.RestoreBindingOrValue
            }

            Binding {
                when: showcaseDelegateRoot.isHiddenShowcaseItem && d.limitReached
                target: showcaseDraggableDelegateLoader.item
                property: "contextMenuEnabled"
                value: false
                restoreMode: Binding.RestoreBindingOrValue
            }

            Binding {
                when: showcaseDelegateRoot.isHiddenShowcaseItem && d.limitReached
                target: showcaseDraggableDelegateLoader.item
                property: "tooltipTextWhenContextMenuDisabled"
                value: qsTr("Showcase limit of %1 reached. <br>Remove item from showcase to add more.").arg(root.showcaseLimit)
                restoreMode: Binding.RestoreBindingOrValue
            }

            Binding {
                when: showcaseDraggableDelegateLoader.item && showcaseDraggableDelegateLoader.item.dragActive
                target: d
                property: "dragItem"
                value: showcaseDraggableDelegateLoader.item
                restoreMode: Binding.RestoreBindingOrValue
            }

            // Delegate shadow background when dragging:
            ShadowDelegate {
                id: showcaseShadow

                visible: showcaseDraggableDelegateLoader.item && showcaseDraggableDelegateLoader.item.dragActive
            }
        }
    }
}
