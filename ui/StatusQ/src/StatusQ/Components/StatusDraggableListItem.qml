import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Core.Theme

/*!
   \qmltype StatusDraggableListItem
   \inherits QtQuickControls::AbstractButton
   \inqmlmodule StatusQ.Components
   \since StatusQ.Components 0.1
   \brief It is a list item with the ability to be dragged and dropped to reorder within a list view. Inherits from \c QtQuickControls::AbstractButton.

   The \c StatusDraggableListItem is a list item with a (smartident)icon, title and a subtitle on the left side, and optional actions on the right.

   It displays a drag handle on its left side

   Example of how to use it:

   \qml
        StatusListView {
            id: linksView
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.socialLinksModel

            displaced: Transition {
                NumberAnimation { properties: "x,y"; easing.type: Easing.OutQuad }
            }

            delegate: DropArea {
                id: delegateRoot

                property int visualIndex: index

                width: ListView.view.width
                height: draggableDelegate.height

                keys: ["x-status-draggable-list-item-internal"]

                onEntered: function(drag) {
                    const from = drag.source.visualIndex
                    const to = draggableDelegate.visualIndex
                    if (to === from)
                        return
                    functionToMoveTo(from, to, 1)
                    drag.accept()
                }

                onDropped: function(drop) {
                    functionToSave(true)
                }

                StatusDraggableListItem {
                    id: draggableDelegate

                    readonly property string asideText: ProfileUtils.stripSocialLinkPrefix(model.url, model.linkType)

                    visible: !!asideText
                    width: parent.width
                    height: visible ? implicitHeight : 0

                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }

                    dragParent: linksView
                    visualIndex: delegateRoot.visualIndex
                    draggable: linksView.count > 1
                    title: ProfileUtils.linkTypeToText(model.linkType) || model.text
                    icon.name: model.icon
                    icon.color: ProfileUtils.linkTypeColor(model.linkType, Theme.palette)
                    actions: [
                        StatusLinkText {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignRight
                            horizontalAlignment: Text.AlignRight
                            font.pixelSize: Theme.primaryTextFontSize
                            font.weight: Font.Normal
                            text: draggableDelegate.asideText
                            onClicked: Global.requestOpenLink(model.url)
                        },
                        StatusFlatRoundButton {
                            icon.name: "edit_pencil"
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            icon.width: 16
                            icon.height: 16
                            type: StatusFlatRoundButton.Type.Tertiary
                            tooltip.text: qsTr("Edit link")
                            onClicked: Global.openPopup(modifySocialLinkModal,
                                                        {linkType: model.linkType, icon: model.icon, uuid: model.uuid,
                                                            linkText: model.text, linkUrl: draggableDelegate.asideText})
                        }
                    ]
                }
            }
        }
   \endqml

   For a list of components available see StatusQ.
*/
AbstractButton {
    id: root

    /*!
       \qmlproperty string StatusDraggableListItem::title
       This property holds the primary text (title)
    */
    property string title: text
    /*!
       \qmlproperty string StatusDraggableListItem::secondaryTitle
       This property holds the secondary text (title), displayed below primary
    */
    property string secondaryTitle
    /*!
       \qmlproperty string StatusDraggableListItem::secondaryTitleIcon
       This property holds the secondary title icon, displayed on the right of the secondary title
    */
    property string secondaryTitleIcon: ""

    /*!
       \qmlproperty list<Item> StatusDraggableListItem::actions
       This property holds the optional list of actions, displayed on the right side.
       The actions are reparented into a RowLayout.
    */
    property alias actions: actionsRow.children

    /*!
       \qmlproperty Item StatusDraggableListItem::dragParent
       This property holds the drag parent (the Item that this Item gets reparented to when being dragged)
    */
    property Item dragParent
    /*!
       \qmlproperty int StatusDraggableListItem::visualIndex
       This property holds the persistent visual index of this item's parent (usually a DropArea)
    */
    property int visualIndex
    /*!
       \qmlproperty bool StatusDraggableListItem::draggable
       This property holds whether the drag handle is displayed
    */
    property bool draggable
    /*!
       \qmlproperty bool StatusDraggableListItem::dragEnabled
       This property holds whether this item can be dragged (and whether the drag handle is displayed)
    */
    property bool dragEnabled: draggable

    property bool highlighted // NB: compat with ItemDelegate

    /*!
        \qmlsignal
        This signal is emitted when the StatusDraggableListItem is clicked.
    */
    signal clicked(var mouse)

    /*!
       \qmlproperty int StatusDraggableListItem::dragAxis
       This property holds whether this item can be dragged along the x-axis (Drag.XAxis), y-axis (Drag.YAxis),
       or both (Drag.XAndYAxis). Defaults to Drag.YAxis
    */
    property int dragAxis: Drag.YAxis

    /*!
       \qmlproperty bool StatusDraggableListItem::hasIcon
       This property holds whether this item wants to display an icon (using a StatusIcon); use `icon.name`
       Defaults to false
    */
    property bool hasIcon: false
    /*!
       \qmlproperty bool StatusDraggableListItem::hasImage
       This property holds whether this item wants to display an image (using a StatusRoundedImage); use `icon.source`
       Specifying `icon.name` adds a fallback to a letter identicon (using StatusLetterIdenticon).
       Defaults to false
    */
    property bool hasImage: false
    /*!
       \qmlproperty bool StatusDraggableListItem::hasEmoji
       This property holds whether this item wants to display an emoji (using a StatusLetterIdenticon); use `icon.name`
       Defaults to false
    */
    property bool hasEmoji: false

    /*!
       \qmlproperty int StatusDraggableListItem::bgRadius
       This property holds the background corner radius in pixels (if the background is visible)
       Defaults to "rounded", half of the icon width or height
    */
    property int bgRadius: icon.height/2
    /*!
       \qmlproperty color StatusDraggableListItem::bgColor
       This property holds background color, if any
       Defaults to "transparent" (ie no background)
    */
    property color bgColor: "transparent"

    /*!
       \qmlproperty color StatusDraggableListItem::assetBgColor
       This property holds icon/image background color, if any
       Defaults to "transparent" (ie no background)
    */
    property color assetBgColor: "transparent"

    /*!
       \qmlproperty bool StatusDraggableListItem::containsMouse
       Used to read if the component contains mouse
    */
    readonly property bool containsMouse: root.hovered

    /*!
       \qmlproperty bool StatusDraggableListItem::changeColorOnDragActive
       This property holds if background color will be changed on drag active or not
       Defaults to "dragActive" (ie background will change on dragActive = true)
    */
    property bool changeColorOnDragActive: dragActive

    /*!
       \qmlproperty bool StatusDraggableListItem::showDragHandle
       This property holds if drag handle is visible when component is draggable
    */
    property bool showDragHandle: true

    /*!
       \qmlproperty bool StatusDraggableListItem::dragByHandleOnly
       This property holds if drag is activated only via drag handler (true) or
       the whole area of the delegate (false). By default false on desktop, true
       on mobile.
    */
    property bool dragByHandleOnly: Utils.isMobile

    /*!
       \qmlproperty bool StatusDraggableListItem::drawBackgroundBorder
       This property holds if background is rendered with border
    */
    property bool drawBackgroundBorder: true

    Drag.dragType: Drag.Automatic
    Drag.hotSpot.x: pointerDrag.centroid.position.x
    Drag.hotSpot.y: pointerDrag.centroid.position.y
    Drag.keys: ["x-status-draggable-list-item-internal"]

    /*!
       \qmlproperty readonly bool StatusDraggableListItem::dragActive
       This property holds whether a drag is currently in progress
    */
    readonly property bool dragActive: pointerDrag.active
    onDragActiveChanged: {
        if (dragActive) {
            d.freezeEnclosingFlickables()
            Drag.start()
            root.dragStarted()
            return
        }
        Drag.drop()
        root.dragFinished()
        d.unfreezeEnclosingFlickables()
    }

    QtObject {
        id: d

        // Enclosing Flickables force-cancel the drag's exclusive grab once
        // real pointer movement crosses their flick threshold (their steal
        // path never consults handler grabPermissions), so they are frozen
        // for the drag's duration. Restoring writes the property back, which
        // drops any host binding on `interactive` — hosts with a dynamic
        // binding there must freeze themselves instead.
        property var frozenFlickables: []

        function freezeEnclosingFlickables() {
            const frozen = []
            for (let p = root.parent; p; p = p.parent) {
                if (p instanceof Flickable && p.interactive) {
                    p.interactive = false
                    frozen.push(p)
                }
            }
            frozenFlickables = frozen
        }

        function unfreezeEnclosingFlickables() {
            for (const flickable of frozenFlickables)
                flickable.interactive = true
            frozenFlickables = []
        }
    }

    // a dropped-on reorder can destroy this delegate before dragActive
    // transitions — the frozen flickables outlive it and must be released
    Component.onDestruction: d.unfreezeEnclosingFlickables()

    /*!
        \qmlsignal
        This signal is emitted when dragging the StatusDraggableListItem item started.
    */
    signal dragStarted()

    /*!
        \qmlsignal
        This signal is emitted when dragging the StatusDraggableListItem item finished.
    */
    signal dragFinished()

    states: [
        State {
            when: root.dragActive
            ParentChange {
                target: root
                parent: root.dragParent
            }

            AnchorChanges {
                target: root
                anchors.horizontalCenter: undefined
                anchors.verticalCenter: undefined
            }
        }
    ]

    background: Rectangle {
        implicitHeight: 76 // ProfileUtils.defaultDelegateHeight
        color: root.changeColorOnDragActive && root.drawBackgroundBorder ? StatusColors.alphaColor(Theme.palette.baseColor2, 0.7) : root.bgColor
        border.width: root.drawBackgroundBorder ? 1 : 0
        border.color: Theme.palette.baseColor2
        radius: root.drawBackgroundBorder ? Theme.radius : 0
    }

    // inset to simulate spacing
    topInset: 4
    bottomInset: 4

    horizontalPadding: 12
    verticalPadding: 16
    spacing: 8

    icon.width: 20
    icon.height: 20

    StatusMouseArea {
        anchors.fill: parent

        acceptedButtons: Qt.LeftButton | Qt.RightButton

        // Left taps are handled by TapHandlers — MouseArea.clicked depends on
        // the delivery agent's hover chain, which goes stale on panel
        // roundtrips and silently eats taps (see StatusChatListItem). A
        // TapHandler only coexists with the exclusive mouse grab when it sits
        // on the grabbing item itself, so each grabbing area carries its own,
        // gated by which one takes row presses in the current mode.
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                root.clicked(mouse)
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            // this area takes row presses when the full-row dragHandler is
            // parented to the drag handle instead (mobile)
            enabled: root.dragByHandleOnly
            onTapped: (eventPoint, button) => {
                root.clicked({ button: Qt.LeftButton, x: eventPoint.position.x,
                               y: eventPoint.position.y, modifiers: 0, accepted: true })
            }
        }
    }

    // Qt6: use a TapHandler with a regular contentItem, and derive again from ItemDelegate
    StatusMouseArea {
        id: dragHandler

        parent: root.dragByHandleOnly ? dragHandleIcon : root

        anchors.fill: parent
        // the actual dragging lives in pointerDrag (DragHandler) — this area
        // keeps the cursor, composed-click propagation and long-press. No
        // preventStealing: it would also refuse the DragHandler's takeover.
        propagateComposedEvents: true // handle mouse click from MouseArea below

        // The drag mechanics. A MouseArea's `drag` measures movement against
        // its own (moving) item and barely moves a target it sits inside of;
        // DragHandler computes in scene space and tracks the pointer exactly.
        // It must live on the item that grabs the press — handlers of items
        // below the grabber are never visited.
        DragHandler {
            id: pointerDrag
            target: root.dragEnabled ? root : null
            xAxis.enabled: root.dragAxis === Drag.XAxis || root.dragAxis === Drag.XAndYAxis
            yAxis.enabled: root.dragAxis === Drag.YAxis || root.dragAxis === Drag.XAndYAxis
            // may take the grab over from the pressing MouseArea, but
            // approves no takeover — hosting flickables must not steal it
            grabPermissions: PointerHandler.CanTakeOverFromItems
                             | PointerHandler.CanTakeOverFromHandlersOfDifferentType
        }

        cursorShape: {
            if (!root.enabled)
                return undefined
            if (root.dragEnabled)
                return root.dragActive ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }

        acceptedButtons: Qt.LeftButton | Qt.RightButton

        TapHandler {
            acceptedButtons: Qt.LeftButton
            // full-row drag area takes row presses on desktop; cancels on drag
            enabled: !root.dragByHandleOnly
            onTapped: (eventPoint, button) => {
                root.clicked({ button: Qt.LeftButton, x: eventPoint.position.x,
                               y: eventPoint.position.y, modifiers: 0, accepted: true })
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.leftPadding
        anchors.rightMargin: root.rightPadding
        anchors.topMargin: root.topPadding
        anchors.bottomMargin: root.bottomPadding
        spacing: root.spacing

        StatusIcon {
            id: dragHandleIcon

            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            icon: "justify"
            visible: root.draggable && root.showDragHandle
            color: root.dragEnabled ? Theme.palette.baseColor1 : Theme.palette.baseColor2
        }

        Loader {
            active: !!root.icon.name || !!root.icon.source
            visible: active
            sourceComponent: root.hasIcon && root.assetBgColor ? roundIconComponent :
                                                                 root.hasIcon ? iconComponent : root.hasImage ? imageComponent : letterIdenticonComponent
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.secondaryTitle ? 4 : 0

            StatusBaseText {
                Layout.fillWidth: true
                text: root.title
                visible: text
                elide: Text.ElideRight
                maximumLineCount: 1
                font.weight: Font.Medium
            }

            Row {
                Layout.fillWidth: true
                visible: !!root.secondaryTitle
                spacing: 8

                StatusBaseText {
                    width: Math.min(parent.width - (secondaryTitleIconLoader.item ? parent.spacing + secondaryTitleIconLoader.item.width : 0),
                                    implicitWidth)
                    text: root.secondaryTitle
                    color: Theme.palette.baseColor1
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Loader {
                    id: secondaryTitleIconLoader
                    anchors.verticalCenter: parent.verticalCenter
                    active: !!root.secondaryTitleIcon
                    visible: active
                    sourceComponent: secondaryTitleIconComponent
                }
            }
        }

        RowLayout {
            id: actionsRow
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            spacing: 12
        }
    }

    Component {
        id: iconComponent
        StatusIcon {
            width: root.icon.width
            height: root.icon.height
            icon: root.icon.name
            color: root.icon.color
            source: root.icon.source
        }
    }

    Component {
        id: secondaryTitleIconComponent
        StatusIcon {
            width: 16
            height: 16
            icon: root.secondaryTitleIcon
            color: Theme.palette.baseColor1
        }
    }

    Component {
        id: imageComponent
        StatusRoundedImage {
            radius: root.bgRadius
            color: root.assetBgColor
            width: root.icon.width
            height: root.icon.height
            image.source: root.icon.source
            showLoadingIndicator: true
            image.fillMode: Image.PreserveAspectCrop
        }
    }

    Component {
        id: letterIdenticonComponent
        StatusLetterIdenticon {
            objectName: "identicon"
            width: root.icon.width
            height: root.icon.height
            emoji: root.hasEmoji ? root.icon.name : ""
            name: !root.hasEmoji ? root.icon.name : ""
            letterIdenticonColor: root.icon.color
        }
    }

    Component {
        id: roundIconComponent
        StatusRoundIcon {
            asset.width: root.icon.width
            asset.height: root.icon.height
            asset.name: root.icon.name
            asset.color: root.icon.color
            asset.bgColor: root.assetBgColor
            asset.bgHeight: 40
            asset.bgWidth: 40
        }
    }
}
