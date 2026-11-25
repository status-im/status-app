import QtQuick
import QtTest

import StatusQ

import mainui

Item {
    id: root

    Component {
        id: refreshComponent

        BootLoginRecordRefresh {
            property int reloginCalls: 0
            property bool reloginAccepted: true

            enabled: true
            secureStorage: SecureStorage {
                property bool fromOtherVersion: false
                function isBootLoginRecordFromOtherVersion() {
                    return fromOtherVersion
                }
            }
            relogin: () => {
                reloginCalls++
                return reloginAccepted
            }
        }
    }

    TestCase {
        name: "BootLoginRecordRefresh"

        function test_recordFromOtherVersionRequestsOneRelogin() {
            const refresh = createTemporaryObject(refreshComponent, root)
            refresh.secureStorage.fromOtherVersion = true

            compare(refresh.reloginIfRecordFromOtherVersion(), true)
            compare(refresh.reloginCalls, 1)
        }

        function test_recordFromThisVersionRequestsNoRelogin() {
            const refresh = createTemporaryObject(refreshComponent, root)

            compare(refresh.reloginIfRecordFromOtherVersion(), false)
            compare(refresh.reloginCalls, 0)
        }

        function test_flagOffRequestsNoRelogin() {
            const refresh = createTemporaryObject(refreshComponent, root, { enabled: false })
            refresh.secureStorage.fromOtherVersion = true

            compare(refresh.reloginIfRecordFromOtherVersion(), false)
            compare(refresh.reloginCalls, 0)
        }

        function test_ignoredReloginLetsTheSessionLoad() {
            const refresh = createTemporaryObject(refreshComponent, root,
                                                  { reloginAccepted: false })
            refresh.secureStorage.fromOtherVersion = true

            compare(refresh.reloginIfRecordFromOtherVersion(), false)
            compare(refresh.reloginCalls, 1)
        }
    }
}
