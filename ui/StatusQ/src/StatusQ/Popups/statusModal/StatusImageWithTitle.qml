pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

Row {
    id: statusImageWithTitle

    property alias title: headerTitle.text
    property alias subTitle: headerSubTitle.text
    property int titleElide: Text.ElideRight
    property int subTitleElide: Text.ElideRight
    property bool editable: false
    property bool headerImageEditable: false

    signal editButtonClicked
    signal headerImageClicked

    property StatusAssetSettings asset: StatusAssetSettings {
        width: 40
        height: 40
        isLetterIdenticon: false
        imgIsIdenticon: false
        bgBorderWidth: 1
    }

    spacing: 8

    Loader {
        id: iconOrImage
        anchors.verticalCenter: parent.verticalCenter
        width: active ? 40 : 0
        sourceComponent: {
            if (statusImageWithTitle.asset.isLetterIdenticon) {
                return statusLetterIdenticon
            }
            return statusRoundedImageCmp
        }
        active: statusImageWithTitle.asset.isLetterIdenticon ||
                !!statusImageWithTitle.asset.name
    }

    Component {
        id: statusLetterIdenticon
        StatusLetterIdenticon {
            width: statusImageWithTitle.asset.width
            height: statusImageWithTitle.asset.height
            letterIdenticonColor: statusImageWithTitle.asset.bgColor
            name: statusImageWithTitle.title
        }
    }

    Component {
        id: statusRoundedImageCmp
        Item {
            width: statusImageWithTitle.asset.width
            height: statusImageWithTitle.asset.height
            StatusRoundedImage {
                id: statusRoundedImage
                objectName: "headerImage"
                image.source: statusImageWithTitle.asset.name
                width: statusImageWithTitle.asset.width
                height: statusImageWithTitle.asset.height
                radius: statusImageWithTitle.asset.bgRadius || width/2
                color: Theme.palette.statusRoundedImage.backgroundColor
                border.width: statusImageWithTitle.asset.bgBorderWidth
                border.color: Theme.palette.directColor7
                showLoadingIndicator: true
            }

            Rectangle {
                id: editAvatarIcon

                objectName: "editAvatarImage"
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -3
                anchors.rightMargin: -2
                width: 18
                height: 18
                radius: width / 2

                visible: statusImageWithTitle.headerImageEditable

                color: Theme.palette.primaryColor1;
                border.color: Theme.palette.indirectColor1
                border.width: Theme.palette.name === "light" ? 1 : 0

                StatusIcon {
                    anchors.centerIn: parent
                    width: 11
                    color: Theme.palette.indirectColor1
                    icon: "tiny/edit"
                }
            }

            StatusMouseArea {
                anchors.fill: parent

                cursorShape: enabled ? Qt.PointingHandCursor
                                     : Qt.ArrowCursor
                enabled: statusImageWithTitle.headerImageEditable

                onClicked: {
                    statusImageWithTitle.headerImageClicked()
                }
            }

            Loader {
                sourceComponent: statusLetterIdenticon
                active: statusRoundedImage.image.status === Image.Error
            }
        }
    }

    Column {
        id: textLayout
        width: !iconOrImage.active ? parent.width :
                                     parent.width - iconOrImage.width - parent.spacing
        anchors.verticalCenter: parent.verticalCenter

        Row {
            id: headerTitleRow
            width: parent.width
            spacing: 4
            StatusBaseText {
                id: headerTitle
                objectName: "headerTitle"
                font.family: Fonts.baseFont.family
                font.pixelSize: Theme.secondaryAdditionalTextSize
                font.bold: true
                elide: statusImageWithTitle.titleElide
                color: Theme.palette.directColor1
                width: implicitWidth > parent.width - editButton.width ? parent.width - editButton.width: implicitWidth
            }
            StatusFlatRoundButton {
                id: editButton
                objectName: "editAvatarbButton"
                visible: statusImageWithTitle.editable
                anchors.verticalCenter: headerTitle.verticalCenter
                height: 24
                width: visible ? 24 : 0
                type: StatusFlatRoundButton.Type.Secondary
                icon.name: "pencil"
                icon.color: Theme.palette.directColor1
                icon.width: 12.5
                icon.height: 12.5

                onClicked: statusImageWithTitle.editButtonClicked()
            }
        }

        StatusBaseText {
            id: headerSubTitle
            objectName: "headerSubTitle"
            font.family: Fonts.baseFont.family
            font.pixelSize: Theme.primaryTextFontSize
            color:Theme.palette.baseColor1
            width: parent.width
            elide: statusImageWithTitle.subTitleElide
            visible: !!statusImageWithTitle.subTitle
        }
    }
}
