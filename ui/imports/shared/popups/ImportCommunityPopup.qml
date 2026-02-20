import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import utils
import shared.controls
import shared.stores

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog
import StatusQ.Controls

import AppLayouts.Communities.stores as CommunitiesStores

StatusDialog {
    id: root

    property CommunitiesStores.CommunitiesStore store
    property UtilsStore utilsStore

    property alias text: keyInput.text
    property alias communityId: d.publicKey

    signal joinCommunityRequested(string communityId, var communityDetails)

    width: 640
    title: qsTr("Join Community")

    QtObject {
        id: d
        property string importErrorMessage

        readonly property bool communityFound: !!d.communityDetails && !!d.communityDetails.name
        property var communityDetails: null

        property var requestedCommunityDetails: null

        readonly property string inputErrorMessage: isInputValid ? "" : qsTr("Invalid key")
        readonly property string errorMessage: importErrorMessage || inputErrorMessage
        readonly property string inputKey: keyInput.text.trim()
        readonly property string publicKey: {
            if (Utils.isStatusDeepLink(inputKey)) {
                const linkData = Utils.getCommunityDataFromSharedLink(inputKey)
                if (!linkData) {
                    return ""
                }
                return linkData.communityId
            }
            let updatedKey = inputKey
            if (inputKey.indexOf("#") !== -1) {
                // It's likely <encoded_data>#<community_chat_key> and we only want the community key
                updatedKey = inputKey.split("#")[1]
            }
            if (!root.utilsStore.isCommunityPublicKey(updatedKey)) {
                return ""
            }
            if (!root.utilsStore.isCompressedPubKey(updatedKey)) {
                return updatedKey
            }
            return root.utilsStore.changeCommunityKeyCompression(updatedKey)
        }
        readonly property bool isInputValid: publicKey !== ""

        property bool communityInfoRequested: false

        function updateCommunityDetails(requestIfNotFound) {
            if (!isInputValid) {
                d.communityInfoRequested = false
                d.communityDetails = null
                return
            }

            const details = root.store.getCommunityDetails(publicKey)

            if (!!details) {
                d.communityInfoRequested = false
                d.communityDetails = details
                return
            }

            if (requestIfNotFound) {
                root.store.requestCommunityInfo(publicKey, false)
                d.communityInfoRequested = true
                d.communityDetails = null
            }
        }

        onPublicKeyChanged: {
            // call later to make sure all proeprties used by `updateCommunityDetails` are udpated
            Qt.callLater(() => { d.updateCommunityDetails(true) })
        }
    }

    Connections {
        target: root.store

        function onCommunityInfoRequestCompleted(communityId, errorMsg) {
            if (!d.communityInfoRequested)
                return

            d.communityInfoRequested = false

            if (errorMsg !== "") {
                d.importErrorMessage = qsTr("Couldn't find community")
                return
            }

            d.updateCommunityDetails(false)
            d.importErrorMessage = ""
        }
    }

    footer: StatusDialogFooter {
        bottomPadding: Theme.padding + root.parent.SafeArea.margins.bottom
        rightButtons: ObjectModel {
            StatusButton {
                objectName: "joinStatusDialogFooterButton"
                enabled: d.isInputValid && d.communityFound
                loading: d.isInputValid && !d.communityFound && d.communityInfoRequested
                text: qsTr("Join")
                onClicked: {
                    root.joinCommunityRequested(d.publicKey, d.communityDetails)
                }
            }
        }
    }

    StatusScrollView {
        id: scrollContent
        anchors.fill: parent
        contentWidth: availableWidth
        padding: 0

        ColumnLayout {
            width: scrollContent.availableWidth
            spacing: Theme.halfPadding

            StatusBaseText {
                id: infoText1
                Layout.fillWidth: true
                text: qsTr("Enter the public key of, or a link to the community you wish to access")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.additionalTextSize
                color: Theme.palette.baseColor1
            }

            StatusBaseText {
                id: inputLabel
                text: qsTr("Community key")
                color: Theme.palette.directColor1
            }
            StatusScrollView {
                padding: 0 // use our own (StatusTextArea) padding
                Layout.fillWidth: true
                Layout.preferredHeight: 108
                StatusTextArea {
                    id: keyInput
                    placeholderText: qsTr("Link or (compressed) public key...")
                    wrapMode: TextEdit.Wrap
                    onTextChanged: d.importErrorMessage = ""
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.minimumHeight: 46
                Layout.maximumHeight: 46
                StatusChatInfoButton {
                    visible: d.communityFound
                    title: visible ? d.communityDetails.name : ""
                    subTitle: visible ? qsTr("%n member(s)", "", d.communityDetails.nbMembers) : ""
                    asset.name: visible ? d.communityDetails.image : ""
                    asset.isImage: (asset.name !== "")
                    asset.color: visible ? d.communityDetails.color : ""
                }
                Item { Layout.fillWidth: true }
                StatusBaseText {
                    id: detectionLabel
                    Layout.alignment: Qt.AlignRight
                    font.pixelSize: Theme.additionalTextSize
                    visible: !!d.inputKey
                    text: {
                        if (d.errorMessage !== "")
                            return d.errorMessage
                        if (d.isInputValid)
                            return qsTr("Public key detected")
                        return ""
                    }
                    color: d.errorMessage === "" ? Theme.palette.successColor1 : Theme.palette.dangerColor1
                }
            }
        }
    }
}
