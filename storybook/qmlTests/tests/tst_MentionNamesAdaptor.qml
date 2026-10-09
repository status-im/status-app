import QtQuick
import QtTest

import AppLayouts.Chat.adaptors
import StatusQ.Core.Utils as SQUtils

/*
 Configuration analysis for MentionNamesAdaptor
 ==============================================
 The adaptor is the lookup source behind MentionResolver, so what matters is how
 ModelUtils.getByKey(model, "pubKey", key, "preferredDisplayName") behaves over it:

 - a mention of somebody outside the chat still resolves (the bug this exists for:
   in a 1:1 the chat's own user model is narrowed to mutual contacts)
 - the chat's own user list takes precedence, so resolution that already worked
   before the contacts fallback existed is unchanged
 - either input may be absent (a popup opens before its store is wired, a chat has
   no member model yet) without taking the other one down
 - with neither input present every key is simply unknown, and a source wired in
   later starts resolving
 - the local user resolves too, since neither input carries them in a 1:1 — the
   contacts model leaves the local user out and the chat's users are mutual contacts
*/
Item {
    id: root

    ListModel {
        id: membersSource

        ListElement {
            pubKey: "0xalice"
            preferredDisplayName: "Alice"
        }
        ListElement {
            pubKey: "0xbob"
            preferredDisplayName: "Bob in this chat"
        }
    }

    ListModel {
        id: contactsSource

        ListElement {
            pubKey: "0xbob"
            preferredDisplayName: "Bob"
        }
        ListElement {
            pubKey: "0xcarol"
            preferredDisplayName: "Carol"
        }
    }

    Component {
        id: adaptorComponent

        MentionNamesAdaptor {
            chatUsersModel: membersSource
            contactsModel: contactsSource
        }
    }

    TestCase {
        name: "MentionNamesAdaptor"

        function nameOf(adaptor, pubKey) {
            return SQUtils.ModelUtils.getByKey(adaptor.model, "pubKey", pubKey,
                                               "preferredDisplayName")
        }

        function test_resolvesChatMember() {
            const adaptor = createTemporaryObject(adaptorComponent, root)
            compare(nameOf(adaptor, "0xalice"), "Alice")
        }

        // the reported bug: mentioning somebody who is not in the chat
        function test_resolvesContactOutsideTheChat() {
            const adaptor = createTemporaryObject(adaptorComponent, root)
            compare(nameOf(adaptor, "0xcarol"), "Carol")
        }

        function test_chatMemberWinsOverContact() {
            const adaptor = createTemporaryObject(adaptorComponent, root)
            compare(nameOf(adaptor, "0xbob"), "Bob in this chat")
        }

        function test_unknownKeyUnresolved() {
            const adaptor = createTemporaryObject(adaptorComponent, root)
            compare(nameOf(adaptor, "0xdave"), null)
        }

        function test_missingSource_data() {
            return [
                { tag: "no chat users", props: { chatUsersModel: null },
                  key: "0xcarol", expected: "Carol" },
                { tag: "no contacts", props: { contactsModel: null },
                  key: "0xalice", expected: "Alice" }
            ]
        }

        function test_missingSource(data) {
            const adaptor = createTemporaryObject(adaptorComponent, root, data.props)
            compare(nameOf(adaptor, data.key), data.expected)
        }

        // a popup can open before its store is wired; every key is simply unknown
        // until a source arrives, and resolution starts working once one does
        function test_bothSourcesMissing() {
            const adaptor = createTemporaryObject(adaptorComponent, root,
                                                  { chatUsersModel: null, contactsModel: null })
            compare(nameOf(adaptor, "0xalice"), null)

            adaptor.contactsModel = contactsSource
            compare(nameOf(adaptor, "0xcarol"), "Carol")
            compare(nameOf(adaptor, "0xalice"), null)

            adaptor.chatUsersModel = membersSource
            compare(nameOf(adaptor, "0xalice"), "Alice")
        }

        // being mentioned yourself in a DM used to show your own chat key
        function test_resolvesSelf() {
            const adaptor = createTemporaryObject(adaptorComponent, root, {
                selfPubKey: "0xme", selfDisplayName: "Me"
            })
            compare(nameOf(adaptor, "0xme"), "Me")
        }

        function test_noSelfRowWithoutAKey() {
            const adaptor = createTemporaryObject(adaptorComponent, root)
            compare(nameOf(adaptor, ""), null)
            compare(SQUtils.ModelUtils.modelToArray(adaptor.model, ["pubKey"]).length, 4)
        }

        // a real row for the same key keeps precedence over the appended self row
        function test_selfRowLosesToARealRow() {
            const adaptor = createTemporaryObject(adaptorComponent, root, {
                selfPubKey: "0xalice", selfDisplayName: "Me"
            })
            compare(nameOf(adaptor, "0xalice"), "Alice")
        }

        function test_selfRenamePropagates() {
            const adaptor = createTemporaryObject(adaptorComponent, root, {
                selfPubKey: "0xme", selfDisplayName: "Me"
            })
            compare(nameOf(adaptor, "0xme"), "Me")
            adaptor.selfDisplayName = "Myself"
            compare(nameOf(adaptor, "0xme"), "Myself")
        }

        // MentionResolver rebuilds its cache from the name role changing, so the
        // rename has to reach the adaptor's output
        function test_renamePropagates() {
            const adaptor = createTemporaryObject(adaptorComponent, root)
            compare(nameOf(adaptor, "0xcarol"), "Carol")
            contactsSource.setProperty(1, "preferredDisplayName", "Caroline")
            compare(nameOf(adaptor, "0xcarol"), "Caroline")
            contactsSource.setProperty(1, "preferredDisplayName", "Carol")
        }
    }
}
