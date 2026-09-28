import QtQuick
import QtTest

import StatusQ.Core.Utils as SQUtils

import QtModelsToolkit
import SortFilterProxyModel

import shared.views
import utils

Item {
    id: root

    width: 400
    height: 500

    ListModel {
        id: testContactsModel

        function addContact(pubKey, displayName, isContact, isBlocked) {
            append({
                       pubKey: pubKey,
                       compressedPubKey: "zx" + pubKey,
                       displayName: displayName,
                       ensName: "",
                       alias: displayName + "-alias",
                       localNickname: "",
                       icon: "",
                       colorId: 1,
                       onlineStatus: Constants.onlineStatus.online,
                       isContact: isContact,
                       isBlocked: isBlocked,
                       isEnsVerified: false
                   })
        }
    }

    ListModel {
        id: testMembersListModel
    }

    SortFilterProxyModel {
        id: testMembersModel
        sourceModel: testMembersListModel

        property var memberKeys: []

        function setMembers(pubKeys) {
            memberKeys = pubKeys
            testMembersListModel.clear()
            for (const pubKey of pubKeys)
                testMembersListModel.append({ pubKey: pubKey })
        }

        function hasMember(pubKey) {
            return memberKeys.includes(pubKey)
        }
    }

    Component {
        id: panelComponent

        ExistingContacts {
            width: root.width
            height: root.height
            contactsModel: testContactsModel
            membersModel: testMembersModel
            communityId: "community-1"
            hideCommunityMembers: true
            showCheckbox: true
        }
    }

    TestCase {
        name: "ExistingContacts"
        when: windowShown

        function init() {
            testContactsModel.clear()
            testMembersModel.setMembers([])
            testContactsModel.addContact("0xaaa", "Alice", true, false)
            testContactsModel.addContact("0xbbb", "Bob", true, false)
            testContactsModel.addContact("0xccc", "Carol", true, false)
            testContactsModel.addContact("0xddd", "Dave", false, false)
            testContactsModel.addContact("0xeee", "Eve", true, true)
        }

        function namesOnList(panel) {
            const listView = findChild(panel, "ExistingContacts_ListView")
            verify(!!listView)
            const names = []
            for (let i = 0; i < listView.count; i++)
                names.push(SQUtils.ModelUtils.get(listView.model, i, "displayName"))
            return names
        }

        function test_hidesContactsWhoAreAlreadyCommunityMembers() {
            testMembersModel.setMembers(["0xaaa", "0xccc"])
            const panel = createTemporaryObject(panelComponent, root)
            verify(!!panel)
            tryCompare(panel, "count", 1)
            compare(namesOnList(panel), ["Bob"])
        }

        function test_showsMemberContactsWhenHideCommunityMembersIsOff() {
            testMembersModel.setMembers(["0xaaa"])
            const panel = createTemporaryObject(panelComponent, root, { hideCommunityMembers: false })
            verify(!!panel)
            tryCompare(panel, "count", 3)
            compare(namesOnList(panel), ["Alice", "Bob", "Carol"])
        }

        function test_hidesNonContactsAndBlocked() {
            const panel = createTemporaryObject(panelComponent, root)
            verify(!!panel)
            tryCompare(panel, "count", 3)
            compare(namesOnList(panel), ["Alice", "Bob", "Carol"])
        }

        function test_searchFiltersVisibleContacts() {
            const panel = createTemporaryObject(panelComponent, root)
            verify(!!panel)
            tryCompare(panel, "count", 3)

            panel.filterText = "bo"
            tryCompare(panel, "count", 1)
            compare(namesOnList(panel), ["Bob"])
        }

        function test_hidesContactAfterTheyJoined() {
            const panel = createTemporaryObject(panelComponent, root)
            verify(!!panel)
            tryCompare(panel, "count", 3)

            testMembersModel.setMembers(["0xaaa"])
            const panelAfterJoin = createTemporaryObject(panelComponent, root)
            verify(!!panelAfterJoin)
            tryCompare(panelAfterJoin, "count", 2)
            compare(namesOnList(panelAfterJoin), ["Bob", "Carol"])
        }
    }
}
