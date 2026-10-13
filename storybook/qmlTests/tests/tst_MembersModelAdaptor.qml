import QtQuick
import QtTest

import AppLayouts.Communities.views
import StatusQ.Core.Utils as SQUtils

import utils

// MembersModelAdaptor splits the admin Members tab data: joined members come
// from the roster (plus members re-joining after an ownership change), banned,
// pending and declined ones from the admin model.
Item {
    id: root

    ListModel {
        id: roster

        function add(pubKey, state) {
            append({ pubKey, membershipRequestState: state, preferredDisplayName: pubKey })
        }
    }

    ListModel {
        id: adminMembers

        function add(pubKey, state) {
            append({ pubKey, membershipRequestState: state, preferredDisplayName: pubKey })
        }
    }

    Component {
        id: adaptorComponent

        MembersModelAdaptor {
            rosterModel: roster
            adminMembersModel: adminMembers
        }
    }

    TestCase {
        name: "MembersModelAdaptor"

        function init() {
            roster.clear()
            roster.add("0xjoined", Constants.CommunityMembershipRequestState.Accepted)
            roster.add("0xkickPending", Constants.CommunityMembershipRequestState.KickedPending)
            roster.add("0xbanPending", Constants.CommunityMembershipRequestState.BannedPending)
            roster.add("0xbannedNotYetRemoved", Constants.CommunityMembershipRequestState.Banned)

            adminMembers.clear()
            adminMembers.add("0xawaiting", Constants.CommunityMembershipRequestState.AwaitingAddress)
            adminMembers.add("0xpending", Constants.CommunityMembershipRequestState.Pending)
            adminMembers.add("0xacceptedPending", Constants.CommunityMembershipRequestState.AcceptedPending)
            adminMembers.add("0xdeclined", Constants.CommunityMembershipRequestState.Rejected)
            adminMembers.add("0xbanned", Constants.CommunityMembershipRequestState.Banned)
            adminMembers.add("0xunbanPending", Constants.CommunityMembershipRequestState.UnbannedPending)
        }

        function keys(model) {
            return SQUtils.ModelUtils.modelToFlatArray(model, "pubKey")
        }

        function test_joinedMembers() {
            const adaptor = createTemporaryObject(adaptorComponent, root)
            compare(keys(adaptor.joinedMembers),
                    ["0xjoined", "0xkickPending", "0xbanPending", "0xawaiting"])
        }

        function test_adminLists() {
            const adaptor = createTemporaryObject(adaptorComponent, root)
            compare(keys(adaptor.pendingMembers), ["0xpending", "0xacceptedPending"])
            compare(keys(adaptor.declinedMembers), ["0xdeclined"])
            compare(keys(adaptor.bannedMembers), ["0xbanned", "0xunbanPending"])
        }

        function test_joinedFollowsTheRoster() {
            const adaptor = createTemporaryObject(adaptorComponent, root)
            roster.add("0xnew", Constants.CommunityMembershipRequestState.Accepted)
            compare(keys(adaptor.joinedMembers),
                    ["0xjoined", "0xkickPending", "0xbanPending", "0xnew", "0xawaiting"])
            roster.setProperty(0, "membershipRequestState", Constants.CommunityMembershipRequestState.Banned)
            compare(keys(adaptor.joinedMembers),
                    ["0xkickPending", "0xbanPending", "0xnew", "0xawaiting"])
        }

        function test_unloadedRoster() {
            const adaptor = createTemporaryObject(adaptorComponent, root, { rosterModel: null })
            compare(keys(adaptor.joinedMembers), ["0xawaiting"])
        }
    }
}
