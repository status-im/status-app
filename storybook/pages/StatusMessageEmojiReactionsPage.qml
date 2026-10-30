import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme
import StatusQ.Components.private as MessagePrivate

import Storybook
import Models

SplitView {
    id: root

    Logs { id: logs }

    ListModel {
        id: reactionsModel

        // Takes a copy, so toggling and adding reactions don't change the shared data
        function reset(reactions) {
            clear()
            for (const reaction of reactions)
                append(Object.assign({}, reaction))
        }

        function indexOf(hexcode) {
            for (let i = 0; i < count; ++i)
                if (get(i).emoji === hexcode)
                    return i
            return -1
        }

        // What the app's backend does when the user taps a reaction
        function toggle(hexcode) {
            const i = indexOf(hexcode)
            if (i === -1) {
                append({
                    emoji: hexcode,
                    didIReactWithThisEmoji: true,
                    numberOfReactions: 1,
                    jsonArrayOfUsersReactedWithThisEmoji: JSON.stringify(["You"])
                })
                return
            }

            const reaction = get(i)
            const users = JSON.parse(reaction.jsonArrayOfUsersReactedWithThisEmoji)
            const reacted = reaction.didIReactWithThisEmoji

            if (reacted && reaction.numberOfReactions === 1) {
                remove(i)
                return
            }

            setProperty(i, "didIReactWithThisEmoji", !reacted)
            setProperty(i, "numberOfReactions", reaction.numberOfReactions + (reacted ? -1 : 1))
            setProperty(i, "jsonArrayOfUsersReactedWithThisEmoji",
                        JSON.stringify(reacted ? users.filter(user => user !== "You") : ["You"].concat(users)))
        }
    }

    QtObject {
        id: d

        readonly property var reactionsModels: ReactionsModels {}

        // Added in turn by the "add reaction" button, in place of the emoji popup
        readonly property var emojisToAdd: ["1f525", "1f44f", "1f914", "1f64f", "1f680", "1f60d",
                                            "1f622", "1f621", "1f440", "2705", "1f4af", "1f973"]

        function nextEmojiToAdd() {
            return emojisToAdd.find(hexcode => reactionsModel.indexOf(hexcode) === -1) ?? ""
        }

        function resetReactions() {
            reactionsModel.reset(reactionsSetSelector.currentIndex === 0 ? []
                                 : reactionsSetSelector.currentIndex === 1 ? d.reactionsModels.threeReactions
                                                                           : d.reactionsModels.twentyReactions)
        }
    }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Rectangle {
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            color: Theme.palette.statusAppLayout.rightPanelBackgroundColor
            clip: true

            // The width a message row gives the reactions, so the wrapping can be checked
            Rectangle {
                anchors.centerIn: parent
                width: widthSlider.value
                height: reactions.height + 2
                color: "transparent"
                border.width: 1
                border.color: "lightgray"

                MessagePrivate.StatusMessageEmojiReactions {
                    id: reactions

                    x: 1
                    y: 1
                    width: parent.width - 2

                    enabled: !disabledCheckBox.checked
                    reactionsModel: reactionsModel
                    limitReached: reactionsModel.count >= maxReactionsSpinBox.value
                    messageHighlighted: highlightedCheckBox.checked

                    onAddEmojiClicked: (sender, mouse) => {
                        logs.logEvent("StatusMessageEmojiReactions::addEmojiClicked")
                        const hexcode = d.nextEmojiToAdd()
                        if (hexcode)
                            reactionsModel.toggle(hexcode)
                    }
                    onToggleReaction: (hexcode) => {
                        logs.logEvent("StatusMessageEmojiReactions::toggleReaction", ["hexcode"], arguments)
                        reactionsModel.toggle(hexcode)
                    }
                    onHoverChanged: (hovered) => logs.logEvent("StatusMessageEmojiReactions::hoverChanged",
                                                               ["hovered"], arguments)
                }
            }
        }

        LogsAndControlsPanel {
            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 200

            logsView.logText: logs.logText

            ColumnLayout {
                anchors.fill: parent

                RowLayout {
                    Label { text: "Reactions:" }

                    ComboBox {
                        id: reactionsSetSelector

                        model: ["None", "Three", "Twenty"]
                        currentIndex: 1

                        onCurrentIndexChanged: d.resetReactions()
                        Component.onCompleted: d.resetReactions()
                    }

                    Button {
                        text: "Reset"
                        onClicked: d.resetReactions()
                    }
                }

                RowLayout {
                    Label { text: "Width:" }

                    Slider {
                        id: widthSlider

                        from: 120
                        to: 800
                        value: 400
                        stepSize: 1
                    }

                    Label { text: `${widthSlider.value}px` }
                }

                RowLayout {
                    Label { text: "Max reactions per message:" }

                    SpinBox {
                        id: maxReactionsSpinBox

                        from: 1
                        to: 30
                        value: 20
                    }

                    Label { text: `(${reactionsModel.count} now, limit ${reactions.limitReached ? "reached" : "not reached"})` }
                }

                CheckBox {
                    id: highlightedCheckBox
                    text: "Message highlighted (hovered or active)"
                }

                CheckBox {
                    id: disabledCheckBox
                    text: "Disabled (reactions not allowed)"
                }
            }
        }
    }
}

// category: Components
// status: good
