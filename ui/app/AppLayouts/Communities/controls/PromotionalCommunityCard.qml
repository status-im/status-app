import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import shared.controls
import shared.panels

Item {
    id: root

    /*!
        \qmlsignal StatusCommunityCard::learnMore
        This signal is emitted when the card learn more button is clicked.
    */
    signal learnMore

    /*!
        \qmlsignal StatusCommunityCard::initiateVote
        This signal is emitted when the card initiate vote button is clicked
    */
    signal initiateVote

    QtObject {
        id: d
        readonly property int cardWidth: 335
        readonly property int cardHeight: 230
        readonly property int defaultMargin: 12
        readonly property int defaultSpacing: 8
    }

    implicitWidth: d.cardWidth
    implicitHeight: d.cardHeight

    ShapeRectangle {
        anchors.fill: parent

        ColumnLayout {
            width: parent.width
            anchors.centerIn: parent
            spacing: d.defaultSpacing

            StatusIcon {
                Layout.topMargin: 28
                Layout.alignment: Qt.AlignHCenter
                color: Theme.palette.directColor1
                icon: "communities"
            }

            StatusBaseText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width - 4 * d.defaultMargin

                text: qsTr("Want to see your community here?")
                font.weight: Font.Bold
            }

            StatusBaseText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width - 4 * d.defaultMargin

                text: qsTr("Help more people discover your community - start or join the vote to get it on the board.")
                font.pixelSize: Theme.additionalTextSize
                lineHeight: 1.2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Separator {
                Layout.fillWidth: true
                Layout.topMargin: 22
                Layout.leftMargin: d.defaultMargin
                Layout.rightMargin: d.defaultMargin
                Layout.bottomMargin: 4
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: d.defaultMargin
                Layout.rightMargin: d.defaultMargin
                spacing: d.defaultSpacing

                StatusButton {
                    text: qsTr("Learn more")
                    icon.name: "external-link"
                    size: StatusBaseButton.Size.Small

                    onClicked: root.learnMore()
                }

                StatusButton {
                    text: qsTr("Initiate the vote")
                    icon.name: "external-link"
                    size: StatusBaseButton.Size.Small

                    onClicked: root.initiateVote()
                }
            }

        } // End of content card
    }
}
