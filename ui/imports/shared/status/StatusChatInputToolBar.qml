import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import utils

Control {
    id: root

    readonly property alias styleButton: styleButton
    readonly property alias boldButton: boldButton
    readonly property alias italicButton: italicButton
    readonly property alias strikeThroughButton: strikeThroughButton
    readonly property alias quoteButton: quoteButton
    readonly property alias codeButton: codeButton

    readonly property alias cameraButton: cameraButton
    readonly property alias imageButton: imageButton
    readonly property alias tokenButton: tokenButton
    readonly property alias mentionButton: mentionButton
    readonly property alias emojiButton: emojiButton
    readonly property alias stickersButton: stickersButton
    readonly property alias gifButton: gifButton

    readonly property alias sendButton: sendButton

    property bool sendButtonVisible: true
    property bool showFormatting: false
    property bool styleButtonVisible: true

    component ChatIcon: AbstractButton {
        id: chatIconRoot

        focusPolicy: Qt.NoFocus

        checkable: true
        padding: Math.round(Theme.halfPadding / 2)

        background: Rectangle {
            radius: Theme.radius

            color: checked ? Theme.palette.baseColor5
                           : StatusColors.transparent
            border.color: checked || chatIconRoot.pressed
                          ? Theme.palette.primaryColor1
                          : Theme.palette.directColor7
        }

        contentItem: Item {
            implicitWidth: icon.width
            implicitHeight: icon.height

            StatusIcon {
                id: icon

                icon: chatIconRoot.icon.name
                width: 24 + Math.max(0, Theme.fontSizeOffset * 2)
                height: width

                color: chatIconRoot.checked || hoverHandler.hovered
                       ? Theme.palette.primaryColor1
                       : Theme.palette.directColor4
            }
        }

        HoverHandler {
            id: hoverHandler
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
            enabled: root.hoverEnabled
            cursorShape: Qt.PointingHandCursor
        }
    }

    QtObject {
        id: d

        readonly property int padding: Math.round(root.Theme.padding * 3 / 4)
    }

    Rectangle {
        id: gradientMask

        width: flickable.width + gradient.fadePixelSize * 2
        height: flickable.height

        visible: false
        layer.enabled: true
        gradient: Gradient {
            id: gradient

            orientation: Gradient.Horizontal

            readonly property int fadePixelSize: 7
            readonly property real relativeFadeSize: fadePixelSize / gradientMask.width

            GradientStop {position: 0; color: Qt.rgba(1, 1, 1, 0)}
            GradientStop {position: gradient.relativeFadeSize; color: Qt.rgba(0, 0, 0)}
            GradientStop {position: 1 - gradient.relativeFadeSize; color: Qt.rgba(0, 0, 0)}
            GradientStop {position: 1; color: Qt.rgba(1, 1, 1, 0)}
        }
    }

    contentItem: RowLayout {
        id: mainRow

        spacing: d.padding

        // Wrapper for the flickable to apply the fade effect on the edges
        Item {
            id: flickableWrapper

            Layout.preferredWidth: flickable.contentWidth + gradient.fadePixelSize * 2
            Layout.preferredHeight: Math.max(content.childrenRect.height, sendButton.implicitHeight)
            Layout.leftMargin: -gradient.fadePixelSize
            Layout.rightMargin: -gradient.fadePixelSize
            Layout.fillWidth: true

            layer.enabled: true
            layer.effect: MultiEffect {
                source: flickableWrapper
                maskEnabled: true
                maskSource: gradientMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Flickable {
                id: flickable

                anchors.fill: parent
                anchors.leftMargin: gradient.fadePixelSize
                anchors.rightMargin: gradient.fadePixelSize

                flickableDirection: Flickable.AutoFlickIfNeeded

                contentWidth: content.implicitWidth
                contentHeight: height

                Item {
                    id: content

                    implicitWidth: actionsRowLayout.width + actionsRowLayout.x
                    height: parent.height

                    ChatIcon {
                        id: styleButton

                        visible: root.styleButtonVisible
                        width: root.styleButtonVisible ? implicitWidth : 0
                        anchors.verticalCenter: parent.verticalCenter
                        icon.name: "chat/style"
                    }

                    state: (root.showFormatting || styleButton.checked) ? "formatting" : "noformatting"

                    states: [
                        State {
                            when: styleButton.checked
                            name: "formatting"

                            AnchorChanges {
                                target: formattingRowLayout
                                anchors.left: styleButton.right
                            }
                            AnchorChanges {
                                target: actionsRowLayout
                                anchors.left: formattingRowLayout.right
                            }
                            PropertyChanges {
                                target: formattingRowLayout
                                opacity: 1
                            }
                        },
                        State {
                            when: !styleButton.checked
                            name: "noformatting"

                            AnchorChanges {
                                target: formattingRowLayout
                                anchors.left: styleButton.right
                            }
                            AnchorChanges {
                                target: actionsRowLayout
                                anchors.left: styleButton.right
                            }
                            PropertyChanges {
                                target: formattingRowLayout
                                opacity: 0
                            }
                        }
                    ]

                    transitions: Transition {
                        // smoothly reanchor and move into new position
                        AnchorAnimation {
                            duration: ThemeUtils.AnimationDuration.Fast
                        }
                    }

                    RowLayout {
                        id: formattingRowLayout

                        spacing: d.padding
                        anchors.leftMargin: root.styleButtonVisible ? d.padding : 0
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on opacity {
                            NumberAnimation {
                                duration: ThemeUtils.AnimationDuration.Fast
                                easing.type: Easing.InOutQuad
                            }
                        }

                        ChatIcon {
                            id: boldButton

                            icon.name: "chat/bold"
                        }

                        ChatIcon {
                            id: italicButton

                            icon.name: "chat/italic"
                        }

                        ChatIcon {
                            id: strikeThroughButton

                            icon.name: "chat/strikethrough"
                        }

                        ChatIcon {
                            id: quoteButton

                            icon.name: "chat/quote"
                        }

                        ChatIcon {
                            id: codeButton

                            icon.name: "chat/code"
                        }
                    }

                    RowLayout {
                        id: actionsRowLayout

                        spacing: d.padding
                        anchors.leftMargin: root.styleButtonVisible || root.showFormatting
                                            ? d.padding : 0
                        anchors.verticalCenter: parent.verticalCenter

                        ChatIcon {
                            id: cameraButton

                            icon.name: "chat/camera"
                        }

                        ChatIcon {
                            id: imageButton

                            icon.name: "chat/image"
                        }

                        ChatIcon {
                            id: tokenButton

                            icon.name: "chat/token"
                        }

                        ChatIcon {
                            id: mentionButton

                            icon.name: "chat/mention"
                        }

                        ChatIcon {
                            id: emojiButton

                            icon.name: "chat/smile"
                        }

                        ChatIcon {
                            id: stickersButton

                            icon.name: "chat/sticker"
                        }

                        ChatIcon {
                            id: gifButton

                            icon.name: "chat/gif"
                        }
                    }
                }
            }
        }

        Item {
            id: buttonWrapper

            Layout.preferredWidth: sendButton.implicitWidth
            Layout.preferredHeight: sendButton.implicitHeight

            StatusChatInputSendButton {
                id: sendButton

                anchors.right: parent.right
            }

            states: [
                State {
                    when: !root.sendButtonVisible
                    PropertyChanges {
                        target: buttonWrapper
                        opacity: 0
                        Layout.preferredWidth: 0
                    }
                    PropertyChanges {
                        target: sendButton
                        interactive: false
                    }
                },
                State {
                    when: root.sendButtonVisible
                    PropertyChanges {
                        target: buttonWrapper
                        opacity: 1
                    }
                }
            ]

            transitions: Transition {
                SequentialAnimation {
                    PropertyAnimation {
                        properties: "opacity,Layout.preferredWidth"
                        duration: ThemeUtils.AnimationDuration.Fast
                    }
                }
            }
        }
    }
}
