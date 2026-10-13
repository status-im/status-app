import QtQuick
import QtTest

import AppLayouts.Communities.models
import AppLayouts.Communities.views

Item {
    id: root

    ListModel { id: channels }
    ListModel { id: permissions }
    ListModel { id: replacementChannels }

    ChannelsSelectionModel {
        id: selection
        sourceModel: channels
    }

    Component {
        id: editorComponent

        ChannelPermissionsModelEditor {
            channelsModel: channels
            permissionsModel: permissions
            channelId: "unsaved"
            name: "Unsaved channel"
            color: "blue"
            emoji: ""
            newChannelMode: true
        }
    }

    Component {
        id: selectionComponent
        ChannelsSelectionModel {}
    }

    TestCase {
        name: "ChannelsSelectionModel"

        function row(id, isThread, isCategory) {
            return {
                itemId: id, name: id, icon: "", emoji: "", color: "blue",
                isThread: isThread, isCategory: isCategory
            }
        }

        function ids(model) {
            const result = []
            for (let i = 0; i < model.count; ++i)
                result.push(model.get(i).key)
            return result
        }

        function init() {
            channels.append([row("category", false, true), row("channel", false, false),
                             row("thread", true, false)])
        }

        function cleanup() {
            channels.clear()
            replacementChannels.clear()
        }

        function test_rolesAndFiltering() {
            tryCompare(selection, "count", 2)
            compare(ids(selection), ["category", "channel"])
            compare(selection.get(1).text, "#channel")
            compare(selection.get(1).isCategory, false)
            compare(channels.count, 3)
            channels.append(row("new-thread", true, false))
            compare(ids(selection), ["category", "channel"])
            channels.setProperty(2, "isThread", false)
            tryCompare(selection, "count", 3)
            compare(ids(selection), ["category", "channel", "thread"])
            channels.setProperty(1, "isThread", true)
            tryCompare(selection, "count", 2)
            compare(ids(selection), ["category", "thread"])
            channels.remove(2)
            tryCompare(selection, "count", 1)
            channels.clear()
            tryCompare(selection, "count", 0)
            channels.append(row("only-thread", true, false))
            compare(ids(selection), [])
            channels.clear()
            channels.append(row("restored", false, false))
            tryCompare(selection, "count", 1)
            compare(ids(selection), ["restored"])
        }

        function test_unsavedChannelRemainsSelectable() {
            const editor = createTemporaryObject(editorComponent, root)
            verify(!!editor)
            const transformed = createTemporaryObject(selectionComponent, root, {
                sourceModel: editor.liveChannelsModel
            })
            verify(!!transformed)
            tryCompare(transformed, "count", 3)
            compare(ids(transformed), ["category", "channel", "unsaved"])
            compare(transformed.get(2).text, "#Unsaved channel")
            compare(transformed.get(2).isThread, false)
            compare(channels.count, 3)
        }

        function test_sourceReplacement() {
            const transformed = createTemporaryObject(selectionComponent, root, {
                sourceModel: channels
            })
            verify(!!transformed)
            compare(ids(transformed), ["category", "channel"])
            replacementChannels.append([row("replacement-thread", true, false),
                                        row("replacement-channel", false, false)])
            transformed.sourceModel = replacementChannels
            tryCompare(transformed, "count", 1)
            compare(ids(transformed), ["replacement-channel"])
            transformed.sourceModel = null
            tryCompare(transformed, "count", 0)
            transformed.sourceModel = channels
            tryCompare(transformed, "count", 2)
            compare(ids(transformed), ["category", "channel"])
        }
    }
}
