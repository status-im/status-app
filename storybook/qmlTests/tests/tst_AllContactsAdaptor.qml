import QtQuick
import QtTest
import QtQml

import utils

import StatusQ.Core.Utils
import mainui.adaptors
import AppLayouts.Profile.helpers

Item {
    id: root

    Component {
        id: testComponent

        AllContactsAdaptor {
            selfContactDetails: ContactDetails {
                publicKey: "0x0000x"
            }
        }
    }

    Component {
        id: contatsModelComponent

        ListModel {
            ListElement {
                pubKey: "0x0001x"
                displayName: "displayName 1"
            }
            ListElement {
                pubKey: "0x0002x"
                displayName: "displayName 2"
            }
        }
    }

    TestCase {
        name: "AllContactsAdaptorTest"

        function test_selfEntry() {
            const obj = createTemporaryObject(testComponent, root)
            const contactDetails = obj.selfContactDetails
            const model = obj.allContactsModel

            compare(model.rowCount(), 1)
            compare(ModelUtils.get(model, 0).pubKey, "0x0000x")

            contactDetails.displayName = "Display name"
            contactDetails.ensName = "@name"
            contactDetails.preferredDisplayName = "Preferred display name"
            contactDetails.alias = "Alias"
            contactDetails.icon = "Icon"
            contactDetails.colorId = 42
            contactDetails.onlineStatus = Constants.onlineStatus.online
            contactDetails.thumbnailImage = "Thumbnail image"
            contactDetails.largeImage = "Large image"
            contactDetails.bio = "Bio"

            compare(ModelUtils.get(model, 0).displayName, "Display name")
            compare(ModelUtils.get(model, 0).alias, "Alias")
            compare(ModelUtils.get(model, 0).bio, "Bio")
            compare(ModelUtils.get(model, 0).colorId, 42)
            compare(ModelUtils.get(model, 0).contactRequestState, Constants.ContactRequestState.None)
            compare(ModelUtils.get(model, 0).displayName, "Display name")
            compare(ModelUtils.get(model, 0).ensName, "@name")
            compare(ModelUtils.get(model, 0).isEnsVerified, true)
            compare(ModelUtils.get(model, 0).icon, "Icon")
            compare(ModelUtils.get(model, 0).isBlocked, false)
            compare(ModelUtils.get(model, 0).isContact, false)
            compare(ModelUtils.get(model, 0).isContactRequestReceived, false)
            compare(ModelUtils.get(model, 0).isContactRequestSent, false)
            compare(ModelUtils.get(model, 0).isCurrentUser, true)
            compare(ModelUtils.get(model, 0).isUntrustworthy, false)
            compare(ModelUtils.get(model, 0).isVerified, false)
            compare(ModelUtils.get(model, 0).largeImage, "Large image")
            compare(ModelUtils.get(model, 0).lastUpdated, 0)
            compare(ModelUtils.get(model, 0).lastUpdatedLocally, 0)
            compare(ModelUtils.get(model, 0).localNickname, "")
            compare(ModelUtils.get(model, 0).onlineStatus, Constants.onlineStatus.online)
            compare(ModelUtils.get(model, 0).preferredDisplayName, "Preferred display name")
            compare(ModelUtils.get(model, 0).removed, false)
            compare(ModelUtils.get(model, 0).thumbnailImage, "Thumbnail image")
            compare(ModelUtils.get(model, 0).trustStatus, Constants.trustStatus.unknown)
        }

        function test_accessToContacts() {
            const contactsModel = createTemporaryObject(contatsModelComponent, root)
            const contactDetails = createTemporaryObject(testComponent, root,
                                                         { contactsModel })
            const model = contactDetails.allContactsModel

            compare(model.rowCount(), 3)

            compare(ModelUtils.get(model, 0).pubKey, "0x0000x")
            compare(ModelUtils.get(model, 1).pubKey, "0x0001x")
            compare(ModelUtils.get(model, 2).pubKey, "0x0002x")

            compare(ModelUtils.get(model, 0).displayName, "")
            compare(ModelUtils.get(model, 1).displayName, "displayName 1")
            compare(ModelUtils.get(model, 2).displayName, "displayName 2")
        }

        function test_roleNames() {
            const contactDetails = createTemporaryObject(testComponent, root)
            const model = contactDetails.allContactsModel
            const roleNames = ModelUtils.roleNames(model)

            verify(roleNames.includes("pubKey"))

            verify(roleNames.includes("alias"))
            verify(roleNames.includes("bio"))
            verify(roleNames.includes("colorId"))
            verify(roleNames.includes("contactRequestState"))
            verify(roleNames.includes("displayName"))
            verify(roleNames.includes("ensName"))
            verify(roleNames.includes("isEnsVerified"))
            verify(roleNames.includes("icon"))
            verify(roleNames.includes("isBlocked"))
            verify(roleNames.includes("isContact"))
            verify(roleNames.includes("isContactRequestReceived"))
            verify(roleNames.includes("isContactRequestSent"))
            verify(roleNames.includes("isCurrentUser"))
            verify(roleNames.includes("isUntrustworthy"))
            verify(roleNames.includes("isVerified"))
            verify(roleNames.includes("largeImage"))
            verify(roleNames.includes("lastUpdated"))
            verify(roleNames.includes("lastUpdatedLocally"))
            verify(roleNames.includes("localNickname"))
            verify(roleNames.includes("onlineStatus"))
            verify(roleNames.includes("preferredDisplayName"))
            verify(roleNames.includes("removed"))
            verify(roleNames.includes("thumbnailImage"))
            verify(roleNames.includes("trustStatus"))
        }
    }
}
