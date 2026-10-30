import QtQuick
import QtQml.Models

import AppLayouts.Browser.stores

// Storybook sample data. The BookmarksStore stub stays empty.
BookmarksStore {
    bookmarksModel: ListModel {
        ListElement {
            name: "Status Hub"
            url: "https://hub.status.network/"
        }
        ListElement {
            name: "Status App"
            url: "https://status.app/"
        }
        ListElement {
            name: "Seznam"
            url: "https://www.seznam.cz/"
        }
    }
}
