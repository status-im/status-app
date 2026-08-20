import QtQuick
import QtTest

import StatusQ.Popups

import AppLayouts.Profile.popups

import utils

Item {
    id: root
    width: 400
    height: 400

    Component {
        id: menuComponent
        WalletKeypairAccountMenu {}
    }

    TestCase {
        name: "WalletKeypairAccountMenu"
        when: windowShown

        function enabledTexts(menu) {
            const texts = []
            for (let i = 0; i < menu.count; ++i) {
                const item = menu.itemAt(i)
                if (!item || item instanceof StatusMenuSeparator)
                    continue
                if (item.enabled && item.text)
                    texts.push(item.text)
            }
            return texts
        }

        function test_profile_showsOnlyMoveToKeycard() {
            const menu = createTemporaryObject(menuComponent, root, {
                keyPair: { pairType: Constants.keypair.type.profile }
            })
            const texts = enabledTexts(menu)
            verify(texts.indexOf(qsTr("Move key pair to a Keycard")) >= 0)
            verify(texts.indexOf(qsTr("Rename key pair")) < 0)
            verify(texts.indexOf(qsTr("Remove key pair and derived accounts")) < 0)
        }

        function test_privateKey_showsRenameAndRemove_noMove() {
            const menu = createTemporaryObject(menuComponent, root, {
                keyPair: { pairType: Constants.keypair.type.privateKeyImport }
            })
            const texts = enabledTexts(menu)
            verify(texts.indexOf(qsTr("Rename key pair")) >= 0)
            verify(texts.indexOf(qsTr("Remove key pair and derived accounts")) >= 0)
            verify(texts.indexOf(qsTr("Move key pair to a Keycard")) < 0)
        }

        function test_seed_showsRenameMoveAndRemove() {
            const menu = createTemporaryObject(menuComponent, root, {
                keyPair: { pairType: Constants.keypair.type.seedImport }
            })
            const texts = enabledTexts(menu)
            verify(texts.indexOf(qsTr("Rename key pair")) >= 0)
            verify(texts.indexOf(qsTr("Move key pair to a Keycard")) >= 0)
            verify(texts.indexOf(qsTr("Remove key pair and derived accounts")) >= 0)
        }
    }
}
