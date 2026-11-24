import QtQuick
import QtTest

import StatusQ

import AppLayouts.stores as AppLayoutStores
import mainui
import shared.stores

// Every type Popups names by URL or by module and type name loads, so a moved
// file or a renamed type fails here instead of at the popup's first opening.
Item {
    id: root

    width: 800
    height: 800

    Component {
        id: popupsComponent

        Popups {
            popupParent: root
            keychain: Keychain {}
            secureStorage: SecureStorage {}
            sharedRootStore: RootStore {}
            rootStore: AppLayoutStores.RootStore {}
            communityTokensStore: CommunityTokensStore {}
            networksStore: NetworksStore {}
        }
    }

    TestCase {
        name: "PopupsDeferredTypes"
        when: windowShown

        function isDeferred(value) {
            return !!value && typeof value.component === "function"
                    && typeof value.adopt === "function"
        }

        function deferredComponents(object) {
            const found = []
            for (const key in object) {
                const value = object[key]
                if (isDeferred(value)) {
                    found.push({ name: key, deferred: value })
                } else if (key === "_deferredComponents") {
                    for (let i = 0; i < value.length; ++i)
                        if (isDeferred(value[i]))
                            found.push({ name: value[i].typeName || value[i].source.toString(),
                                         deferred: value[i] })
                }
            }
            return found
        }

        function test_everyDeferredTypeLoads() {
            ignoreWarning(/AuthenticationStore\.qml:\d+: ReferenceError: mainModule is not defined/)
            ignoreWarning(/SigningStore\.qml:\d+: ReferenceError: mainModule is not defined/)
            ignoreWarning(/KeycardManagementStore\.qml:\d+: ReferenceError: mainModule is not defined/)
            ignoreWarning(/StatusSuccessAction\.qml:\d+:\d+: Duplicate signal name/)
            const popups = createTemporaryObject(popupsComponent, root)
            verify(!!popups)

            const all = deferredComponents(popups)
            verify(all.length > 40, "found only " + all.length)

            for (const entry of all) {
                const component = entry.deferred.component()
                compare(component.status, Component.Ready, entry.name + ": " + component.errorString())
            }
        }
    }
}
