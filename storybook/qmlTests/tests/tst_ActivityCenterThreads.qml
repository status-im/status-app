import QtQuick
import QtTest

import StatusQ.Core.Utils as SQUtils

import AppLayouts.ActivityCenter.adaptors
import AppLayouts.ActivityCenter.controls
import AppLayouts.ActivityCenter.panels
import AppLayouts.ActivityCenter.helpers

import utils

Item {
    id: root
    width: 500
    height: 300

    Component {
        id: notificationsComponent
        ListModel { dynamicRoles: true }
    }

    Component {
        id: adaptorComponent
        ActivityCenterAdaptor {
            contactsModel: ListModel {}
            userProfileName: "Me"
            getCommunityDetails: () => ({ name: "Community", image: "" })
            getChatDetails: () => ({ name: "General", icon: "" })
        }
    }

    Component {
        id: cardComponent
        NotificationCard { width: 320 }
    }

    Component {
        id: messengerComponent
        NotificationAdaptorMessenger {
            contactsModel: ListModel {}
            notification: ActivityNotification {
                notificationId: "notification"
                chatType: Constants.chatType.oneToOne
                threadId: "thread"
                threadName: "Planning"
            }
        }
    }

    Component {
        id: panelComponent
        ActivityCenterPanel {
            width: 480
            height: 300
            hasAdmin: false
            hasMentions: true
            hasReplies: true
            hasContactRequests: false
            hasMembership: false
            hasSystem: false
            hasNews: false
            activeGroup: ActivityCenterTypes.ActivityCenterGroup.All
            readNotificationsStatus: ActivityCenterTypes.ActivityCenterReadType.All
            hasUnreadNotifications: true
            newsSettingsStatus: Constants.settingsSection.notifications.sendAlertsValue
            newsEnabledViaRSS: true
        }
    }

    Component {
        id: spyComponent
        SignalSpy {}
    }

    TestCase {
        name: "ActivityCenterThreads"
        when: windowShown

        function notification(type, chatType, threadId, threadName) {
            return {
                id: "notification", notificationType: type, timestamp: 1,
                read: false, dismissed: false, accepted: false,
                chatId: "chat", communityId: "community", sectionId: "section",
                threadId: threadId, threadName: threadName,
                author: "", chatType: chatType, name: "",
                membershipStatus: 0, newsTitle: "", newsDescription: "", newsContent: "",
                newsImageUrl: "", newsLink: "", newsLinkLabel: "",
                message: { id: "message", communityId: "community", amISender: false,
                           messageText: "Hello", unparsedText: "Hello", albumMessageImages: "" },
                repliedMessage: "", tokenData: ""
            }
        }

        function test_threadContext_data() {
            const rows = []
            for (const type of [ActivityCenterTypes.NotificationType.Mention, ActivityCenterTypes.NotificationType.Reply]) {
                for (const chatType of [Constants.chatType.oneToOne, Constants.chatType.privateGroupChat, Constants.chatType.communityChat])
                    rows.push({ tag: type + "-" + chatType, type, chatType })
            }
            return rows
        }

        function test_tertiaryContext() {
            const adaptor = createTemporaryObject(messengerComponent, root)
            verify(!!adaptor)
            compare(adaptor.context.tertiaryText, "Planning")
            compare(adaptor.nestedSubsectionId, "thread")
            compare(adaptor.tertiaryText, adaptor.context.tertiaryText)
            compare(adaptor.context.tertiaryIconName, "thread")
            compare(adaptor.tertiaryIconName, adaptor.context.tertiaryIconName)

            adaptor.notification.threadName = ""
            compare(adaptor.context.tertiaryText, "Thread")
            adaptor.notification.threadId = ""
            compare(adaptor.context.tertiaryText, "")
            compare(adaptor.context.tertiaryIconName, "")
            compare(adaptor.nestedSubsectionId, "")
        }

        function test_threadContext(data) {
            const source = createTemporaryObject(notificationsComponent, root)
            source.append(notification(data.type, data.chatType, "thread", "Release planning"))
            const adaptor = createTemporaryObject(adaptorComponent, root, { notifications: source })
            const model = adaptor.model
            compare(SQUtils.ModelUtils.get(model, 0, "tertiaryText"), "Release planning")
            compare(SQUtils.ModelUtils.get(model, 0, "tertiaryIconName"), "thread")
            compare(SQUtils.ModelUtils.get(model, 0, "nestedSubsectionId"), "thread")
            compare(SQUtils.ModelUtils.get(model, 0, "subsectionId"), "chat")
            compare(SQUtils.ModelUtils.get(model, 0, "subsectionItemId"), "message")
            compare(SQUtils.ModelUtils.get(model, 0, "redirectToDetails"), true)
            compare(SQUtils.ModelUtils.get(model, 0, "primaryText"),
                    data.chatType === Constants.chatType.oneToOne ? "" :
                    data.chatType === Constants.chatType.communityChat ? "Community" : "General")
            compare(SQUtils.ModelUtils.get(model, 0, "secondaryText"),
                    data.chatType === Constants.chatType.communityChat ? "#General" : "")

            // Updates must not retain a title or navigation target from the previous payload.
            source.setProperty(0, "threadName", "")
            compare(SQUtils.ModelUtils.get(model, 0, "tertiaryText"), "Thread")
            source.setProperty(0, "threadId", "")
            compare(SQUtils.ModelUtils.get(model, 0, "tertiaryText"), "")
            compare(SQUtils.ModelUtils.get(model, 0, "tertiaryIconName"), "")
            compare(SQUtils.ModelUtils.get(model, 0, "nestedSubsectionId"), "")
        }

        function test_unrelatedNotifications() {
            const source = createTemporaryObject(notificationsComponent, root)
            source.append(notification(ActivityCenterTypes.NotificationType.NewPrivateGroupChat,
                                       Constants.chatType.privateGroupChat, "thread", "Ignored"))
            const adaptor = createTemporaryObject(adaptorComponent, root, { notifications: source })
            compare(SQUtils.ModelUtils.get(adaptor.model, 0, "tertiaryText"), "")
            compare(SQUtils.ModelUtils.get(adaptor.model, 0, "tertiaryIconName"), "")
            compare(SQUtils.ModelUtils.get(adaptor.model, 0, "nestedSubsectionId"), "")
        }

        function test_clickOpensThreadMessage_data() {
            return test_threadContext_data()
        }

        function test_clickOpensThreadMessage(data) {
            const source = createTemporaryObject(notificationsComponent, root)
            source.append(notification(data.type, data.chatType, "thread", "Planning"))
            const adaptor = createTemporaryObject(adaptorComponent, root, { notifications: source })
            const panel = createTemporaryObject(panelComponent, root, { notificationsModel: adaptor.model })
            const spy = createTemporaryObject(spyComponent, root, { target: panel, signalName: "redirectToDetails" })
            const list = findChild(panel, "listView")
            tryVerify(() => list.itemAtIndex(0) !== null)
            const card = list.itemAtIndex(0)
            compare(card.tertiaryText, "Planning")
            mouseClick(card)
            compare(spy.count, 1)
            const args = spy.signalArguments[0]
            compare(args[0], "section")
            compare(args[1], "chat")
            compare(args[2], "message")
            compare(args[3], "thread")

            // A subsequent notification outside threads must keep normal chat navigation.
            source.setProperty(0, "threadId", "")
            tryCompare(card, "tertiaryText", "")
            mouseClick(card)
            compare(spy.count, 2)
            compare(spy.signalArguments[1][3], "")
        }

        function test_directMessageThreadBreadcrumb() {
            const card = createTemporaryObject(cardComponent, root, {
                tertiaryText: "<b>Release planning</b>", tertiaryIconName: "thread", title: "Alice", content: "Hello"
            })
            verify(card)
            const title = findChild(card, "tertiaryText")
            verify(title)
            tryCompare(title, "visible", true)
            compare(title.textFormat, Text.PlainText)
            verify(title.width > 0)
            card.width = 120
            verify(title.width >= 0)
            verify(title.width <= card.width)
        }
    }
}
