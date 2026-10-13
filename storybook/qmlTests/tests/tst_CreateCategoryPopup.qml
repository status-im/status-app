import QtQuick
import QtQuick.Window
import QtTest

import AppLayouts.Chat.stores
import AppLayouts.Communities.popups

import utils

Item {
    id: root

    width: 1000
    height: 900

    property var submittedIds: []
    property string submittedCategoryId

    Window {
        id: testWindow
        width: root.width
        height: root.height
        visible: true
    }

    ListModel { id: chatsModel }
    ListModel { id: editChatsModel }

    RootStore {
        id: testStore

        chatCommunitySectionModule: QtObject {
            readonly property var model: chatsModel
            readonly property var editCategoryChannelsModel: editChatsModel
        }

        function prepareEditCategoryModel(categoryId) {}
        function createCommunityCategory(name, channels) {
            root.submittedIds = JSON.parse(channels)
            return ""
        }
        function editCommunityCategory(id, name, channels) {
            root.submittedCategoryId = id
            root.submittedIds = JSON.parse(channels)
            return ""
        }
    }

    Component {
        id: popupComponent

        CreateCategoryPopup {
            store: testStore
            communityId: "community"
            categoryId: "_support"
            categoryName: "Support"
            destroyOnClose: false
        }
    }

    TestCase {
        name: "CreateCategoryPopup"
        when: windowShown

        function channel(id, categoryId, isThread) {
            return {
                itemId: id, name: id, categoryId: categoryId,
                type: Constants.chatType.communityChat, isCategory: false,
                isThread: isThread, icon: "", emoji: "", color: "blue"
            }
        }

        function init() {
            chatsModel.append([
                channel("welcome", "", false),
                channel("welcome-thread", "", true),
                channel("faq", "_support", false),
                channel("faq-thread", "_support", true)
            ])
            for (let i = 0; i < chatsModel.count; ++i)
                editChatsModel.append(chatsModel.get(i))
            chatsModel.append(channel("other", "_other", false))
            chatsModel.append({
                itemId: "_support", name: "Support", categoryId: "_support",
                type: Constants.chatType.category, isCategory: true,
                isThread: false, icon: "", emoji: "", color: "blue"
            })
            root.submittedIds = []
            root.submittedCategoryId = ""
        }

        function cleanup() {
            chatsModel.clear()
            editChatsModel.clear()
            testWindow.width = root.width
            testWindow.height = root.height
        }

        function openPopup(isEdit, portrait) {
            testWindow.width = portrait ? 390 : root.width
            testWindow.height = portrait ? 844 : root.height
            const popup = createTemporaryObject(popupComponent, testWindow.contentItem, { isEdit })
            verify(!!popup)
            popup.open()
            tryCompare(popup, "opened", true)
            tryVerify(() => !!popup.hostedItem)
            return popup
        }

        function channelList(popup) {
            const list = findChild(popup.hostedItem, "createOrEditCommunityCategoryChannelList")
            verify(!!list)
            return list
        }

        function ids(list) {
            const result = []
            for (let i = 0; i < list.model.count; ++i)
                result.push(list.model.get(i).itemId)
            return result
        }

        function test_selectionAndSubmission_data() {
            return [
                { tag: "create-desktop", isEdit: false, portrait: false },
                { tag: "edit-desktop", isEdit: true, portrait: false },
                { tag: "create-portrait", isEdit: false, portrait: true },
                { tag: "edit-portrait", isEdit: true, portrait: true }
            ]
        }

        function test_selectionAndSubmission(data) {
            const popup = openPopup(data.isEdit, data.portrait)
            const list = channelList(popup)
            tryCompare(list, "count", data.isEdit ? 2 : 1)
            compare(ids(list), data.isEdit ? ["welcome", "faq"] : ["welcome"])
            list.forceLayout()
            tryVerify(() => !!list.itemAtIndex(0)?.item)
            list.itemAtIndex(0).item.components[0].click()
            if (!data.isEdit)
                popup.hostedItem.categoryName.text = "New category"
            const saveButton = popup.footerRightButtons.get(1)
            tryCompare(saveButton, "enabled", true)
            saveButton.clicked()
            compare(root.submittedIds.slice().sort(), data.isEdit ? ["faq", "welcome"] : ["welcome"])
            compare(root.submittedCategoryId, data.isEdit ? "_support" : "")
        }

        function test_dynamicFiltering() {
            const popup = openPopup(false, false)
            const list = channelList(popup)
            tryCompare(list, "count", 1)
            const newThreadIndex = chatsModel.count
            chatsModel.append(channel("new-thread", "", true))
            compare(ids(list), ["welcome"])
            chatsModel.append(channel("new-channel", "", false))
            tryCompare(list, "count", 2)
            compare(ids(list), ["welcome", "new-channel"])
            chatsModel.setProperty(newThreadIndex, "isThread", false)
            tryCompare(list, "count", 3)
            compare(ids(list), ["welcome", "new-thread", "new-channel"])
            chatsModel.remove(newThreadIndex)
            tryCompare(list, "count", 2)
            chatsModel.clear()
            tryCompare(list, "count", 0)
            chatsModel.append(channel("only-thread", "", true))
            compare(ids(list), [])
            popup.close()
        }
    }
}
