import QtQuick
import QtTest

import Models
import Storybook
import QtModelsToolkit

import AppLayouts.HomePage
import utils

Item {
    id: root
    width: 1400
    height: 800

    Component {
        id: gridComponent

        HomePageGrid {
            width: 1000
            height: 500
            spacing: 8
        }
    }

    Component {
        id: modelComponent
        ListModel {}
    }

    component MockAdaptor: HomePageAdaptor {
        sectionsBaseModel: SectionsModel {}
        chatsBaseModel: ChatsModel {}
        chatsSearchBaseModel: ChatsSearchModel {}
        walletsBaseModel: WalletAccountsModel {}
        dappsBaseModel: DappsModel {}
        syncingBadgeCount: 2
        messagingBadgeCount: 4
        showBackUpSeed: true
        backUpSeedBadgeCount: 1
        keycardEnabled: true
        showPassword: true
        showSignOut: true
        showAllChats: true
        searchPhrase: ""
        profileId: "tst_HomePageGrid_" + Date.now()
    }

    Component {
        id: adaptorComponent
        MockAdaptor {}
    }

    Component {
        id: pageComponent

        HomePage {
            id: page
            width: 1260
            height: 600
            homePageEntriesModel: adaptor.homePageEntriesModel
            sectionsModel: adaptor.sectionsModel
            pinnedModel: adaptor.pinnedModel

            MockAdaptor {
                id: adaptor
                searchPhrase: page.searchPhrase
            }
        }
    }

    TestCase {
        name: "HomePageGrid"
        when: windowShown

        function entry(id) {
            return {
                key: "4;" + id, id: String(id), sectionType: Constants.appSection.profile,
                name: qsTr("Settings %1").arg(id), icon: "settings",
                hasNotification: false, notificationsCount: 0, pinned: false
            }
        }

        function gridView(grid) {
            const view = findChild(grid, "homePageGridView")
            verify(!!view, "Object exists")
            return view
        }

        function verifyLayout(view, count) {
            tryCompare(view, "count", count)
            tryVerify(() => view.delegateCountPerRow > 0)
            waitForRendering(view)
            tryCompare(view, "height", Math.ceil(count / view.delegateCountPerRow) * view.cellHeight)
            for (let i = 0; i < count; ++i) {
                let loader = null
                tryVerify(() => {
                    loader = view.itemAtIndex(i)
                    return !!loader && loader.status === Loader.Ready
                })
                const x = (i % view.delegateCountPerRow) * view.cellWidth
                const y = Math.floor(i / view.delegateCountPerRow) * view.cellHeight
                tryVerify(() => {
                    const pos = loader.mapToItem(view, 0, 0)
                    return Math.abs(pos.x - x) < 0.01 && Math.abs(pos.y - y) < 0.01
                })
                compare(loader.item.width, 160)
                compare(loader.item.height, 160)
            }
        }

        function test_storybook_initial_population() {
            const adaptor = createTemporaryObject(adaptorComponent, root)
            verify(!!adaptor, "Component exists")
            const grid = createTemporaryObject(gridComponent, root, {
                model: adaptor.homePageEntriesModel
            })
            verify(!!grid, "Component exists")
            const view = gridView(grid)
            tryVerify(() => view.count > 30)
            verifyLayout(view, adaptor.homePageEntriesModel.ModelCount.count)
        }

        function test_storybook_page_initial_population_data() {
            return [
                { tag: "five columns", width: 1000 },
                { tag: "seven columns", width: 1260 }
            ]
        }

        function test_storybook_page_initial_population(data) {
            // Create the adaptor inside the page: pre-populating it misses startup displacement.
            const page = createTemporaryObject(pageComponent, root, { width: data.width })
            verify(!!page, "Component exists")
            const view = gridView(page)
            verifyLayout(view, 42)
            const grid = findChild(page, "homeGrid")
            verify(!!grid, "Object exists")
            compare(grid.contentItem.contentHeight, view.height)
        }

        function test_search_and_restore() {
            const page = createTemporaryObject(pageComponent, root)
            verify(!!page, "Component exists")
            const view = gridView(page)
            verifyLayout(view, 42)
            const searchField = findChild(page, "homeSearchField")
            verify(!!searchField, "Object exists")

            searchField.text = "zzzzzz"
            tryCompare(view, "count", 0)
            tryCompare(view, "height", 0)

            searchField.text = "appearance"
            verifyLayout(view, 1)

            searchField.clear()
            verifyLayout(view, 42)
        }

        function test_delayed_insertions_and_removals() {
            const model = createTemporaryObject(modelComponent, root)
            verify(!!model, "Component exists")
            const grid = createTemporaryObject(gridComponent, root, { model: model })
            verify(!!grid, "Component exists")
            const view = gridView(grid)

            for (let i = 0; i < 12; ++i)
                model.append(entry(i))
            verifyLayout(view, 12)

            for (let i = 12; i < 24; ++i)
                model.insert(0, entry(i))
            verifyLayout(view, 24)

            model.remove(0, 7)
            verifyLayout(view, 17)

            model.move(0, 10, 3)
            verifyLayout(view, 17)

            grid.width = 700
            verifyLayout(view, 17)

            grid.width = 1260
            verifyLayout(view, 17)

            const scroll = grid.contentItem
            scroll.contentY = scroll.contentHeight - scroll.height
            const last = view.itemAtIndex(16)
            verify(!!last, "Object exists")
            tryVerify(() => {
                const bottom = last.mapToItem(grid, 0, last.item.height).y
                return Math.abs(bottom - (grid.height - grid.spacing)) < 0.01
            })

            model.clear()
            tryCompare(view, "count", 0)
            tryCompare(view, "height", 0)
            model.append(entry(0))
            verifyLayout(view, 1)
            tryCompare(scroll, "contentY", 0)
        }
    }
}
