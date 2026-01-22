import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Popups.Dialog

import utils

ColumnLayout {
    id: root

    required property var model
    required property Component delegate

    property alias suggestionsModel: suggestionsListView.model
    property alias suggestionsDelegate: suggestionsListView.delegate
    property alias suggestionsDialog: suggestionsDialog
    property size suggestionsDelegateSize: Qt.size(344, 64)
    property alias dirty: confirmButton.enabled

    readonly property alias label: label
    readonly property alias warningLabel: warningLabel
    readonly property alias edit: edit
    readonly property int membersFlickContentWidth: membersFlick.contentWidth

    signal confirmed()
    signal rejected()

    signal enterKeyPressed()
    signal upKeyPressed()
    signal downKeyPressed()

    signal entryAccepted(var suggestionsDelegate)
    signal entryRemoved(var delegate)
    signal textPasted(string text)

    spacing: Theme.halfPadding

    QtObject {
        id: d

        readonly property bool isCompactMode: root.width <= 600

        function paste() {
            root.suggestionsDialog.forceHide = true
            edit.pasteOperation = true
            edit.paste()
            root.textPasted(edit.text)
            edit.pasteOperation = false
        }
    }

    RowLayout {
        Layout.fillWidth: true

        RowLayout {
            id: titleFiller
            visible: d.isCompactMode

            StatusBaseText {
                Layout.fillWidth: true
                Layout.maximumWidth: implicitWidth + 2 * Theme.padding
                text: qsTr("Group Members")
                elide: Text.ElideRight
            }

            // Filler
            Item {
                Layout.fillWidth: true
            }
        }

        LayoutItemProxy {
            Layout.fillWidth: true
            visible: !d.isCompactMode
            target: membersBox
        }

        LayoutItemProxy {
            visible: !d.isCompactMode
            target: confirmButton
        }

        StatusButton {
            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth + 2 * Theme.padding

            text: qsTr("Cancel")
            type: StatusBaseButton.Type.Danger
            onClicked: root.rejected()
        }
    }

    LayoutItemProxy {
        Layout.fillWidth: true
        visible: d.isCompactMode
        target: membersBox
    }

    LayoutItemProxy {
        Layout.fillWidth: true
        visible: d.isCompactMode
        target: confirmButton
    }

    Popup {
        id: suggestionsDialog

        property bool forceHide: false

        parent: membersFlick
        x: 0
        y: parent.height + Theme.halfPadding
        visible: edit.text !== "" && !forceHide
        padding: Theme.halfPadding
        background: StatusDialogBackground {
            id: bg
            layer.enabled: true
            layer.effect: DropShadow {
                source: bg
                horizontalOffset: 0
                verticalOffset: 4
                radius: 12
                samples: 25
                spread: 0.2
                color: Theme.palette.dropShadow
            }
        }

        height: suggestionsListView.count ?
                    Math.min(400, suggestionsListView.count * suggestionsDelegateSize.height + 2 * Theme.padding) :
                    noResultsFoundText.height + 2 * Theme.xlPadding
        width: d.isCompactMode ? Math.min(membersBox.width - membersBox.toLabelWidth - 2 * Theme.halfPadding,
                                          suggestionsDelegateSize.width) : suggestionsDelegateSize.width

        ColumnLayout {
            anchors.fill: parent

            StatusBaseText {
                id: noResultsFoundText

                Layout.fillWidth: true

                horizontalAlignment: Text.AlignHCenter
                visible: root.suggestionsModel.count === 0
                text: qsTr("No results found")
                color: Theme.palette.baseColor1
                elide: Text.ElideRight
            }

            StatusListView {
                id: suggestionsListView

                Layout.fillWidth: true
                Layout.fillHeight: true

                visible: root.suggestionsModel.count

                highlightMoveDuration: 0
                highlightMoveVelocity: -1

                verticalScrollBar {
                    visible: contentHeight > height
                    policy: ScrollBar.AlwaysOn
                }

                onVisibleChanged: currentIndex = 0
                onCountChanged: currentIndex = 0
            }
        }
    }

    // Here the different dynamic layout items definition:
    StatusButton {
        id: confirmButton

        objectName: "inlineSelectorConfirmButton"
        enabled: root.dirty
        text: qsTr("Save Changes")
        onClicked: root.confirmed()
    }

    Rectangle {
        id: membersBox

        readonly property int toLabelWidth: label.implicitWidth + 2 * Theme.halfPadding

        readonly property int maxContentHeight: 120
        readonly property int minContentHeight: 44

        Layout.preferredHeight: Math.max(membersBox.minContentHeight,
                                         membersFlick.height + 2 * Theme.halfPadding)
        visible: false
        color: Theme.palette.baseColor2
        radius: Theme.radius

        RowLayout {
            anchors.fill: parent
            spacing: Theme.halfPadding

            StatusBaseText {
                id: label
                Layout.leftMargin: Theme.padding
                Layout.alignment: Qt.AlignVCenter
                visible: text !== ""
                color: Theme.palette.baseColor1
            }

            Flickable {
                id: membersFlick

                function positionViewAtEnd() {
                    if (contentHeight > height) {
                        contentY = contentHeight - height
                    } else {
                        contentY = 0
                    }
                }

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(membersFlow.implicitHeight,
                                                 membersBox.maxContentHeight)

                contentWidth: width
                contentHeight: membersFlow.implicitHeight
                clip: true

                ScrollBar.vertical: StatusScrollBar {}

                onContentHeightChanged: positionViewAtEnd()
                onHeightChanged: positionViewAtEnd()

                Flow {
                    id: membersFlow

                    width: membersFlick.width
                    spacing: Theme.halfPadding

                    Repeater {
                        id: membersRepeater

                        model: root.model
                        delegate: root.delegate
                    }

                    TextInput {
                        id: edit
                        objectName: "chatRecipientInput"
                        Accessible.name: Utils.formatAccessibleName("Input for adding group members", "chatRecipientInput")

                        property bool pasteOperation: false

                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText

                        width: Math.max(Math.min(implicitWidth, membersFlick.width + 2 * Theme.padding),
                                        2 * Theme.smallPadding)
                        height: 30

                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Theme.primaryTextFontSize
                        color: Theme.palette.directColor1

                        selectByMouse: true
                        selectionColor: Theme.palette.primaryColor2
                        selectedTextColor: color

                        cursorDelegate: StatusCursorDelegate {
                            cursorVisible: edit.cursorVisible
                        }

                        onTextEdited: {
                            if (suggestionsDialog.forceHide && !pasteOperation)
                                suggestionsDialog.forceHide = false
                        }

                        Keys.onPressed: (event) => {

                                            if (event.matches(StandardKey.Paste)) {
                                                event.accepted = true
                                                d.paste()
                                                return
                                            }

                                            if (suggestionsDialog.visible) {
                                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                    root.entryAccepted(suggestionsListView.itemAtIndex(suggestionsListView.currentIndex))
                                                } else if (event.key === Qt.Key_Up) {
                                                    suggestionsListView.decrementCurrentIndex()
                                                } else if (event.key === Qt.Key_Down) {
                                                    suggestionsListView.incrementCurrentIndex()
                                                }
                                            } else {
                                                if (event.key === Qt.Key_Backspace && edit.text === "") {
                                                    root.entryRemoved(membersRepeater.itemAt(membersRepeater.count - 1))
                                                } else if (event.key === Qt.Key_Return || event.key === Qt.Enter)  {
                                                    root.enterKeyPressed()
                                                } else if (event.key === Qt.Key_Escape)  {
                                                    root.rejected()
                                                } else if (event.key === Qt.Key_Up) {
                                                    root.upKeyPressed()
                                                } else if (event.key === Qt.Key_Down) {
                                                    root.downKeyPressed()
                                                }
                                            }
                                        }
                    }
                }
            }

            StatusBaseText {
                id: warningLabel
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                Layout.rightMargin: Theme.padding
                Layout.preferredWidth: Math.min(membersBox.width / 4, implicitWidth)

                visible: text !== ""
                font.pixelSize: Theme.asideTextFontSize
                wrapMode: Text.Wrap
                color: Theme.palette.dangerColor1
            }
        }

        StatusMouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onPressed: {
                edit.forceActiveFocus()
                InputMethod.show()
                mouse.accepted = false
            }
        }
    }
}
