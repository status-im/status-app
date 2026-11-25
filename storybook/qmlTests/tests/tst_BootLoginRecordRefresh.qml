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

        function ignoreReloginWarning() {
            ignoreWarning(new RegExp("boot-login record from another app version"))
        }

        function test_recordFromOtherVersionRequestsOneReloginOnceTheAdoptFinished() {
            const refresh = createTemporaryObject(refreshComponent, root)
            refresh.secureStorage.fromOtherVersion = true

            compare(refresh.adoptStarted(), true)
            compare(refresh.reloginCalls, 0)

            ignoreReloginWarning()
            compare(refresh.adoptFinished(), true)
            compare(refresh.reloginCalls, 1)

            compare(refresh.adoptFinished(), false)
            compare(refresh.reloginCalls, 1)
        }

        function test_recordFromThisVersionRequestsNoRelogin() {
            const refresh = createTemporaryObject(refreshComponent, root)

            compare(refresh.adoptStarted(), false)
            compare(refresh.adoptFinished(), false)
            compare(refresh.reloginCalls, 0)
        }

        function test_flagOffRequestsNoRelogin() {
            const refresh = createTemporaryObject(refreshComponent, root, { enabled: false })
            refresh.secureStorage.fromOtherVersion = true

            compare(refresh.adoptStarted(), false)
            compare(refresh.adoptFinished(), false)
            compare(refresh.reloginCalls, 0)
        }

        function test_ignoredReloginLetsTheSessionLoad() {
            const refresh = createTemporaryObject(refreshComponent, root,
                                                  { reloginAccepted: false })
            refresh.secureStorage.fromOtherVersion = true

            compare(refresh.adoptStarted(), true)
            ignoreReloginWarning()
            compare(refresh.adoptFinished(), false)
            compare(refresh.reloginCalls, 1)
        }
    }
}
