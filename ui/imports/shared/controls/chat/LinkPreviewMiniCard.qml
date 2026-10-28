import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import shared
import utils

import "./private"

CalloutCard {
    id: root

    enum State {
        Invalid,
        Loading,
        LoadingFailed,
        Loaded
    }

    readonly property LinkData linkData: LinkData { }
    readonly property UserData userData: UserData { }
    readonly property CommunityData communityData: CommunityData { }
    readonly property ChannelData channelData: ChannelData { }

    required property int previewState
    required property int type

    readonly property bool containsMouse: mouseArea.hovered || reloadButton.hovered || closeButton.hovered

    signal close()
    signal retry()
    signal clicked(var eventPoint)
    signal rightClicked(var eventPoint)

    implicitWidth: 260
    implicitHeight: 64
    verticalPadding: 15
    horizontalPadding: 12
    borderColor: Theme.palette.directColor7
    backgroundColor: root.containsMouse ? Theme.palette.directColor7 : Theme.palette.background

    // behavior
    states: [
        State {
            name: "invalid"
            when: root.previewState === LinkPreviewMiniCard.State.Invalid
            PropertyChanges {
                target: root
                visible: false
            }
        },
        State {
            name: "loading"
            when: root.previewState === LinkPreviewMiniCard.State.Loading
            PropertyChanges { target: root; visible: true; dashedBorder: true; }
            PropertyChanges { target: loadingAnimation; visible: true; }
            PropertyChanges { target: titleText; text: qsTr("Generating preview..."); color: Theme.palette.baseColor1 }
            PropertyChanges { target: subtitleText; visible: false; }
            PropertyChanges { target: reloadButton; visible: false; }
        },
        State {
            name: "loadingFailed"
            when: root.previewState === LinkPreviewMiniCard.State.LoadingFailed
            PropertyChanges { target: root; visible: true; dashedBorder: true; }
            PropertyChanges { target: loadingAnimation; visible: false; }
            PropertyChanges { target: titleText; text: qsTr("Failed to generate preview"); color: Theme.palette.directColor1 }
            PropertyChanges { target: subtitleText; visible: false; }
            PropertyChanges { target: reloadButton; visible: true; }
        },
        State {
            name: "loaded"
            when: root.previewState === LinkPreviewMiniCard.State.Loaded &&
                  root.type === Constants.LinkPreviewType.Standard &&
                  root.linkData.type === Constants.StandardLinkPreviewType.Link
            PropertyChanges { 
                target: root; visible: true; dashedBorder: false; borderWidth: 0;
                borderColor: backgroundColor;
            }
            PropertyChanges { target: loadingAnimation; visible: false; }
            PropertyChanges { target: titleText; text: root.linkData.title; color: Theme.palette.directColor1 }
            PropertyChanges { target: subtitleText; visible: true; text: root.linkData.domain; }
            PropertyChanges { target: reloadButton; visible: false; }
            PropertyChanges { 
                target: favIcon
                visible: true
                name: root.linkData.title
                asset.isLetterIdenticon: !root.linkData.image
                asset.color: Theme.palette.baseColor2
            }
        },
        State {
            name: "loadedImage"
            when: root.previewState === LinkPreviewMiniCard.State.Loaded &&
                  root.type === Constants.LinkPreviewType.Standard &&
                  root.linkData.type === Constants.StandardLinkPreviewType.Image
            extend: "loaded"
            PropertyChanges { target: thumbnailImage; visible: root.linkData.thumbnail != ""; image.source: root.linkData.thumbnail; }
            PropertyChanges { target: favIcon; visible: true; name: root.linkData.domain; asset.isLetterIdenticon: true; asset.color: Theme.palette.baseColor2; }
            PropertyChanges { target: subtitleText; visible: true; text: root.linkData.domain; }
        },
        State {
            name: "loadedCommunity"
            when: root.previewState === LinkPreviewMiniCard.State.Loaded && root.type === Constants.LinkPreviewType.StatusCommunity
            extend: "loaded"
            PropertyChanges { target: titleText; text: root.communityData.name; }
            PropertyChanges { target: subtitleText; visible: true; text: Constants.externalStatusLink; }
            PropertyChanges {
                target: favIcon
                visible: true
                name: root.communityData.name
                asset.isLetterIdenticon: root.communityData.image.length === 0
                asset.color: root.communityData.color
                asset.name: root.communityData.image
            }
        },
        State {
            name: "loadedChannel"
            when: root.previewState === LinkPreviewMiniCard.State.Loaded && root.type === Constants.LinkPreviewType.StatusCommunityChannel
            extend: "loadedCommunity"
            PropertyChanges { target: titleText; text: root.channelData.communityData.name; Layout.fillWidth: false; Layout.maximumWidth: Math.min(92, implicitWidth); }
            PropertyChanges { target: secondTitleText; text: "#" + root.channelData.name; visible: true; }
            PropertyChanges {
                target: favIcon
                visible: true
                name: root.channelData.communityData.name
                asset.isLetterIdenticon: root.channelData.communityData.image.length === 0
                asset.color: root.channelData.communityData.color
                asset.name: root.channelData.communityData.image
            }
        },
        State {
            name: "loadedUser"
            when: root.previewState === LinkPreviewMiniCard.State.Loaded && root.type === Constants.LinkPreviewType.StatusContact
            extend: "loaded"
            PropertyChanges { target: titleText; text: root.userData.name; Layout.fillWidth: false; Layout.maximumWidth: Math.min(92, implicitWidth); }
            PropertyChanges { target: subtitleText; visible: true; text: Constants.externalStatusLink; }
            PropertyChanges { 
                target: favIcon
                visible: true
                name: root.userData.name
                asset.name: root.userData.image
                asset.isLetterIdenticon: root.userData.image.length === 0
                asset.charactersLen: 2
                asset.color: Theme.palette.miscColor9
            }
        }
    ]

    contentItem: Item {
        implicitHeight: layout.implicitHeight
        implicitWidth: layout.implicitWidth

        RowLayout {
            id: layout
            anchors.fill: parent
            spacing: 0
            LoadingAnimation {
                id: loadingAnimation
                Layout.alignment: Qt.AlignVCenter
                Layout.margins: 4
                visible: false
            }
            StatusSmartIdenticon {
                id: favIcon
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                Layout.topMargin: 1
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                visible: false
                asset.letterSize: asset.charactersLen == 1 ? 10 : 7
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 8
                spacing: 0
                RowLayout {
                    id: titleRow
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0
                    StatusBaseText {
                        id: titleText
                        objectName: "linkPreviewTitleText"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        font.pixelSize: Theme.additionalTextSize
                        font.weight: Font.Medium
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        maximumLineCount: 1
                    }
                    StatusIcon {
                        id: secondTitleIcon
                        width: 16
                        height: 16
                        icon: "tiny/chevron-right"
                        color: Theme.palette.baseColor1
                        visible: secondTitleText.visible
                    }
                    StatusBaseText {
                        id: secondTitleText
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        font.pixelSize: Theme.additionalTextSize
                        font.weight: Font.Medium
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        maximumLineCount: 1
                        visible: false
                    }
                }
                StatusBaseText {
                    id: subtitleText
                    objectName: "linkPreviewSubtitleText"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    font.pixelSize: Theme.tertiaryTextFontSize
                    color: Theme.palette.baseColor1
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                }
            }
            StatusRoundedImage {
                id: thumbnailImage
                Layout.alignment: Qt.AlignRight
                Layout.rightMargin: 4
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 4
                visible: false
            }
            StatusFlatButton {
                id: reloadButton
                icon.name: "refresh"
                size: StatusBaseButton.Size.Small
                hoverColor: Theme.palette.directColor8
                textColor: Theme.palette.directColor1
                onClicked: root.retry()
            }
            StatusFlatButton {
                id: closeButton
                icon.name: "close"
                size: StatusBaseButton.Size.Small
                hoverColor: Theme.palette.directColor8
                textColor: Theme.palette.directColor1
                onClicked: root.close()
            }
        }
    }

    HoverHandler {
        id: mouseArea
        target: background
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        id: tapHandler
        target: background
        onTapped: root.clicked(eventPoint)
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: root.rightClicked(eventPoint)
    }
}
