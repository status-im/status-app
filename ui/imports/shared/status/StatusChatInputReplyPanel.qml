import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils

Control {
    id: root

    objectName: "statusChatInputReplyArea"

    property string nameText
    property string messageText
    property string extraContentText

    property url avatarImage
    property color avatarColor: Theme.palette.miscColor5

    signal closeClicked

    onNameTextChanged: replyText.updateText()
    onMessageTextChanged: replyText.updateText()
    onExtraContentTextChanged: replyText.updateText()

    QtObject {
        id: d

        readonly property bool hasImage: avatarImg.status === Image.Ready

        readonly property string avatarLetterText: {
            const words = root.nameText.trim().split(/\s+/)
            if (words.length >= 2)
                return (words[0][0] + words[1][0]).toUpperCase()
            return root.nameText.trim().charAt(0).toUpperCase()
        }

        readonly property color avatarLetterColor: {
            const lum = ColorUtils.luminance(root.avatarColor)
            return lum > 0.5 ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(1, 1, 1, 0.7)
        }
    }

    contentItem: RowLayout {
        Item {
            clip: true

            Layout.preferredWidth: 10
            Layout.preferredHeight: 10
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: metrics.height / 2

            Rectangle {
                width: parent.width * 2
                height: parent.height * 2

                radius: width / 2

                border.color:  Theme.palette.baseColor1
                border.width: 2
                color: StatusColors.transparent
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: (metrics.height - Layout.preferredHeight) / 2

            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            radius: width / 2

            color: d.hasImage ? Theme.palette.baseColor1 : root.avatarColor

            // circular in the pass drawing the image's own texture
            StatusRoundedImage {
                id: avatarImg

                anchors.fill: parent

                source: root.avatarImage
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                unsetBorderWidth: 0
            }

            StatusBaseText {
                anchors.fill: parent

                horizontalAlignment: Qt.AlignHCenter
                verticalAlignment: Qt.AlignVCenter

                visible: !d.hasImage

                text: d.avatarLetterText
                color: d.avatarLetterColor
                font.pixelSize: parent.height / 2
                font.weight: Font.Medium
            }
        }


        Item {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop

            implicitHeight: replyText.implicitHeight

            StatusBaseText {
                id: replyText

                anchors.left: parent.left
                anchors.right: parent.right

                lineHeight: 1.1
                font.pixelSize: Theme.tertiaryTextFontSize

                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight

                FontMetrics {
                    id: metrics

                    font: replyText.font
                }

                function updateText() {
                    if (width === 0) {
                        text = ""
                        return
                    }

                    function wrap(name, message, extraContent) {
                        return `<b>${name}</b> ${StringUtils.escapeHtml(message)} <font color=\"${Theme.palette.baseColor1}\">${extraContent}</font>`
                    }

                    const nameText = root.nameText
                    const extraContentText = root.extraContentText

                    const averageCharWidth = metrics.averageCharacterWidth / 1.5
                    const middleTextEstimatedWidth = width * maximumLineCount / averageCharWidth
                                                   - nameText.length - extraContentText.length

                    const initialText = root.messageText.substring(0, middleTextEstimatedWidth)

                    text = wrap(nameText, initialText, extraContentText)

                    for (let i = 0, middle = text; truncated && middle.length > 0; i++) {
                        middle = initialText.substring(0, initialText.length - i).trim()
                        text = wrap(nameText, middle + "…", extraContentText)
                    }
                }

                onWidthChanged: {
                    updateText()
                }
            }
        }

        StatusFlatButton {
            id: closeButton

            Layout.topMargin: (metrics.height - height) / 2
            Layout.rightMargin: Layout.topMargin

            Layout.alignment: Qt.AlignTop
            icon.name: "close"

            icon.color: pressed ? Theme.palette.background
                                : Theme.palette.primaryColor1
            radius: width / 2

            Binding on hoverColor {
                when: closeButton.pressed
                value: Theme.palette.primaryColor1
            }

            onClicked: root.closeClicked()
        }
    }
}
