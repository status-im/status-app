import QtQuick
import QtTest

import Storybook.Testing

import StatusQ.Core.Utils as SQUtils

import QtModelsToolkit

import AppLayouts.ActivityCenter.adaptors
import AppLayouts.ActivityCenter.helpers
import AppLayouts.Chat.adaptors

import shared.status

Item {
    id: root

    // mention wire format: "@0x" + 130 lowercase hex chars
    readonly property string aliceKey: "0x04" + "a".repeat(128)
    readonly property string strangerKey: "0x04" + "b".repeat(128)
    readonly property string myKey: "0x04" + "c".repeat(128)

    readonly property var snapshotRoles: [
        "notificationId", "notificationType", "unread", "title", "content", "primaryText",
        "actionText", "timestamp", "dismissed", "redirectToLink"
    ]

    Component {
        id: notificationsComponent

        ListModel {
            property int rowsToGenerate: 0

            Component.onCompleted: {
                const types = [
                    ActivityCenterTypes.NotificationType.ActivityCenterNotificationTypeNews,
                    ActivityCenterTypes.NotificationType.NewInstallationReceived,
                    ActivityCenterTypes.NotificationType.NewInstallationCreated
                ]
                for (let i = 0; i < rowsToGenerate; i++) {
                    append({
                        id: "n" + i,
                        notificationType: types[i % types.length],
                        // deterministic, unsorted timestamps with duplicates
                        timestamp: 1700000000000 + ((i * 7919) % 31) * 1000,
                        read: i % 4 === 0,
                        dismissed: i % 5 === 3,
                        accepted: false,
                        chatId: "", communityId: "", sectionId: "", threadId: "", threadName: "",
                        author: "", chatType: 0, name: "",
                        membershipStatus: ActivityCenterTypes.ActivityCenterMembershipStatus.None,
                        newsTitle: "News title " + i,
                        newsDescription: "News description " + i,
                        newsContent: "News content " + i,
                        newsImageUrl: "",
                        newsLink: i % 2 ? "https://status.app/news/" + i : "",
                        newsLinkLabel: i % 2 ? "Read more" : "",
                        installationId: "installation-" + i,
                        message: "", repliedMessage: "", tokenData: ""
                    })
                }
            }
        }
    }

    Component {
        id: contactsComponent
        ListModel {}
    }

    Component {
        id: adaptorComponent

        ActivityCenterAdaptor {
            contactsModel: contactsComponent.createObject(this)
            userProfileName: "Me"
        }
    }

    Component {
        id: namedContactsComponent

        ListModel {
            // mirrors the backend contacts model API used by ContactModelEntry
            function hasUser(pubKey) {
                return SQUtils.ModelUtils.contains(this, "pubKey", pubKey)
            }

            Component.onCompleted: append({ pubKey: root.aliceKey, preferredDisplayName: "Alice" })
        }
    }

    Component {
        id: messengerAdaptorComponent

        ActivityCenterAdaptor {
            contactsModel: namedContactsComponent.createObject(this)
            userProfileName: "Me"
        }
    }

    // The app wires one MentionResolver for every surface that renders message text and
    // injects it (see AppMain); the tests do the same, so the naming, the renames and the
    // message's own names are covered the way the adaptor is really used.
    Component {
        id: mentionsComponent

        QtObject {
            id: mentions

            property var contactsModel

            readonly property var resolveFn: (text, knownNames) => mentions.resolver.resolveFor(text, knownNames)

            readonly property MentionNamesAdaptor names: MentionNamesAdaptor {
                contactsModel: mentions.contactsModel
            }

            readonly property MentionResolver resolver: MentionResolver {
                sourceModel: mentions.names.model
                nameRole: "preferredDisplayName"
                selfPubKey: root.myKey
                selfName: "Me"
                aliasProvider: publicKey => "Alias " + publicKey.substring(0, 6)
            }
        }
    }

    Component {
        id: messageNotificationsComponent

        ListModel {
            function appendNotification(id, notificationType, unparsedText, mentionedNames = "") {
                append({
                    id, notificationType,
                    timestamp: 1700000000000, read: false, dismissed: false, accepted: false,
                    chatId: "", communityId: "", sectionId: "",
                    author: "0x04author", chatType: 0, name: "",
                    membershipStatus: ActivityCenterTypes.ActivityCenterMembershipStatus.None,
                    newsTitle: "", newsDescription: "", newsContent: "", newsImageUrl: "",
                    newsLink: "", newsLinkLabel: "", installationId: "",
                    message: {
                        id: id + "-message", communityId: "", amISender: false, unparsedText,
                        mentionedNames,
                        albumMessageImages: "",
                        contactRequestState: ActivityCenterTypes.ActivityCenterContactRequestState.Pending
                    },
                    repliedMessage: "", tokenData: ""
                })
            }
        }
    }

    Component {
        id: loaderComponent

        Loader {
            id: acLoader

            property var notifications

            active: false
            sourceComponent: ActivityCenterAdaptor {
                notifications: acLoader.notifications
                contactsModel: contactsComponent.createObject(this)
                userProfileName: "Me"
            }
        }
    }

    ObjectCounter {
        id: objectCounter
    }

    TestCase {
        name: "ActivityCenterAdaptor"

        function snapshot(model) {
            const rows = []
            const count = model.ModelCount.count
            for (let i = 0; i < count; i++) {
                const row = {}
                for (const role of root.snapshotRoles)
                    row[role] = SQUtils.ModelUtils.get(model, i, role)
                rows.push(row)
            }
            return rows
        }

        function cleanup() {
            objectCounter.stop()
        }

        // characterization of the output against the ObjectProxyModel-sorted implementation
        function test_outputOrderAndRoles() {
            const notifications = createTemporaryObject(notificationsComponent, root, { rowsToGenerate: 30 })
            const adaptor = createTemporaryObject(adaptorComponent, root, { notifications })
            const rows = snapshot(adaptor.model)

            // dismissed rows are filtered out (none of them is a membership request)
            compare(rows.length, 24)

            for (let i = 1; i < rows.length; i++)
                verify(rows[i - 1].timestamp >= rows[i].timestamp, "sorted newest first at " + i)

            const expectedIds = []
            for (let i = 0; i < 30; i++)
                if (i % 5 !== 3)
                    expectedIds.push(i)
            // stable sort: source order is kept for equal timestamps
            expectedIds.sort((a, b) => {
                const ta = ((a * 7919) % 31), tb = ((b * 7919) % 31)
                return ta !== tb ? tb - ta : a - b
            })
            compare(JSON.stringify(rows.map(r => r.notificationId)),
                    JSON.stringify(expectedIds.map(i => "n" + i)))

            for (const row of rows) {
                const i = parseInt(row.notificationId.substring(1))
                compare(row.unread, i % 4 !== 0, row.notificationId)
                compare(row.dismissed, false)
                compare(row.timestamp, 1700000000000 + ((i * 7919) % 31) * 1000)
            }

            const news = rows.find(r => r.notificationId === "n9")
            compare(news.notificationType, ActivityCenterTypes.NotificationType.ActivityCenterNotificationTypeNews)
            compare(news.title, "News title 9")
        }

        function test_sourceChangesResort() {
            const notifications = createTemporaryObject(notificationsComponent, root, { rowsToGenerate: 6 })
            const adaptor = createTemporaryObject(adaptorComponent, root, { notifications })

            notifications.setProperty(0, "timestamp", 1800000000000)
            tryCompare(SQUtils.ModelUtils.get(adaptor.model, 0), "notificationId", "n0")

            notifications.setProperty(0, "dismissed", true)
            tryVerify(() => !SQUtils.ModelUtils.contains(adaptor.model, "notificationId", "n0"))

            notifications.setProperty(1, "read", true)
            tryCompare(SQUtils.ModelUtils.getByKey(adaptor.model, "notificationId", "n1"), "unread", false)
        }

        // Building the adaptor must not create a per-notification QObject graph up front
        function test_noPerRowObjectsUntilRequested() {
            const notifications = createTemporaryObject(notificationsComponent, root, { rowsToGenerate: 100 })

            objectCounter.start()
            const adaptor = createTemporaryObject(adaptorComponent, root, { notifications })
            compare(adaptor.model.ModelCount.count, 80)

            compare(objectCounter.count("QQmlPropertyMap"), 0)

            // reading one row materialises exactly one row
            SQUtils.ModelUtils.get(adaptor.model, 0, "title")
            compare(objectCounter.count("QQmlPropertyMap"), 1)
        }

        function test_messageContentRenderedFromUnparsedText_data() {
            return [
                { tag: "mention", type: ActivityCenterTypes.NotificationType.Mention },
                { tag: "reply", type: ActivityCenterTypes.NotificationType.Reply },
                { tag: "contact request", type: ActivityCenterTypes.NotificationType.ContactRequest }
            ]
        }

        // the adaptor with the resolver its consumer injects, as AppMain wires it
        function createMessengerAdaptor(notifications) {
            const adaptor = createTemporaryObject(messengerAdaptorComponent, root, { notifications })
            const mentions = createTemporaryObject(mentionsComponent, root,
                                                   { contactsModel: adaptor.contactsModel })
            adaptor.resolveMentionsFn = mentions.resolveFn
            return { adaptor, mentions }
        }

        function test_messageContentRenderedFromUnparsedText(data) {
            failOnWarning(/Binding loop detected/)
            const notifications = createTemporaryObject(messageNotificationsComponent, root)
            notifications.appendNotification("n1", data.type,
                                             `**hi** @${root.aliceKey} @${root.myKey} @${root.strangerKey}\nbye`)
            const { adaptor } = createMessengerAdaptor(notifications)

            const content = SQUtils.ModelUtils.get(adaptor.model, 0, "content")
            verify(content.startsWith("<b>hi</b> "), content)
            verify(content.includes(`>@Alice</a>`), content)
            verify(content.includes(`>@Me</a>`), content)
            verify(content.includes(`>@Alias 0x04bb</a>`), content)
            // the content is styled text: the line break is kept, not collapsed
            verify(content.endsWith("<br/>bye"), content)
        }

        function test_mentionFollowsContactRename() {
            failOnWarning(/Binding loop detected/)
            const notifications = createTemporaryObject(messageNotificationsComponent, root)
            notifications.appendNotification("n1", ActivityCenterTypes.NotificationType.Mention,
                                             `hi @${root.aliceKey}`)
            const { adaptor } = createMessengerAdaptor(notifications)
            const content = () => SQUtils.ModelUtils.get(adaptor.model, 0, "content")
            verify(content().includes("@Alice<"), content())

            adaptor.contactsModel.setProperty(0, "preferredDisplayName", "Alicia")
            tryVerify(() => content().includes("@Alicia<"), 1000, content())
        }

        // a mention the contacts cannot name takes the name sent with the message,
        // before an alias
        function test_unknownMentionTakesMessageNames() {
            const notifications = createTemporaryObject(messageNotificationsComponent, root)
            notifications.appendNotification("n1", ActivityCenterTypes.NotificationType.Mention,
                                             `hi @${root.strangerKey}`,
                                             JSON.stringify({ [root.strangerKey]: "Stranger" }))
            const { adaptor } = createMessengerAdaptor(notifications)

            const content = SQUtils.ModelUtils.get(adaptor.model, 0, "content")
            verify(content.includes(`>@Stranger</a>`), content)
        }

        function test_inactiveLoaderReleasesAdaptor() {
            const notifications = createTemporaryObject(notificationsComponent, root, { rowsToGenerate: 50 })
            const loader = createTemporaryObject(loaderComponent, root, { notifications })

            objectCounter.start()
            loader.active = true
            verify(!!loader.item)
            snapshot(loader.item.model) // a view showing every row
            verify(objectCounter.count("QQmlPropertyMap") >= 40)

            loader.active = false
            tryCompare(loader, "item", null)
            tryVerify(() => objectCounter.count("QQmlPropertyMap") === 0)
        }
    }
}
