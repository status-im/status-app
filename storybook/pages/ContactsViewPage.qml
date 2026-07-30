import QtQuick

import StatusQ

import Models
import Storybook

import shared.stores as SharedStores
import AppLayouts.Profile.views
import AppLayouts.stores as AppLayoutStores
import mainui.adaptors

Item {
    ContactsView {
        sectionTitle: "Contacts"
        anchors.fill: parent
        anchors.leftMargin: 64
        anchors.topMargin: 16
        contentWidth: 560

        contactsStore: AppLayoutStores.ContactsStore {
            readonly property string myPublicKey: "0xdeadbeef"
            readonly property string myCompressedPublicKey: "zx3shdeadbeef"

            function joinPrivateChat(pubKey) {
                console.info("ContactsStore::joinPrivateChat", pubKey)
            }
            function acceptContactRequest(pubKey, contactRequestId) {
                console.info("ContactsStore::acceptContactRequest", pubKey, contactRequestId)
            }
            function dismissContactRequest(pubKey, contactRequestId) {
                console.info("ContactsStore::dismissContactRequest", pubKey, contactRequestId)
            }

            function resolveENS(value) {
                console.info("ContactsStore::resolveENS", value)
                if (value.startsWith("0x") || value.startsWith("zx3sh"))
                    resolvedENS(value, "", "")
                else
                    resolvedENS("", "", "")
            }

            signal resolvedENS(string resolvedPubKey, string resolvedAddress,
                               string uuid)
        }
        utilsStore: SharedStores.UtilsStore {
            function getEmojiHash(publicKey) {
                if (publicKey === "")
                    return ""

                return JSON.stringify(
                            ["👨🏻‍🍼", "🏃🏿‍♂️", "🌇", "🤶🏿", "🏮","🤷🏻‍♂️", "🤦🏻",
                             "📣", "🤎", "👷🏽", "😺", "🥞", "🔃", "🧝🏽‍♂️"])
            }
            function isCompressedPubKey(key) {
                return !!key && key.startsWith("zx3sh")
            }
            function getDecompressedPk(value) {
                return "0x" + value
            }
        }

        mutualContactsModel: adaptor.mutualContacts
        blockedContactsModel: adaptor.blockedContacts
        pendingContactsModel: adaptor.pendingContacts
        dismissedReceivedRequestContactsModel: adaptor.dismissedReceivedRequestContacts
        pendingReceivedContactsCount: adaptor.pendingReceivedRequestContacts.count
    }

    ContactsModelAdaptor {
        id: adaptor

        allContacts: UsersModel {}
    }
}

// category: Views
// status: good
