import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme

Control {
    id: root

    property string nameText
    property string messageText
    property string extraContentText

    property alias avatarImage: avatarImg.source

    signal closeClicked

    onNameTextChanged: replyText.updateText()
    onMessageTextChanged: replyText.updateText()
    onExtraContentTextChanged: replyText.updateText()

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

            color: Theme.palette.baseColor1

            Image {
                id: avatarImg

                anchors.fill: parent

                smooth: true
                mipmap: true
                layer.enabled: true

                fillMode: Image.PreserveAspectCrop

                layer.effect: MultiEffect {
                    source: avatarImg

                    maskEnabled: true
                    maskSource: circleMask

                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

                // Mask geometry
                Rectangle {
                    id: circleMask

                    anchors.fill: parent
                    layer.enabled: true
                    radius: width / 2
                    visible: false
                }
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
                        return `<b>${name}</b> ${message} <font color=\"${Theme.palette.baseColor1}\">${extraContent}</font>`
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
            size: StatusBaseButton.Size.Small
            radius: width / 2

            Binding on hoverColor {
                when: closeButton.pressed
                value: Theme.palette.primaryColor1
            }

            onClicked: root.closeClicked()
        }
    }
}
