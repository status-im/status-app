import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QtModelsToolkit

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import shared.controls
import utils

/**
  * The share picker:
  * header, swipeable tab pages (optionally narrowed to the selection), and
  * the composer.
  * Store-free: model + payload in, sendRequested/cancelRequested out.
  */
Control {
    id: root

    required property var model

    property string text
    property var imagePaths: []
    property var emojiPopup: null
    property var stickersPopup: null
    // Recipient cap; unticked rows are disabled once it is reached.
    property int maxDestinations: 5
    property bool unlimitedImages: true

    readonly property int selectedCount: shareSelection.count

    signal sendRequested(var destinations, string text, var imagePaths)
    signal cancelRequested()

    function reset() {
        shareSelection.clear()
        searchBox.text = ""
        d.searchActive = false
        d.selectedOnly = false
        tabBar.currentIndex = ShareDestinationTabBar.Tab.All
        composer.reset()
    }

    QtObject {
        id: d

        property bool searchActive: false
        property bool selectedOnly: false

        // Selected destinations in the model's (ranking) order
        function selectedDestinations() {
            const result = []
            const count = root.model.ModelCount.count
            for (let i = 0; i < count; i++) {
                const row = ModelUtils.get(root.model, i)
                if (shareSelection.contains(row.chatId))
                    result.push({ sectionId: row.sectionId, chatId: row.chatId })
            }
            return result
        }
    }

    // Not named "selection" — the same name on TabList (ShareDestinationList's
    // own "selection" property) would shadow this id inside the component
    // block below and self-bind instead of referencing it.
    ShareSelection {
        id: shareSelection
        maxCount: root.maxDestinations
    }

    // A destination that stops being postable leaves the adaptor output;
    // drop it from the selection too.
    Connections {
        target: root.model
        function onRowsRemoved() { shareSelection.retainOnly(root.model) }
        function onModelReset() { shareSelection.retainOnly(root.model) }
    }

    Connections {
        target: shareSelection
        function onChanged() {
            if (shareSelection.count === 0)
                d.selectedOnly = false
        }
    }

    component TabList: ShareDestinationList {
        model: root.model
        selection: shareSelection
        selectedOnly: d.selectedOnly
        searchPhrase: searchBox.text
        onToggleRequested: chatId => shareSelection.toggle(chatId)
    }

    padding: 0

    contentItem: ColumnLayout {
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.preferredHeight: 56
            spacing: 0

            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Share")
                font.pixelSize: 19
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StatusFlatRoundButton {
                id: selectedToggle
                objectName: "shareDestinationPickerSelectedToggle"
                icon.name: "check-round-rect-cut"
                icon.color: Theme.palette.primaryColor1
                type: StatusFlatRoundButton.Type.Tertiary
                visible: shareSelection.count > 0
                highlighted: d.selectedOnly
                onClicked: {
                    d.selectedOnly = !d.selectedOnly
                    if (d.selectedOnly)
                        tabBar.currentIndex = ShareDestinationTabBar.Tab.All
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: selectedToggle.radius / 2
                    width: 16
                    height: 16
                    color: "transparent"
                    StatusBaseText {
                        anchors.centerIn: parent
                        text: shareSelection.count
                        font.pixelSize: Theme.asideTextFontSize
                        font.weight: Font.DemiBold
                        color: Theme.palette.primaryColor1
                    }
                }
            }

            StatusFlatRoundButton {
                objectName: "shareDestinationPickerSearchToggle"
                icon.name: "search"
                icon.color: Theme.palette.primaryColor1
                type: StatusFlatRoundButton.Type.Tertiary
                highlighted: d.searchActive
                onClicked: {
                    d.searchActive = !d.searchActive
                    if (!d.searchActive)
                        searchBox.text = ""
                    else
                        searchBox.forceActiveFocus()
                }
            }

            StatusFlatRoundButton {
                objectName: "shareDestinationPickerCancelButton"
                icon.name: "close"
                icon.color: Theme.palette.primaryColor1
                type: StatusFlatRoundButton.Type.Tertiary
                onClicked: root.cancelRequested()
            }
        }

        SearchBox {
            id: searchBox
            objectName: "shareDestinationPickerSearchBox"
            Layout.fillWidth: true
            Layout.leftMargin: Theme.halfPadding
            Layout.rightMargin: Theme.halfPadding
            Layout.bottomMargin: Theme.halfPadding
            visible: d.searchActive
            placeholderText: qsTr("Search chats and channels")
        }

        ShareDestinationTabBar {
            id: tabBar
            objectName: "shareDestinationPickerTabBar"
            Layout.fillWidth: true
            Layout.leftMargin: Theme.halfPadding
            Layout.rightMargin: Theme.halfPadding
            position: {
                const view = swipeView.contentItem
                if (!view || swipeView.width <= 0)
                    return tabBar.currentIndex
                return (view.contentX - view.originX) / swipeView.width
            }
            onCurrentIndexChanged: swipeView.currentIndex = currentIndex
        }

        Item {
            id: pagesHost
            Layout.fillWidth: true
            Layout.fillHeight: true

            SwipeView {
                id: swipeView
                objectName: "shareDestinationPickerTabs"
                anchors.fill: parent
                clip: true
                onCurrentIndexChanged: tabBar.currentIndex = currentIndex

                Repeater {
                    id: pagesRepeater
                    model: [allComponent, contactsComponent, groupsComponent, communitiesComponent]

                    // Adding pages as children one at a time makes
                    // Container's own currentIndex auto-track the
                    // last-added page while nothing else claims the
                    // property (it ends up on Communities, not All).
                    // Reclaim it once every page has landed, in the same
                    // synchronous call chain as that internal auto-advance
                    // (itemAdded's index order isn't guaranteed to match
                    // insertion order, so count is the reliable signal).
                    onItemAdded: (index, item) => {
                        if (pagesRepeater.count === model.length)
                            swipeView.currentIndex = ShareDestinationTabBar.Tab.All
                    }

                    Loader {
                        id: pageLoader

                        required property var modelData
                        property bool activated: false
                        readonly property bool near: SwipeView.isCurrentItem || SwipeView.isNextItem
                                                     || SwipeView.isPreviousItem

                        active: activated
                        asynchronous: true
                        sourceComponent: modelData

                        onNearChanged: if (near) activated = true
                        Component.onCompleted: if (near) activated = true
                    }
                }
            }
        }

        ShareComposer {
            id: composer
            objectName: "shareDestinationPickerComposer"
            Layout.fillWidth: true
            text: root.text
            imagePaths: root.imagePaths
            emojiPopup: root.emojiPopup
            stickersPopup: root.stickersPopup
            sendEnabled: shareSelection.count > 0
            unlimitedImages: root.unlimitedImages
            onSendRequested: (text, imagePaths) =>
                root.sendRequested(d.selectedDestinations(), text, imagePaths)
        }
    }

    Component { id: allComponent; TabList {} }
    Component { id: contactsComponent; TabList { chatTypeFilter: Constants.chatType.oneToOne } }
    Component { id: groupsComponent; TabList { chatTypeFilter: Constants.chatType.privateGroupChat } }
    Component { id: communitiesComponent; TabList { chatTypeFilter: Constants.chatType.communityChat } }
}
