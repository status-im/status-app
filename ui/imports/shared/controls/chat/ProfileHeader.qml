import QtQuick
import QtQuick.Layouts

import utils
import shared.panels
import shared.controls

import StatusQ
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Core
import StatusQ.Core.Theme

Item {
    id: root

    enum ImageSize {
        Compact,
        Middle,
        Big
    }

    property string displayName
    property string compressedPubKey
    property string icon
    property url previewIcon: icon
    property int trustStatus
    property int onlineStatus: Constants.onlineStatus.unknown
    property bool usesDefaultName: false
    property bool isContact: false
    property bool isBlocked
    property bool isCurrentUser
    property rect cropRect
    property int colorId

    property int imageSize: ProfileHeader.ImageSize.Compact
    property bool displayNameVisible: true
    property bool displayNamePlusIconsVisible: false
    property bool pubkeyVisible: true
    property alias emojiHash: emojiHash.emojiHash
    property bool emojiHashVisible: true
    property bool editImageButtonVisible: false
    property bool editButtonVisible: displayNamePlusIconsVisible
    property bool loading: false
    readonly property bool compact: root.imageSize === ProfileHeader.ImageSize.Compact
    property bool isBridgedAccount: false

    signal clicked()
    signal editClicked()

    Binding on previewIcon {
        value: icon
    }

    implicitWidth: contentContainer.implicitWidth
    implicitHeight: contentContainer.implicitHeight

    QtObject {
        id: d
        function getSize(compact, normal, big) {
            switch(root.imageSize) {
                case ProfileHeader.ImageSize.Compact: return compact;
                case ProfileHeader.ImageSize.Middle: return normal;
                case ProfileHeader.ImageSize.Big: return big;
            }
        }
    }

    Item {
        id: tmpCroppedImageHelper

        visible: false

        Image {
            id: tmpImage
            mipmap: true
            cache: false
        }

        property var keepGrabResultAlive;

        function setCroppedTmpIcon(source, x, y, width, height) {
            tmpCroppedImageHelper.width = width
            tmpCroppedImageHelper.height = height

            tmpImage.x = -x
            tmpImage.y = -y
            tmpImage.source = source

            tmpCroppedImageHelper.grabToImage(result => {
                keepGrabResultAlive = result
                root.previewIcon = result.url
                tmpImage.source = ""
            })
        }
    }

    ColumnLayout {
        id: contentContainer

        spacing: root.compact ? 4 : 12

        anchors {
            left: parent.left
            right: parent.right
            leftMargin: Theme.smallPadding
            rightMargin: Theme.smallPadding
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: userImage.width
            implicitHeight: userImage.height

            StatusUserImage {
                id: userImage

                objectName: "ProfileHeader_userImage"
                name: root.displayName
                usesDefaultName: root.usesDefaultName
                userColor: Utils.colorForColorId(Theme.palette, root.colorId)
                image: root.previewIcon
                interactive: false
                imageWidth: d.getSize(36, 64, 170)
                imageHeight: imageWidth
                loading: root.loading
                onlineStatus: root.onlineStatus
                isBridgedAccount: root.isBridgedAccount
            }

            StatusRoundButton {
                id: editButton
                visible: root.editImageButtonVisible
                anchors.top: userImage.top
                anchors.right: userImage.right
                anchors.rightMargin: Math.round(userImage.width / 10)

                width: d.getSize(10, 24, 40)
                height: width

                type: StatusRoundButton.Type.Secondary
                icon.name: "edit_pencil"
                icon.width: d.getSize(8, 12, 24)
                icon.height: d.getSize(8, 12, 24)

                onClicked: {
                    if (!!root.icon)
                        Global.openMenu(editImageMenuComponent, this)
                    else
                        Global.openChangeProfilePicPopup(setTempIcon);
                }

                function setTempIcon(image, aX, aY, bX, bY) {
                    root.icon = image
                    root.cropRect = Qt.rect(aX, aY, bX - aX, bY - aY)

                    tmpCroppedImageHelper.setCroppedTmpIcon(
                                image, aX, aY, bX - aX, bY - aY)
                }
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: displayNameLabel.implicitHeight
            visible: root.displayNameVisible

            StyledText {
                id: displayNameLabel
                width: parent.width
                height: parent.height
                text: root.displayName
                visible: !root.loading
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 3
                wrapMode: Text.Wrap
                font {
                    bold: true
                    pixelSize: 17
                }
            }

            Loader {
                anchors.centerIn: parent
                height: parent.height
                width: 100
                visible: root.loading
                active: visible

                sourceComponent: LoadingComponent {
                    radius: 4
                }
            }
        }

        RowLayout {
            spacing: compact ? 4 : Theme.halfPadding
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            visible: root.displayNamePlusIconsVisible

            StyledText {
                objectName: "ProfileHeader_displayName"
                Layout.maximumWidth: root.width - verificationIcons.width - contentContainer.anchors.leftMargin - contentContainer.anchors.rightMargin -
                                     (editButtonLoader.active ? editButtonLoader.item.width : 0)
                text: root.displayName
                elide: Text.ElideRight
                font {
                    weight: Font.Medium
                    pixelSize: Theme.primaryTextFontSize
                }
            }

            StatusContactVerificationIcons {
                id: verificationIcons
                visible: !root.isCurrentUser && !root.isBridgedAccount
                isContact: root.isContact
                trustIndicator: root.trustStatus
                isBlocked: root.isBlocked
            }

            Loader {
                id: editButtonLoader
                sourceComponent: SVGImage {
                    objectName: "ProfileHeader_displayNameEditIcon"
                    height: compact ? 10 : 16
                    width: compact ? 10 : 16
                    source: Assets.svg("edit-message")
                    StatusMouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton
                        onClicked: {
                            root.editClicked()
                        }
                    }
                }
                active: root.editButtonVisible
                visible: active
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            visible: root.pubkeyVisible
            text: root.isBridgedAccount ? qsTr("Bridged from Discord") : Utils.getElidedPk(compressedPubKey)
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.additionalTextSize
            color: Theme.palette.secondaryText
        }

        EmojiHash {
            id: emojiHash
            Layout.alignment: Qt.AlignHCenter
            visible: root.emojiHashVisible && !root.isBridgedAccount
            compact: root.compact
        }
    }

    Component {
        id: editImageMenuComponent

        StatusMenu {
            onClosed: destroy()
            StatusAction {
                text: !!root.icon ? qsTr("Select different image") : qsTr("Select image")
                assetSettings.name: "image"
                onTriggered: Global.openChangeProfilePicPopup(editButton.setTempIcon)
            }

            StatusAction {
                text: qsTr("Use a collectible")
                assetSettings.name: "nft-profile"
                onTriggered: Global.openChangeProfilePicPopup(editButton.setTempIcon)
                enabled: false // TODO enable this with the profile showcase (#13418)
            }

            StatusMenuSeparator {}

            StatusAction {
                text: qsTr("Remove image")
                type: StatusAction.Danger
                assetSettings.name: "delete"
                onTriggered: root.icon = ""
            }
        }
    }
}
