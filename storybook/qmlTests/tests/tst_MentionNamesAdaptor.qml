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
 - only contacts with a name of their own (or added ones) resolve: an alias-only
   contacts-cache entry would hide the name the message carries
   (MentionResolver's knownNames)
*/
Item {
    id: root

    ListModel {
        id: membersSource

        ListElement {
            pubKey: "0xalice"
            preferredDisplayName: "Alice"
            usesDefaultName: false
            isContact: false
        }
        ListElement {
            pubKey: "0xbob"
            preferredDisplayName: "Bob in this chat"
            usesDefaultName: false
            isContact: false
        }
        ListElement {
            pubKey: "0xfrank"
            preferredDisplayName: "Frank's Alias"
            usesDefaultName: true
            isContact: false
        }
    }

    ListModel {
        id: contactsSource

        ListElement {
            pubKey: "0xbob"
            preferredDisplayName: "Bob"
            usesDefaultName: false
            isContact: true
        }
        ListElement {
            pubKey: "0xcarol"
            preferredDisplayName: "Carol"
            usesDefaultName: false
            isContact: true
        }
        ListElement {
            pubKey: "0xdave"
            preferredDisplayName: "Dave's Alias"
            usesDefaultName: true
            isContact: false
        }
        ListElement {
            pubKey: "0xerin"
            preferredDisplayName: "Erin's Alias"
            usesDefaultName: true
            isContact: true
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

        function test_rowCount() {
            const adaptor = createTemporaryObject(adaptorComponent, root)
            compare(SQUtils.ModelUtils.modelToArray(adaptor.model, ["pubKey"]).length, 6)
        }

        // a contacts-cache entry with only an alias (e.g. a contact request stranger)
        function test_aliasOnlyContactDoesNotResolve() {
            const adaptor = createTemporaryObject(adaptorComponent, root)
            compare(nameOf(adaptor, "0xdave"), null)
        }

        // the chat's own rows are not narrowed: an alias there is what the roster knows
        function test_aliasOnlyChatMemberResolves() {
            const adaptor = createTemporaryObject(adaptorComponent, root)
            compare(nameOf(adaptor, "0xfrank"), "Frank's Alias")
        }

        // an added contact counts as a name of its own, like the Nim renderer
        function test_addedContactWithoutANameResolves() {
            const adaptor = createTemporaryObject(adaptorComponent, root)
            compare(nameOf(adaptor, "0xerin"), "Erin's Alias")
        }

        // a contact naming themselves starts resolving
        function test_contactGainingANameResolves() {
            const adaptor = createTemporaryObject(adaptorComponent, root)
            contactsSource.setProperty(2, "preferredDisplayName", "Dave")
            contactsSource.setProperty(2, "usesDefaultName", false)
            compare(nameOf(adaptor, "0xdave"), "Dave")
            contactsSource.setProperty(2, "preferredDisplayName", "Dave's Alias")
            contactsSource.setProperty(2, "usesDefaultName", true)
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
