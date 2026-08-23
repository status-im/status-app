import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtTest

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: tagDelegate

        Rectangle {
            objectName: "tag_" + index
            width: 100
            height: 24
            color: "red"
        }
    }

    Component {
        id: badgeComponentUnderTest

        StatusListItemBadge {
            primaryText: "badge"
        }
    }

    Component {
        id: listItemComponent

        StatusListItem {
            width: 400
            title: "One"
            tagsDelegate: tagDelegate
            inlineTagDelegate: tagDelegate
        }
    }

    ListModel {
        id: threeRowsModel

        ListElement { name: "a" }
        ListElement { name: "b" }
        ListElement { name: "c" }
    }

    property Item controlUnderTest: null

    TestCase {
        name: "StatusListItem"
        when: windowShown

        function cleanup() {
            if (!!controlUnderTest)
                controlUnderTest.destroy()
        }

        function countByType(item, type) {
            let count = (item instanceof type) ? 1 : 0
            for (const child of item.children)
                count += countByType(child, type)
            return count
        }

        function firstOfType(item, type) {
            if (item instanceof type)
                return item
            for (const child of item.children) {
                const found = firstOfType(child, type)
                if (!!found)
                    return found
            }
            return null
        }

        // The whole point of the deferral: the two tag scroll views are a
        // Flickable each, and an item with no tags must build neither.
        function test_itemWithoutTagsBuildsNoScrollView() {
            controlUnderTest = createTemporaryObject(listItemComponent, root)
            verify(!!controlUnderTest)

            compare(controlUnderTest.tagsCount, 0)
            compare(countByType(controlUnderTest, Flickable), 0,
                    "an item with no tags must not build a tag scroll view")
        }

        function test_tagsBuildOneScrollView() {
            controlUnderTest = createTemporaryObject(listItemComponent, root,
                                                     { tagsModel: threeRowsModel })
            verify(!!controlUnderTest)

            compare(controlUnderTest.tagsCount, 3)
            compare(countByType(controlUnderTest, Flickable), 1)
            verify(!!findChild(controlUnderTest, "tag_2"))
        }

        function test_inlineTagsBuildOneScrollView() {
            controlUnderTest = createTemporaryObject(listItemComponent, root,
                                                     { inlineTagModel: 2 })
            verify(!!controlUnderTest)

            compare(controlUnderTest.tagsCount, 0)
            compare(countByType(controlUnderTest, Flickable), 1)
            verify(!!findChild(controlUnderTest, "tag_1"))
        }

        function test_bothTagRowsBuildTwoScrollViews() {
            controlUnderTest = createTemporaryObject(listItemComponent, root, {
                tagsModel: threeRowsModel,
                inlineTagModel: 2
            })
            verify(!!controlUnderTest)

            compare(countByType(controlUnderTest, Flickable), 2)
        }

        // tagsCount no longer comes from a Repeater, so it has to report the
        // same number for every model kind a Repeater accepts.
        function test_tagsCountFollowsTheModelKind_data() {
            return [
                { tag: "null", model: null, count: 0 },
                { tag: "empty array", model: [], count: 0 },
                { tag: "array", model: ["a", "b"], count: 2 },
                { tag: "zero", model: 0, count: 0 },
                { tag: "number", model: 4, count: 4 },
                { tag: "list model", model: threeRowsModel, count: 3 }
            ]
        }

        function test_tagsCountFollowsTheModelKind(data) {
            controlUnderTest = createTemporaryObject(listItemComponent, root,
                                                     { tagsModel: data.model })
            verify(!!controlUnderTest)

            compare(controlUnderTest.tagsCount, data.count)
            compare(countByType(controlUnderTest, Flickable), data.count > 0 ? 1 : 0)
        }

        function test_scrollViewFollowsTheModelGoingUpAndDown() {
            controlUnderTest = createTemporaryObject(listItemComponent, root)
            verify(!!controlUnderTest)
            compare(countByType(controlUnderTest, Flickable), 0)

            controlUnderTest.tagsModel = threeRowsModel
            compare(controlUnderTest.tagsCount, 3)
            compare(countByType(controlUnderTest, Flickable), 1)

            controlUnderTest.tagsModel = null
            compare(controlUnderTest.tagsCount, 0)
            compare(countByType(controlUnderTest, Flickable), 0,
                    "the scroll view must go away with the tags that needed it")
        }

        function test_tagsWiderThanTheItemStayScrollable() {
            controlUnderTest = createTemporaryObject(listItemComponent, root,
                                                     { tagsModel: 8 })
            verify(!!controlUnderTest)

            const flickable = firstOfType(controlUnderTest, Flickable)
            verify(!!flickable)
            verify(flickable.contentWidth > flickable.width,
                   "eight 100px tags must overflow a 400px item")

            flickable.contentX = 40
            compare(flickable.contentX, 40)
        }

        // The warning icon used to decide its own existence from its own
        // tooltip text, so it had to be built to be found unnecessary.
        function test_errorIconNeedsBothErrorModeAndText() {
            controlUnderTest = createTemporaryObject(listItemComponent, root)
            verify(!!controlUnderTest)
            compare(countByType(controlUnderTest, StatusFlatRoundButton), 0)

            controlUnderTest.errorMode = true
            compare(countByType(controlUnderTest, StatusFlatRoundButton), 0,
                    "error mode without a message must not build the icon")

            controlUnderTest.errorTooltipText = "no balance"
            compare(countByType(controlUnderTest, StatusFlatRoundButton), 1)

            controlUnderTest.errorMode = false
            compare(countByType(controlUnderTest, StatusFlatRoundButton), 0)
        }

        function test_badgeBuildsOnlyWhenOneIsSupplied() {
            controlUnderTest = createTemporaryObject(listItemComponent, root)
            verify(!!controlUnderTest)
            compare(countByType(controlUnderTest, StatusListItemBadge), 0)

            controlUnderTest.badgeComponent = badgeComponentUnderTest
            compare(countByType(controlUnderTest, StatusListItemBadge), 1)
        }

        function test_titleTextIconBuildsOnlyWhenNamed() {
            controlUnderTest = createTemporaryObject(listItemComponent, root)
            verify(!!controlUnderTest)
            const before = countByType(controlUnderTest, StatusIcon)

            controlUnderTest.titleTextIcon = "keycard"
            compare(countByType(controlUnderTest, StatusIcon), before + 1)

            controlUnderTest.titleTextIcon = ""
            compare(countByType(controlUnderTest, StatusIcon), before)
        }

        // The subtitle/tags row is the only RowLayout a plain item needs; the
        // beneath-tags row is built only for the keypair and keycard callers.
        function test_beneathTagsBuildsOnlyWhenAsked() {
            controlUnderTest = createTemporaryObject(listItemComponent, root)
            verify(!!controlUnderTest)
            compare(countByType(controlUnderTest, RowLayout), 1)

            controlUnderTest.beneathTagsTitle = "on a keycard"
            compare(countByType(controlUnderTest, RowLayout), 2)

            controlUnderTest.beneathTagsTitle = ""
            compare(countByType(controlUnderTest, RowLayout), 1)
        }

        function test_tagsSpacing() {
            controlUnderTest = createTemporaryObject(listItemComponent, root, {
                tagsModel: 2,
                tagsSpacing: 30
            })
            verify(!!controlUnderTest)

            const first = findChild(controlUnderTest, "tag_0")
            const second = findChild(controlUnderTest, "tag_1")
            verify(!!first)
            verify(!!second)
            compare(second.x - (first.x + first.width), 30)
        }
    }
}
