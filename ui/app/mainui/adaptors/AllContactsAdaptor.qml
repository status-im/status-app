import QtQuick

import StatusQ
import StatusQ.Core.Utils
import utils

import QtModelsToolkit
import SortFilterProxyModel
import AppLayouts.Profile.helpers

/**
  * Adaptor concatenating model of contacts with own profile details into single
    model in order to use it as a complete source of profile info, with no
    distinction between own and contact's profiles.
  */
QObject {
    id: root

    /* Model with details (not including self) */
    property alias contactsModel: mainSource.model

    /* Self-profile details */
    required property ContactDetails selfContactDetails

    readonly property ConcatModel allContactsModel: ConcatModel {
        id: concatModel

        function hasUser(pubKey) {
            return pubKey === root.selfContactDetails.publicKey || contactsModel.hasUser(pubKey)
        }

        expectedRoles: [
            "pubKey", "displayName", "ensName", "isEnsVerified", "localNickname", "usesDefaultName",
            "alias", "icon", "colorId", "onlineStatus",
            "isContact", "isCurrentUser", "isVerified", "isUntrustworthy",
            "isBlocked", "contactRequestState", "preferredDisplayName",
            "lastUpdated", "lastUpdatedLocally", "thumbnailImage", "largeImage",
            "isContactRequestReceived", "isContactRequestSent", "removed",
            "trustStatus", "bio"
        ]

        markerRoleName: ""

        sources: [
            SourceModel {
                model: ObjectProxyModel {
                    sourceModel: ListModel {
                        ListElement {
                            _: "" // empty role to prevent warning
                        }
                    }

                    delegate: QtObject {
                        readonly property string pubKey: root.selfContactDetails.publicKey
                        readonly property string displayName: root.selfContactDetails.displayName
                        readonly property string ensName: root.selfContactDetails.ensName
                        readonly property bool isEnsVerified: !!ensName && Utils.isValidEns(ensName)
                        readonly property string localNickname: ""
                        readonly property string preferredDisplayName: root.selfContactDetails.preferredDisplayName
                        readonly property string name: preferredDisplayName
                        readonly property string alias: root.selfContactDetails.alias
                        readonly property bool usesDefaultName: root.selfContactDetails.usesDefaultName
                        readonly property string icon: root.selfContactDetails.icon
                        readonly property int colorId: root.selfContactDetails.colorId
                        readonly property int onlineStatus: root.selfContactDetails.onlineStatus
                        readonly property bool isContact: false
                        readonly property bool isCurrentUser: true
                        readonly property bool isVerified: false
                        readonly property bool isUntrustworthy: false
                        readonly property bool isBlocked: false
                        readonly property int contactRequestState: Constants.ContactRequestState.None
                        readonly property int lastUpdated: 0
                        readonly property int lastUpdatedLocally: 0
                        readonly property string thumbnailImage: root.selfContactDetails.thumbnailImage
                        readonly property string largeImage: root.selfContactDetails.largeImage
                        readonly property bool isContactRequestReceived: Constants.ContactRequestState.None
                        readonly property bool isContactRequestSent: Constants.ContactRequestState.None
                        readonly property bool removed: false
                        readonly property int trustStatus: Constants.trustStatus.unknown
                        readonly property string bio: root.selfContactDetails.bio
                    }

                    exposedRoles: concatModel.expectedRoles
                }
            },
            SourceModel {
                id: mainSource
            }
        ]
    }
}
