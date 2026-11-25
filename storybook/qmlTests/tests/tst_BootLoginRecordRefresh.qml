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
            property int holdIntakeCalls: 0
            property int releaseIntakeCalls: 0
            property int holdCallsAtRelogin: -1

            enabled: true
            secureStorage: SecureStorage {
                property bool fromOtherVersion: false
                function isBootLoginRecordFromOtherVersion() {
                    return fromOtherVersion
                }
            }
            relogin: () => {
                reloginCalls++
                holdCallsAtRelogin = holdIntakeCalls
                return reloginAccepted
            }
            holdIntake: () => holdIntakeCalls++
            releaseIntake: () => releaseIntakeCalls++
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

        function test_recordFromOtherVersionHoldsTheIntakeForTheNextSession() {
            const refresh = createTemporaryObject(refreshComponent, root)
            refresh.secureStorage.fromOtherVersion = true

            refresh.adoptStarted()
            compare(refresh.holdIntakeCalls, 1)

            ignoreReloginWarning()
            refresh.adoptFinished()
            compare(refresh.holdCallsAtRelogin, 1)
            compare(refresh.holdIntakeCalls, 1)
            compare(refresh.releaseIntakeCalls, 0)
        }

        function test_ignoredReloginReleasesTheIntakeToThisSession() {
            const refresh = createTemporaryObject(refreshComponent, root,
                                                  { reloginAccepted: false })
            refresh.secureStorage.fromOtherVersion = true

            refresh.adoptStarted()
            ignoreReloginWarning()
            refresh.adoptFinished()
            compare(refresh.holdIntakeCalls, 1)
            compare(refresh.releaseIntakeCalls, 1)
        }

        function test_noRefreshNeverHoldsTheIntake_data() {
            return [
                { tag: "this version", enabled: true, fromOtherVersion: false },
                { tag: "flag off", enabled: false, fromOtherVersion: true }
            ]
        }

        function test_noRefreshNeverHoldsTheIntake(data) {
            const refresh = createTemporaryObject(refreshComponent, root,
                                                  { enabled: data.enabled })
            refresh.secureStorage.fromOtherVersion = data.fromOtherVersion

            refresh.adoptStarted()
            refresh.adoptFinished()
            compare(refresh.holdIntakeCalls, 0)
            compare(refresh.releaseIntakeCalls, 0)
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
