import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Models
import Storybook

import AppLayouts.Communities.popups
import AppLayouts.Chat.stores

Item {
    id: root

    Component.onCompleted: openPopup()

    function openPopup() {
        popupComponent.createObject(root).open()
    }

    Button {
        anchors.centerIn: parent
        text: "Reopen"
        onClicked: openPopup()
    }

    ChannelsModel {
        id: channelsModel
    }

    Component {
        id: popupComponent
        CreateCategoryPopup {
            visible: true
            modal: false
            closePolicy: Popup.NoAutoClose
            store: RootStore {
                readonly property var chatCommunitySectionModule: QtObject {
                    readonly property var editCategoryChannelsModel: channelsModel
                    readonly property var model: channelsModel
                }
                function prepareEditCategoryModel() {}
                function createCommunityCategory(name, channels) {
                    console.info("RootStore.createCommunityCategory(name, channels):", name, channels)
                }
                function editCommunityCategory(id, name, channels) {
                    console.info("RootStore.editCommunityCategory(id, name, channels):", id, name, channels)
                }
                function deleteCommunityCategory(id) {
                    console.info("RootStore.deleteCommunityCategory(id):", id)
                }
            }
            communityId: "foo"
            categoryId: isEdit ? "_support" : ""
            categoryName: isEdit ? "Sample category name" : ""
            isEdit: ctrlIsEdit.checked
        }
    }

    CheckBox {
        id: ctrlIsEdit
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 16
        text: "is edit?"
    }
}

// category: Popups
// status: good
