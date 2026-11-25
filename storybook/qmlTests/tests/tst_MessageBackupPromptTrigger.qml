import QtQuick
import QtTest

import mainui
import utils

Item {
    id: root

    property int destroyedQueues: 0

    Component {
        id: settingsComponent

        QtObject {
            property int messageBackupVisitCount: 0
            property bool messageBackupContactRequestCompleted: false
        }
    }

    Component {
        id: triggerComponent

        MessageBackupPromptTrigger {
            sessionReady: true
            sectionId: "wallet"
            sectionType: Constants.appSection.wallet
        }
    }

    Component {
        id: queueComponent

        DeferredActionQueue {
            Component.onDestruction: ++root.destroyedQueues
        }
    }

    SignalSpy {
        id: requests

        signalName: "promptRequested"
    }

    TestCase {
        name: "MessageBackupPromptTrigger"

        readonly property var messenger: ({
            id: "personal", type: Constants.appSection.chat
        })
        readonly property var communityA: ({
            id: "communityA", type: Constants.appSection.community
        })
        readonly property var communityB: ({
            id: "communityB", type: Constants.appSection.community
        })
        readonly property var directory: ({
            id: "directory", type: Constants.appSection.communitiesPortal
        })
        readonly property var wallet: ({
            id: "wallet", type: Constants.appSection.wallet
        })

        function createTrigger(settings, properties = {}) {
            const trigger = createTemporaryObject(triggerComponent, root,
                                                  Object.assign({ settings }, properties))
            verify(trigger)
            requests.target = trigger
            requests.clear()
            return trigger
        }

        function navigate(trigger, section) {
            trigger.sectionId = section.id
            trigger.sectionType = section.type
            wait(0) // Process the deferred observation of the complete section change.
        }

        function test_thirdVisit_data() {
            return [
                { tag: "messenger", sections: [messenger, directory, messenger, wallet, messenger] },
                { tag: "communities", sections: [communityA, communityB, communityA] },
                { tag: "mixed", sections: [messenger, communityA, communityB] }
            ]
        }

        function test_thirdVisit(data) {
            const settings = createTemporaryObject(settingsComponent, root)
            const trigger = createTrigger(settings)
            let visits = 0
            for (const section of data.sections) {
                navigate(trigger, section)
                if (section.type === Constants.appSection.chat || section.type === Constants.appSection.community)
                    ++visits
                compare(settings.messageBackupVisitCount, visits)
                compare(requests.count, visits === 3 ? 1 : 0)
            }

            navigate(trigger, data.sections[data.sections.length - 1])
            compare(requests.count, 1)
            navigate(trigger, directory)
            navigate(trigger, communityB)
            compare(settings.messageBackupVisitCount, 3)
            compare(requests.count, 2)
        }

        function test_restoredSectionCountsOnceAfterSessionReady() {
            const settings = createTemporaryObject(settingsComponent, root, { messageBackupVisitCount: 1 })
            const trigger = createTrigger(settings, {
                sessionReady: false,
                sectionId: communityA.id,
                sectionType: communityA.type
            })
            wait(0)
            compare(settings.messageBackupVisitCount, 1)

            trigger.sessionReady = true
            tryCompare(settings, "messageBackupVisitCount", 2)
            navigate(trigger, communityA)
            compare(settings.messageBackupVisitCount, 2)
            compare(requests.count, 0)

            trigger.destroy()
            createTrigger(settings, { sectionId: messenger.id, sectionType: messenger.type })
            tryCompare(requests, "count", 1)
            compare(settings.messageBackupVisitCount, 3)
        }

        function test_contactActionIsIndependentAndDoesNotReplay() {
            const settings = createTemporaryObject(settingsComponent, root)
            const trigger = createTrigger(settings)
            trigger.recordSuccessfulContactRequest()
            verify(settings.messageBackupContactRequestCompleted)
            compare(settings.messageBackupVisitCount, 0)
            compare(requests.count, 1)
            trigger.recordSuccessfulContactRequest()
            compare(requests.count, 1)

            trigger.destroy()
            const nextSession = createTrigger(settings)
            wait(0)
            compare(requests.count, 0)
            nextSession.recordSuccessfulContactRequest()
            compare(requests.count, 0)

            const otherProfile = createTemporaryObject(settingsComponent, root)
            const otherSession = createTrigger(otherProfile)
            otherSession.recordSuccessfulContactRequest()
            compare(requests.count, 1)
        }

        function test_bothTriggersShareOneQueuedPrompt() {
            const settings = createTemporaryObject(settingsComponent, root, { messageBackupVisitCount: 2 })
            const trigger = createTrigger(settings)
            const queue = createTemporaryObject(queueComponent, trigger, { busy: true })
            let shown = 0
            trigger.promptRequested.connect(() => queue.schedule("backup", () => ++shown, true))

            trigger.recordSuccessfulContactRequest()
            navigate(trigger, communityA)
            compare(requests.count, 2)
            compare(queue.pendingCount, 1)
            compare(shown, 0)

            queue.busy = false
            compare(shown, 1)
        }

        function test_signOutDropsPendingContactPrompt() {
            const settings = createTemporaryObject(settingsComponent, root)
            const trigger = createTrigger(settings)
            const queue = createTemporaryObject(queueComponent, trigger, { blocked: true })
            trigger.promptRequested.connect(() => queue.schedule("backup",
                                                                 () => fail("Prompt shown after sign-out"), true))
            trigger.recordSuccessfulContactRequest()
            compare(queue.pendingCount, 1)

            const destroyedBefore = root.destroyedQueues
            trigger.destroy()
            tryCompare(root, "destroyedQueues", destroyedBefore + 1)
            const nextSession = createTrigger(settings)
            wait(0)
            compare(requests.count, 0)
            nextSession.recordSuccessfulContactRequest()
            compare(requests.count, 0)
            navigate(nextSession, messenger)
            navigate(nextSession, communityA)
            navigate(nextSession, communityB)
            compare(requests.count, 1)
        }
    }
}
