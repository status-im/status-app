import QtQuick
import QtTest

import StatusQ.Models

import Models

import QtModelsToolkit

// The Wallet stores outlive a session: their ManageTokensController must not keep
// the signed-out profile's visibility preferences (see WalletAssetsStore and
// CollectiblesStore, which clear them when the profile's backend goes away and
// reload them when the next profile's backend arrives).
Item {
    id: root

    // The logged-in profile's saved preferences; null while signed out
    property var profile: null

    readonly property var profileA: ({ json: "" })
    readonly property var profileB: ({ json: "" })

    ManageCollectiblesModel {
        id: collectiblesModel
    }

    RolesRenamingModel {
        id: renamedModel
        sourceModel: collectiblesModel
        mapping: [
            RoleRename {
                from: "uid"
                to: "key"
            }
        ]
    }

    ManageTokensController {
        id: controller

        sourceModel: renamedModel
        settingsKey: "ProfileSwitchTest"
        serializeAsCollectibles: true

        onRequestSaveSettings: (jsonData) => {
            savingStarted()
            root.profile.json = jsonData
            savingFinished()
        }
        onRequestLoadSettings: {
            loadingStarted()
            loadingFinished(root.profile ? root.profile.json : "")
        }
    }

    // What the stores do when the profile's backend changes
    function switchProfile(profile) {
        root.profile = profile
        if (profile) {
            controller.revert()
        } else {
            controller.loadingStarted()
            controller.loadingFinished("")
        }
    }

    TestCase {
        name: "ManageTokensControllerProfileSwitch"
        when: windowShown

        readonly property string key: "123"

        function cleanup() {
            root.profileA.json = ""
            root.profileB.json = ""
            root.switchProfile(null)
        }

        function test_signedOutProfilePreferencesDoNotCarryOver() {
            root.switchProfile(root.profileA)
            tryVerify(() => controller.filterAcceptsKey(key))

            controller.showHideRegularToken(key, false)
            tryVerify(() => !controller.filterAcceptsKey(key))
            verify(root.profileA.json !== "")

            // sign out of A
            root.switchProfile(null)
            tryVerify(() => controller.filterAcceptsKey(key))
            compare(controller.hasSettings, false)

            // sign in to B: none of A's rules
            root.switchProfile(root.profileB)
            tryVerify(() => controller.filterAcceptsKey(key))
            compare(root.profileB.json, "")

            // back to A: its own rules again
            root.switchProfile(null)
            root.switchProfile(root.profileA)
            tryVerify(() => !controller.filterAcceptsKey(key))
        }
    }
}
