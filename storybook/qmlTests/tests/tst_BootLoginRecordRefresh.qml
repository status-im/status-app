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
            property var keptRecords: []

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
            // The KeptCurrent rewrite stamps this version's versionCode into the record
            keepCurrent: (record) => {
                keptRecords.push(record)
                secureStorage.fromOtherVersion = false
            }
            holdIntake: () => holdIntakeCalls++
            releaseIntake: () => releaseIntakeCalls++
        }
    }

    readonly property string record: JSON.stringify({ version: 1, keyUid: "uid_1", versionCode: 2 })

    TestCase {
        name: "BootLoginRecordRefresh"

        function ignoreReloginWarning() {
            ignoreWarning(new RegExp("boot-login record from another app version"))
        }

        function test_recordFromOtherVersionRequestsOneReloginOnceTheAdoptFinished() {
            const refresh = createTemporaryObject(refreshComponent, root)
            refresh.secureStorage.fromOtherVersion = true

            compare(refresh.adoptStarted(root.record), true)
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

            refresh.adoptStarted(root.record)
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

            refresh.adoptStarted(root.record)
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

            refresh.adoptStarted(root.record)
            refresh.adoptFinished()
            compare(refresh.holdIntakeCalls, 0)
            compare(refresh.releaseIntakeCalls, 0)
        }

        // Logged in at start (SessionRoot opens on the session) and the in-progress boot
        // login adopted by the login screen (onboarding KeptCurrent) take the same path
        function test_everyAdoptPathRefreshesARecordFromOtherVersion_data() {
            return [
                { tag: "logged in at start" },
                { tag: "adopt during an in-progress boot login" }
            ]
        }

        function test_everyAdoptPathRefreshesARecordFromOtherVersion(data) {
            const refresh = createTemporaryObject(refreshComponent, root)
            refresh.secureStorage.fromOtherVersion = true

            compare(refresh.adoptStarted(root.record), true)
            ignoreReloginWarning()
            compare(refresh.adoptFinished(), true)
            compare(refresh.reloginCalls, 1)
        }

        // On the in-progress adopt path the onboarding flow moves to the app by itself: once
        // the relogin started the session must not load it, or its contentLoaded ends the
        // window's loading screen and "Signing out…" shows
        function test_anAcceptedReloginKeepsTheSessionFromLoadingTheApp_data() {
            return [
                { tag: "logged in at start" },
                { tag: "adopt during an in-progress boot login" }
            ]
        }

        function test_anAcceptedReloginKeepsTheSessionFromLoadingTheApp(data) {
            const refresh = createTemporaryObject(refreshComponent, root)
            refresh.secureStorage.fromOtherVersion = true

            refresh.adoptStarted(root.record)
            compare(refresh.reloginStarted, false)
            ignoreReloginWarning()
            refresh.adoptFinished()
            compare(refresh.reloginStarted, true)
        }

        function test_noOrIgnoredReloginLetsTheSessionLoadTheApp_data() {
            return [
                { tag: "this version", fromOtherVersion: false, reloginAccepted: true },
                { tag: "ignored relogin", fromOtherVersion: true, reloginAccepted: false }
            ]
        }

        function test_noOrIgnoredReloginLetsTheSessionLoadTheApp(data) {
            const refresh = createTemporaryObject(refreshComponent, root,
                                                  { reloginAccepted: data.reloginAccepted })
            refresh.secureStorage.fromOtherVersion = data.fromOtherVersion

            refresh.adoptStarted(root.record)
            if (data.fromOtherVersion)
                ignoreReloginWarning()
            refresh.adoptFinished()
            compare(refresh.reloginStarted, false)
        }

        // The KeptCurrent rewrite removes the version mismatch, so it is read first
        function test_theVersionIsReadBeforeTheKeptCurrentRewrite() {
            const refresh = createTemporaryObject(refreshComponent, root)
            refresh.secureStorage.fromOtherVersion = true

            compare(refresh.adoptStarted(root.record), true)
            compare(refresh.keptRecords, [root.record])
            compare(refresh.secureStorage.fromOtherVersion, false)
        }

        function test_theAdoptKeepsTheRecordCurrent_data() {
            return [
                { tag: "this version", enabled: true, fromOtherVersion: false },
                { tag: "other version", enabled: true, fromOtherVersion: true },
                { tag: "flag off", enabled: false, fromOtherVersion: true }
            ]
        }

        function test_theAdoptKeepsTheRecordCurrent(data) {
            const refresh = createTemporaryObject(refreshComponent, root,
                                                  { enabled: data.enabled })
            refresh.secureStorage.fromOtherVersion = data.fromOtherVersion

            refresh.adoptStarted(root.record)
            compare(refresh.keptRecords, [root.record])
        }

        function test_recordFromThisVersionRequestsNoRelogin() {
            const refresh = createTemporaryObject(refreshComponent, root)

            compare(refresh.adoptStarted(root.record), false)
            compare(refresh.adoptFinished(), false)
            compare(refresh.reloginCalls, 0)
        }

        function test_flagOffRequestsNoRelogin() {
            const refresh = createTemporaryObject(refreshComponent, root, { enabled: false })
            refresh.secureStorage.fromOtherVersion = true

            compare(refresh.adoptStarted(root.record), false)
            compare(refresh.adoptFinished(), false)
            compare(refresh.reloginCalls, 0)
        }

        function test_ignoredReloginLetsTheSessionLoad() {
            const refresh = createTemporaryObject(refreshComponent, root,
                                                  { reloginAccepted: false })
            refresh.secureStorage.fromOtherVersion = true

            compare(refresh.adoptStarted(root.record), true)
            ignoreReloginWarning()
            compare(refresh.adoptFinished(), false)
            compare(refresh.reloginCalls, 1)
        }
    }
}
