import QtQml

import StatusQ.Core.Utils
import utils

import SortFilterProxyModel

QObject {
    id: root

    /**
      Expected model structure:

        pubKey                   [string] - unique identifier of a member, e.g "0x3234235"
        displayName              [string] - member's chosen name
        preferredDisplayName     [string] - calculated member name according to priorities (eg: nickname has higher priority)
        ensName                  [string] - member's ENS name
        isEnsVerified            [bool]   - whether the ENS name was verified on chain
        localNickname            [string] - local nickname set by the current user
        alias                    [string] - generated 3 word name
        icon                     [string] - thumbnail image of the user
        colorId                  [int]    - generated color ID for the user's profile
        onlineStatus             [int]    - the online status of the member
        isContact                [bool]   - whether the user is a mutual contact or not
        isVerified               [bool]   - wheter the user has been marked as verified or not
        isUntrustworthy          [bool]   - wheter the user has been marked as untrustworthy or not
        isBlocked                [bool]   - whether the user has been blocked or not
        contactRequest           [int]    - state of the contact request that was sent
        isCurrentUser            [bool]   - whether the contact is actually ourselves
        lastUpdated              [int64]  - clock of when last the contact was updated
        lastUpdatedLocally       [int64]  - clock of when last the contact was updated locally
        bio                      [string] - contacts's chosen bio text
        thumbnailImage           [string] - local url of the user's thumbnail image
        largeImage               [string] - local url of the user's large image
        isContactRequestReceived [bool]   - whether we received a contact request from that user
        isContactRequestSent     [bool]   - whether we send a contact request to that user
        isRemoved                [bool]   - whether we removed that contact
        trustStatus              [int]    - the trust status of the user as an enum
    **/
    property var allContacts

    readonly property var mutualContacts: SortFilterProxyModel {
        sourceModel: root.allContacts ?? null

        filters: ValueFilter {
            roleName: "isContact"
            value: true
        }
    }

    readonly property var blockedContacts: SortFilterProxyModel {
        sourceModel: root.allContacts ?? null

        filters: ValueFilter {
            roleName: "isBlocked"
            value: true
        }
    }

    readonly property var pendingReceivedRequestContacts: SortFilterProxyModel {
        sourceModel: root.allContacts ?? null

        filters: ValueFilter {
            roleName: "contactRequest"
            value: Constants.ContactRequestState.Received
        }
    }

    readonly property var pendingSentRequestContacts: SortFilterProxyModel {
        sourceModel: root.allContacts ?? null

        filters: ValueFilter {
            roleName: "contactRequest"
            value: Constants.ContactRequestState.Sent
        }
    }

    readonly property var pendingContacts: SortFilterProxyModel {
        sourceModel: root.allContacts ?? null

        filters: [
            AnyOf {
                ValueFilter {
                    roleName: "contactRequest"
                    value: Constants.ContactRequestState.Received
                }
                ValueFilter {
                    roleName: "contactRequest"
                    value: Constants.ContactRequestState.Sent
                }
            }
        ]
    }

    readonly property var dismissedReceivedRequestContacts: SortFilterProxyModel {
        sourceModel: root.allContacts ?? null

        filters: [
            ValueFilter {
                roleName: "contactRequest"
                value: Constants.ContactRequestState.Dismissed
            },
            ValueFilter {
                roleName: "isBlocked"
                value: false
            }
        ]
    }
}
