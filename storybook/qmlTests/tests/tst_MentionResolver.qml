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
 - a key the model does not know falls back to aliasProvider, so the renderer shows
   a 3-word alias rather than 130 hex characters; with no provider it stays
   unresolved and the renderer falls back to the raw key
 - a key the model cannot name is handed to contactInfoRequester exactly once, and
   never from inside the binding that discovered it (resolveFor() is called from a
   binding, which must not call into the backend mid-evaluation)
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
    readonly property string keyUnknown2: "0x" + "d".repeat(130)

    ListModel {
        id: usersModel

        Component.onCompleted: {
            append({ pubKey: root.keyA, name: "Alice" })
            append({ pubKey: root.keyB, name: "Bob" })
        }
    }

    ListModel {
        id: namelessModel

        Component.onCompleted: append({ pubKey: root.keyA, name: "" })
    }

    Component {
        id: resolverComp

        MentionResolver {
            sourceModel: usersModel
        }
    }

    // counts the provider calls, so a name from the model is seen to cost none
    QtObject {
        id: aliasStub

        property int calls: 0

        function generateAlias(pubKey) {
            calls++
            return "Alias of " + pubKey.substring(0, 6)
        }
    }

    // records what was asked about, and when
    QtObject {
        id: requesterStub

        property var keys: []
        property bool calledSynchronously: false
        property bool resolving: false

        function requestContactInfo(pubKey) {
            if (resolving)
                calledSynchronously = true
            keys = keys.concat([pubKey])
        }

        function reset() {
            keys = []
            calledSynchronously = false
            resolving = false
        }
    }

    Component {
        id: requestingResolverComp

        MentionResolver {
            sourceModel: usersModel
            contactInfoRequester: pubKey => requesterStub.requestContactInfo(pubKey)
        }
    }

    Component {
        id: aliasResolverComp

        MentionResolver {
            sourceModel: usersModel
            aliasProvider: pubKey => aliasStub.generateAlias(pubKey)
        }
    }

    TestCase {
        name: "MentionResolver"

        // the stubs are shared, so every test starts from a clean slate
        function init() {
            aliasStub.calls = 0
            requesterStub.reset()
        }

        // resolveFor() is called from a binding; the request must land after it returns
        function resolveDeferred(r, text) {
            requesterStub.resolving = true
            const m = r.resolveFor(text)
            requesterStub.resolving = false
            return m
        }

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

        // with no provider the renderer still gets nothing and shows the raw key
        function test_unknownKeyStaysUnresolved() {
            const r = createTemporaryObject(resolverComp, root)
            const m = r.resolveFor("hi @" + root.keyUnknown)
            verify(!(root.keyUnknown in m))
        }

        function test_unknownKeyFallsBackToAnAlias() {
            const r = createTemporaryObject(aliasResolverComp, root)
            const m = r.resolveFor("hi @" + root.keyUnknown)
            compare(m[root.keyUnknown], "Alias of 0x" + "c".repeat(4))
        }

        function test_knownKeyIgnoresTheAliasProvider() {
            const r = createTemporaryObject(aliasResolverComp, root)
            compare(r.resolveFor("@" + root.keyA)[root.keyA], "Alice")
            compare(aliasStub.calls, 0, "a name from the model must not cost a backend call")
        }

        // a row with an empty display name is a miss, not a name
        function test_emptyNameFallsBackToAnAlias() {
            const r = createTemporaryObject(aliasResolverComp, root,
                                            { sourceModel: namelessModel })
            compare(r.resolveFor("@" + root.keyA)[root.keyA], "Alias of 0x" + "a".repeat(4))
        }

        // the provider is a function literal, so its binding never re-evaluates when the
        // store behind it arrives; the next pass must ask again
        function test_providerWithoutItsStoreYetIsRetried() {
            let ready = false
            const r = createTemporaryObject(resolverComp, root, {
                aliasProvider: pubKey => ready ? aliasStub.generateAlias(pubKey) : ""
            })
            verify(!(root.keyUnknown in r.resolveFor("@" + root.keyUnknown)))

            ready = true
            compare(r.resolveFor("@" + root.keyUnknown)[root.keyUnknown],
                    "Alias of 0x" + "c".repeat(4))
        }

        function test_aliasProviderWiredUpLate() {
            const r = createTemporaryObject(resolverComp, root)
            verify(!(root.keyUnknown in r.resolveFor("@" + root.keyUnknown)))

            r.aliasProvider = pubKey => aliasStub.generateAlias(pubKey)
            compare(r.resolveFor("@" + root.keyUnknown)[root.keyUnknown],
                    "Alias of 0x" + "c".repeat(4))
        }

        function test_unknownKeyIsRequested() {
            const r = createTemporaryObject(requestingResolverComp, root)
            resolveDeferred(r, "hi @" + root.keyUnknown)

            tryVerify(() => requesterStub.keys.length === 1, 2000,
                      "an unnameable key must be asked about")
            compare(requesterStub.keys[0], root.keyUnknown)
            verify(!requesterStub.calledSynchronously,
                   "the request must not happen during the binding's evaluation")
        }

        // All requests from one resolveFor() are queued in the same event-loop turn, so a
        // key that did arrive is a fence: anything else would have arrived with it.
        function test_knownKeyIsNotRequested() {
            const r = createTemporaryObject(requestingResolverComp, root)
            resolveDeferred(r, "@" + root.keyA + " @0x00001 @" + root.keyUnknown)

            tryVerify(() => requesterStub.keys.length > 0, 2000)
            compare(requesterStub.keys, [root.keyUnknown],
                    "a name from the model, and the everyone tag, cost no round trip")
        }

        function test_keyIsRequestedOnlyOnce() {
            const r = createTemporaryObject(requestingResolverComp, root)
            const text = "@" + root.keyUnknown
            resolveDeferred(r, text)
            tryVerify(() => requesterStub.keys.length > 0, 2000)

            // re-resolving, and a model change that drops the name cache, must not re-ask
            resolveDeferred(r, text)
            usersModel.setProperty(0, "name", "Alicia")
            resolveDeferred(r, text)
            usersModel.setProperty(0, "name", "Alice")

            // a fresh key fences the repeats: it arrives after anything they queued
            resolveDeferred(r, "@" + root.keyUnknown2)
            tryVerify(() => requesterStub.keys.length > 1, 2000)
            compare(requesterStub.keys, [root.keyUnknown, root.keyUnknown2],
                    "one round trip per key per resolver")
        }

        // the point of asking: the answer arrives in the model and the name takes over
        function test_nameArrivingFromARequestWins() {
            const r = createTemporaryObject(requestingResolverComp, root, {
                aliasProvider: pubKey => aliasStub.generateAlias(pubKey)
            })
            compare(r.resolveFor("@" + root.keyUnknown)[root.keyUnknown],
                    "Alias of 0x" + "c".repeat(4))

            usersModel.append({ pubKey: root.keyUnknown, name: "Carol" })
            compare(r.resolveFor("@" + root.keyUnknown)[root.keyUnknown], "Carol")
            usersModel.remove(usersModel.count - 1)
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
