import QtQuick
import QtTest

import shared.status

/*
 Configuration analysis for MentionResolver
 ==========================================
 Wire format (markdownparser.cpp): a mention is "@0x" + exactly 130 lowercase
 hex chars (uncompressed key) or "@0x" + 5 digits with a non-zero last digit
 (system tag; only 0x00001 = everyone exists).

 The resolver's product contract:
 - a message's mentions resolve to display names from the source model
 - the "everyone" system tag always resolves
 - unknown keys stay unresolved (renderer falls back to the raw key)
 - display-name changes in the model are reflected (revision tracking)
 - while `enabled` is false results are frozen; re-enabling catches up
 - resolution cost scales with the mentions IN THE TEXT, not with the size
   of the contacts model: no-mention messages (the common case) must not
   iterate the model at all — hence resolveFor(text) instead of an eagerly
   built full map (which also crossed to C++ as a 1000-entry QVariantMap per
   toBlocks/plainText call)
*/
Item {
    id: root

    readonly property string keyA: "0x" + "a".repeat(130)
    readonly property string keyB: "0x" + "b".repeat(130)
    readonly property string keyUnknown: "0x" + "c".repeat(130)

    ListModel {
        id: usersModel

        Component.onCompleted: {
            append({ pubKey: root.keyA, name: "Alice" })
            append({ pubKey: root.keyB, name: "Bob" })
        }
    }

    Component {
        id: resolverComp

        MentionResolver {
            sourceModel: usersModel
        }
    }

    TestCase {
        name: "MentionResolver"

        function test_noMentions() {
            const r = createTemporaryObject(resolverComp, root)
            compare(JSON.stringify(r.resolveFor("plain text, no mentions")), "{}")
            compare(JSON.stringify(r.resolveFor("")), "{}")
        }

        function test_resolvesKnownMention() {
            const r = createTemporaryObject(resolverComp, root)
            const m = r.resolveFor("hello @" + root.keyA + " !")
            compare(m[root.keyA], "Alice")
            compare(Object.keys(m).length, 1)
        }

        function test_multipleAndDuplicateMentions() {
            const r = createTemporaryObject(resolverComp, root)
            const m = r.resolveFor("@" + root.keyA + " and @" + root.keyB + " and again @" + root.keyA)
            compare(m[root.keyA], "Alice")
            compare(m[root.keyB], "Bob")
            compare(Object.keys(m).length, 2)
        }

        function test_unknownKeyStaysUnresolved() {
            const r = createTemporaryObject(resolverComp, root)
            const m = r.resolveFor("hi @" + root.keyUnknown)
            verify(!(root.keyUnknown in m))
        }

        function test_everyoneTag() {
            const r = createTemporaryObject(resolverComp, root)
            const m = r.resolveFor("hey @0x00001 !")
            compare(m["0x00001"], "everyone")
        }

        function test_renameReflected() {
            const r = createTemporaryObject(resolverComp, root)
            compare(r.resolveFor("@" + root.keyA)[root.keyA], "Alice")
            usersModel.setProperty(0, "name", "Alicia")
            compare(r.resolveFor("@" + root.keyA)[root.keyA], "Alicia")
            usersModel.setProperty(0, "name", "Alice")
        }

        function test_frozenWhileDisabled() {
            const r = createTemporaryObject(resolverComp, root)
            compare(r.resolveFor("@" + root.keyA)[root.keyA], "Alice")

            r.enabled = false
            usersModel.setProperty(0, "name", "Alicia")
            compare(r.resolveFor("@" + root.keyA)[root.keyA], "Alice",
                    "results are frozen while disabled")

            r.enabled = true
            compare(r.resolveFor("@" + root.keyA)[root.keyA], "Alicia",
                    "re-enabling catches up with model changes")
            usersModel.setProperty(0, "name", "Alice")
        }

        // the ChatMessagesView usage: a binding over resolveFor must re-evaluate
        // when a display name changes
        function test_bindingReactivity() {
            const r = createTemporaryObject(resolverComp, root)
            const holder = Qt.createQmlObject(
                "import QtQml; QtObject { property var resolver; property var names: resolver ? resolver.resolveFor('@" + root.keyA + "') : ({}) }",
                root)
            holder.resolver = r
            compare(holder.names[root.keyA], "Alice")
            usersModel.setProperty(0, "name", "Alicia")
            tryVerify(() => holder.names[root.keyA] === "Alicia", 2000,
                      "binding over resolveFor must re-evaluate on rename")
            usersModel.setProperty(0, "name", "Alice")
            holder.destroy()
        }
    }
}
