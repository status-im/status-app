import QtQml

import StatusQ
import StatusQ.Models
import StatusQ.Core.Utils

import utils

import SortFilterProxyModel

QObject {
    id: root

    /**
      Expected model structure:

        pubKey                          [string]    - unique identifier of a member, e.g "0x3234235"
        displayName                     [string]    - member's chosen name
        preferredDisplayName            [string]    - calculated member name according to priorities (eg: nickname has higher priority)
        ensName                         [string]    - member's ENS name
        isEnsVerified                   [bool]      - whether the ENS name was verified on chain
        localNickname                   [string]    - local nickname set by the current user
        alias                           [string]    - generated 3 word name
        icon                            [string]    - thumbnail image of the user
        colorId                         [string]    - generated color ID for the user's profile
        onlineStatus                    [int]       - the online status of the member
        isContact                       [bool]      - whether the user is a mutual contact or not
        isVerified                      [bool]      - wheter the user has been marked as verified or not
        isUntrustworthy                 [bool]      - wheter the user has been marked as untrustworthy or not
        isBlocked                       [bool]      - whether the user has been blocked or not
        contactRequest                  [int]       - state of the contact request that was sent
        incomingVerificationStatus      [int]       - state of the verification request that was received
        outgoingVerificationStatus      [int]       - state of the verification request that was send
        memberRole                      [int]       - role of the member in the community
        joined                          [bool]      - whether the user has joined the community
        requestToJoinId                 [string]    - the user's request to join ID
        requestToJoinLoading            [bool]      - whether the accept request action is being processed
        declineRequestToJoinLoading     [bool]      - whether the decline request action is being processed
        airdropAddress                  [string]    - the member's airdrop address (only available to TMs and owners)
        membershipRequestState          [int]       - the user's membership state (pending, joined, etc.)
    **/
    property var allMembers

    readonly property var joinedMembers: SortFilterProxyModel {
        sourceModel: root.allMembers ?? null

        filters: AnyOf {
            ValueFilter {
                roleName: "membershipRequestState"
                value: Constants.CommunityMembershipRequestState.Accepted
            }
            ValueFilter {
                roleName: "membershipRequestState"
                value: Constants.CommunityMembershipRequestState.KickedPending
            }
            ValueFilter {
                roleName: "membershipRequestState"
                value: Constants.CommunityMembershipRequestState.BannedPending
            }
            ValueFilter {
                roleName: "membershipRequestState"
                value: Constants.CommunityMembershipRequestState.AwaitingAddress
            }
        }
    }

    readonly property var bannedMembers: SortFilterProxyModel {
        sourceModel: root.allMembers ?? null

        filters: AnyOf {
            ValueFilter {
                roleName: "membershipRequestState"
                value: Constants.CommunityMembershipRequestState.Banned
            }
            ValueFilter {
                roleName: "membershipRequestState"
                value: Constants.CommunityMembershipRequestState.UnbannedPending
            }
            ValueFilter {
                roleName: "membershipRequestState"
                value: Constants.CommunityMembershipRequestState.BannedWithAllMessagesDelete
            }
        }
    }

    readonly property var pendingMembers: SortFilterProxyModel {
        sourceModel: root.allMembers ?? null

        filters: AnyOf {
            ValueFilter {
                roleName: "membershipRequestState"
                value: Constants.CommunityMembershipRequestState.Pending
            }
            ValueFilter {
                roleName: "membershipRequestState"
                value: Constants.CommunityMembershipRequestState.AcceptedPending
            }
            ValueFilter {
                roleName: "membershipRequestState"
                value: Constants.CommunityMembershipRequestState.RejectedPending
            }
        }
    }

    readonly property var declinedMembers: SortFilterProxyModel {
        sourceModel: root.allMembers ?? null

        filters: ValueFilter {
            roleName: "membershipRequestState"
            value: Constants.CommunityMembershipRequestState.Rejected
        }
    }
}
