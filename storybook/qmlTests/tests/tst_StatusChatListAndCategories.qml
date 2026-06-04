import QtQuick
import QtTest

import StatusQ.Components
import StatusQ.Core.Utils as SQUtils
import StatusQ.Popups

Item {
    id: root

    width: 400
    height: 600

    readonly property string testCategoryId: "cat1"
    readonly property string testCategoryName: "Category in general"
    readonly property string testChannelName: "general"
    readonly property string testAddedChannelName: "New Channel"
    readonly property string testEditedCategoryName: "Renamed Category"

    readonly property var initialChatsModelData: [
        {
            itemId: "cat1",
            categoryId: "cat1",
            name: "Category in general",
            active: false,
            notificationsCount: 0,
            hasUnreadMessages: false,
            icon: "",
            isCategory: true,
            categoryOpened: true,
            muted: false,
            shouldBeHiddenBecausePermissionsAreNotMet: false
        },
        {
            itemId: "ch_general",
            categoryId: "cat1",
            name: "general",
            active: false,
            notificationsCount: 0,
            hasUnreadMessages: false,
            color: "",
            colorId: 1,
            icon: "",
            muted: false,
            isCategory: false,
            categoryOpened: true,
            shouldBeHiddenBecausePermissionsAreNotMet: false
        }
    ]

    ListModel {
        id: chatsModel

        Component.onCompleted: root.resetModel()
    }

    function resetModel() {
        chatsModel.clear()
        chatsModel.append(initialChatsModelData)
    }

    function addChannelToCategory(categoryId, channelName, itemId) {
        chatsModel.append({
            itemId: itemId,
            categoryId: categoryId,
            name: channelName,
            active: false,
            notificationsCount: 0,
            hasUnreadMessages: false,
            color: "",
            colorId: 2,
            icon: "",
            muted: false,
            isCategory: false,
            categoryOpened: true,
            shouldBeHiddenBecausePermissionsAreNotMet: false
        })
    }

    function applyCategoryCollapsed(categoryId, collapsed) {
        const opened = !collapsed
        for (let i = 0; i < chatsModel.count; ++i) {
            if (chatsModel.get(i).categoryId === categoryId)
                chatsModel.setProperty(i, "categoryOpened", opened)
        }
    }

    function findCategoryModelEntry(categoryId) {
        return SQUtils.ModelUtils.getFirstModelEntryIf(chatsModel, (item) =>
            item.isCategory && (item.categoryId === categoryId || item.itemId === categoryId))
    }

    function findCategoryModelIndex(categoryId) {
        const entry = findCategoryModelEntry(categoryId)
        return entry ? SQUtils.ModelUtils.indexOf(chatsModel, "itemId", entry.itemId) : -1
    }

    function setCategoryMuted(categoryId, muted) {
        const index = findCategoryModelIndex(categoryId)
        if (index >= 0)
            chatsModel.setProperty(index, "muted", muted)
    }

    function renameCategory(categoryId, categoryName) {
        const index = findCategoryModelIndex(categoryId)
        if (index >= 0)
            chatsModel.setProperty(index, "name", categoryName)
    }

    function deleteCategory(categoryId) {
        for (let i = chatsModel.count - 1; i >= 0; --i) {
            const item = chatsModel.get(i)
            if (item.isCategory && (item.categoryId === categoryId || item.itemId === categoryId)) {
                chatsModel.remove(i)
            } else if (!item.isCategory && item.categoryId === categoryId) {
                chatsModel.setProperty(i, "categoryId", "")
                chatsModel.setProperty(i, "categoryOpened", true)
            }
        }
    }

    Component {
        id: categoryMenuComponent
        StatusMenu {
            id: contextMenuCategory
            property var categoryItem

            StatusAction {
                objectName: "muteCategoryMenuItem"
                enabled: !!contextMenuCategory.categoryItem && !contextMenuCategory.categoryItem.muted
                text: qsTr("Mute category")
                icon.name: "notification-muted"
                onTriggered: {
                    const categoryId = contextMenuCategory.categoryItem.itemId
                    root.setCategoryMuted(categoryId, true)
                    contextMenuCategory.close()
                }
            }

            StatusAction {
                objectName: "unmuteCategoryMenuItem"
                enabled: !!contextMenuCategory.categoryItem && contextMenuCategory.categoryItem.muted
                text: qsTr("Unmute category")
                icon.name: "notification"
                onTriggered: {
                    const categoryId = contextMenuCategory.categoryItem.itemId
                    root.setCategoryMuted(categoryId, false)
                    contextMenuCategory.close()
                }
            }

            StatusAction {
                objectName: "editCategoryMenuItem"
                text: qsTr("Edit Category")
                icon.name: "edit"
                onTriggered: {
                    const categoryId = contextMenuCategory.categoryItem.itemId
                    root.renameCategory(categoryId, root.testEditedCategoryName)
                    contextMenuCategory.close()
                }
            }

            StatusAction {
                objectName: "deleteCategoryMenuItem"
                text: qsTr("Delete Category")
                icon.name: "delete"
                type: StatusAction.Type.Danger
                onTriggered: {
                    const categoryId = contextMenuCategory.categoryItem.itemId
                    root.deleteCategory(categoryId)
                    contextMenuCategory.close()
                }
            }
        }
    }

    Component {
        id: chatListPopupMenuComponent
        Item {
            function popup(x, y) {}
        }
    }

    Component {
        id: componentUnderTest
        StatusChatListAndCategories {
            width: 288
            height: parent.height
            showCategoryActionButtons: true
            showPopupMenu: true
            model: chatsModel
            categoryPopupMenu: categoryMenuComponent
            chatListPopupMenu: chatListPopupMenuComponent

            onToggleCollapsedCommunityCategory: (categoryId, collapsed) =>
                root.applyCategoryCollapsed(categoryId, collapsed)

            onCategoryAddButtonClicked: (categoryId) =>
                root.addChannelToCategory(categoryId, root.testAddedChannelName, "ch_new")
        }
    }

    SignalSpy {
        id: toggleCollapsedSpy
        signalName: "toggleCollapsedCommunityCategory"
    }

    SignalSpy {
        id: categoryAddButtonSpy
        signalName: "categoryAddButtonClicked"
    }

    property StatusChatListAndCategories controlUnderTest: null

    TestCase {
        name: "StatusChatListAndCategories"
        when: windowShown

        function init() {
            resetModel()
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            toggleCollapsedSpy.target = controlUnderTest
            categoryAddButtonSpy.target = controlUnderTest
            toggleCollapsedSpy.clear()
            categoryAddButtonSpy.clear()
            waitForRendering(controlUnderTest)
        }

        function cleanup() {
            toggleCollapsedSpy.clear()
            categoryAddButtonSpy.clear()
            resetModel()
        }

        function getCategoryItem() {
            const categoryItem = findChild(controlUnderTest, "categoryItem")
            verify(!!categoryItem)
            return categoryItem
        }

        function getCategoryDropArea(categoryName) {
            categoryName = categoryName ?? root.testCategoryName
            const dropArea = findChild(controlUnderTest, categoryName)
            verify(!!dropArea)
            return dropArea
        }

        function getChannelDropArea(channelName) {
            const dropArea = findChild(controlUnderTest, channelName)
            verify(!!dropArea)
            return dropArea
        }

        function verifyChannelVisible(channelName, expectedVisible) {
            channelName = channelName ?? root.testChannelName
            const dropArea = getChannelDropArea(channelName)
            waitForRendering(controlUnderTest)
            if (expectedVisible)
                verify(dropArea.height > 0, `Channel ${channelName} should be visible`)
            else
                compare(dropArea.height, 0)
        }

        function getToggleButton(categoryItem) {
            const toggle = findChild(categoryItem, "categoryItemButtonToggle")
            verify(!!toggle)
            return toggle
        }

        function getToggleRotation(categoryItem) {
            return getToggleButton(categoryItem).icon.rotation
        }

        function openCategoryMoreMenu(categoryItem) {
            categoryItem.highlighted = true
            categoryItem.menuButtonClicked({button: Qt.LeftButton})
            waitForRendering(controlUnderTest)
        }

        function triggerCategoryMenuAction(objectName) {
            const action = findChild(controlUnderTest, objectName)
            verify(!!action, `Menu action ${objectName} not found`)
            action.trigger()
            waitForRendering(controlUnderTest)
        }

        function test_category_expanded_by_default() {
            const categoryItem = getCategoryItem()
            compare(getToggleRotation(categoryItem), 0)
            verifyChannelVisible(root.testChannelName, true)
        }

        function test_click_category_collapses() {
            const categoryItem = getCategoryItem()
            mouseClick(getCategoryDropArea())
            tryCompare(toggleCollapsedSpy, "count", 1)
            compare(toggleCollapsedSpy.signalArguments[0][0], root.testCategoryId)
            compare(toggleCollapsedSpy.signalArguments[0][1], true)
            verifyChannelVisible(root.testChannelName, false)
            compare(getToggleRotation(categoryItem), 270)
        }

        function test_click_category_expands() {
            const categoryItem = getCategoryItem()
            mouseClick(getCategoryDropArea())
            verifyChannelVisible(root.testChannelName, false)
            mouseClick(getCategoryDropArea())
            tryCompare(toggleCollapsedSpy, "count", 2)
            compare(toggleCollapsedSpy.signalArguments[1][1], false)
            verifyChannelVisible(root.testChannelName, true)
            compare(getToggleRotation(categoryItem), 0)
        }

        function test_toggle_button_collapses() {
            const categoryItem = getCategoryItem()
            compare(getToggleRotation(categoryItem), 0)
            mouseClick(getToggleButton(categoryItem))
            tryCompare(toggleCollapsedSpy, "count", 1)
            compare(toggleCollapsedSpy.signalArguments[0][1], true)
            verifyChannelVisible(root.testChannelName, false)
            compare(getToggleRotation(categoryItem), 270)
        }

        function test_toggle_after_collapse_expands() {
            const categoryItem = getCategoryItem()
            mouseClick(getCategoryDropArea())
            verifyChannelVisible(root.testChannelName, false)
            compare(getToggleRotation(categoryItem), 270)
            mouseClick(getToggleButton(categoryItem))
            verifyChannelVisible(root.testChannelName, true)
            compare(getToggleRotation(categoryItem), 0)
        }

        function test_more_button_after_collapse_expands() {
            const categoryItem = getCategoryItem()
            mouseClick(getCategoryDropArea())
            compare(getToggleRotation(categoryItem), 270)
            mouseClick(getToggleButton(categoryItem))
            compare(getToggleRotation(categoryItem), 0)
            categoryItem.highlighted = true
            const moreButton = findChild(categoryItem, "categoryItemButtonMore")
            verify(!!moreButton)
            tryCompare(moreButton, "visible", true)
            categoryItem.menuButtonClicked({button: Qt.LeftButton})
            compare(getToggleRotation(categoryItem), 0)
        }

        function test_add_button_keeps_category_expanded() {
            const categoryItem = getCategoryItem()
            mouseClick(getCategoryDropArea())
            compare(getToggleRotation(categoryItem), 270)
            mouseClick(getToggleButton(categoryItem))
            compare(getToggleRotation(categoryItem), 0)
            categoryItem.highlighted = true
            const addButton = findChild(categoryItem, "categoryItemButtonAdd")
            verify(!!addButton)
            tryCompare(addButton, "visible", true)
            categoryItem.addButtonClicked({button: Qt.LeftButton})
            compare(getToggleRotation(categoryItem), 0)
            verifyChannelVisible(root.testChannelName, true)
        }

        function test_add_channel_via_add_button_persists_after_collapse_expand() {
            const categoryItem = getCategoryItem()
            categoryItem.highlighted = true
            const addButton = findChild(categoryItem, "categoryItemButtonAdd")
            verify(!!addButton)
            tryCompare(addButton, "visible", true)

            categoryItem.addButtonClicked({button: Qt.LeftButton})
            tryCompare(categoryAddButtonSpy, "count", 1)
            compare(categoryAddButtonSpy.signalArguments[0][0], root.testCategoryId)
            waitForRendering(controlUnderTest)

            verifyChannelVisible(root.testChannelName, true)
            verifyChannelVisible(root.testAddedChannelName, true)

            mouseClick(getCategoryDropArea())
            verifyChannelVisible(root.testAddedChannelName, false)
            compare(getToggleRotation(categoryItem), 270)

            mouseClick(getToggleButton(categoryItem))
            verifyChannelVisible(root.testAddedChannelName, true)
            verifyChannelVisible(root.testChannelName, true)
            compare(getToggleRotation(categoryItem), 0)
        }

        function test_mute_category_via_more_menu() {
            const categoryItem = getCategoryItem()
            compare(categoryItem.muted, false)
            openCategoryMoreMenu(categoryItem)
            triggerCategoryMenuAction("muteCategoryMenuItem")
            compare(root.findCategoryModelEntry(root.testCategoryId).muted, true)
            tryCompare(getCategoryItem(), "muted", true)
        }

        function test_unmute_category_via_more_menu() {
            root.setCategoryMuted(root.testCategoryId, true)
            waitForRendering(controlUnderTest)
            const categoryItem = getCategoryItem()
            compare(categoryItem.muted, true)
            openCategoryMoreMenu(categoryItem)
            triggerCategoryMenuAction("unmuteCategoryMenuItem")
            compare(root.findCategoryModelEntry(root.testCategoryId).muted, false)
            tryCompare(getCategoryItem(), "muted", false)
        }

        function test_edit_category_via_more_menu() {
            const categoryItem = getCategoryItem()
            openCategoryMoreMenu(categoryItem)
            triggerCategoryMenuAction("editCategoryMenuItem")
            compare(root.findCategoryModelEntry(root.testCategoryId).name, root.testEditedCategoryName)
            tryCompare(getCategoryItem(), "text", root.testEditedCategoryName)
            verify(!findChild(controlUnderTest, root.testCategoryName))
            verify(!!getCategoryDropArea(root.testEditedCategoryName))
        }

        function test_delete_category_via_more_menu() {
            const categoryItem = getCategoryItem()
            openCategoryMoreMenu(categoryItem)
            triggerCategoryMenuAction("deleteCategoryMenuItem")
            compare(root.findCategoryModelIndex(root.testCategoryId), -1)
            verify(!findChild(controlUnderTest, root.testCategoryName))
            verifyChannelVisible(root.testChannelName, true)
        }
    }
}
