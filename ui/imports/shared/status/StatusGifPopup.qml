import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Backpressure
import StatusQ.Core.Utils as SQUtils

import utils
import shared.panels
import shared.stores
import shared.controls

import "./StatusGifPopup"

StatusDropdown {
    id: root

    property bool gifUnfurlingEnabled
    property bool thirdpartyServicesEnabled

    property var searchGif: Backpressure.debounce(searchBox, 500, function (query) {
        root.searchGifsRequest(query)
    })
    property var toggleCategory: function(newCategory) {
        previousCategory = currentCategory
        currentCategory = newCategory
        searchBox.text = ""
        if (currentCategory === GifPopupDefinitions.Category.Trending) {
            root.getTrendingsGifs()
        } else if(currentCategory === GifPopupDefinitions.Category.Favorite) {
            root.getFavoritesGifs()
        } else if(currentCategory === GifPopupDefinitions.Category.Recent) {
            root.getRecentsGifs()
        }
    }
    property var toggleFavorite: function(item) {
        root.toggleFavoriteGif(item.id, currentCategory === GifPopupDefinitions.Category.Favorite)
    }
    property alias searchString: searchBox.text
    property int currentCategory: GifPopupDefinitions.Category.Trending
    property int previousCategory: GifPopupDefinitions.Category.Trending

    property bool loading: false
    property var gifColumnA: null
    property var gifColumnB: null
    property var gifColumnC: null

    property var isFavorite: function () {}
    property var addToRecentsGif: function () {}
    property var searchGifsRequest: function () {}
    property var getTrendingsGifs: function () {}
    property var getFavoritesGifs: function () {}
    property var getRecentsGifs: function () {}
    property var toggleFavoriteGif: function () {}
    property var setGifUnfurlingEnabled: function () {}

    signal gifSelected(string url)
    signal enableThirdpartyServicesRequested

    width: 360

    background: Rectangle {
        radius: Theme.radius
        color: Theme.palette.background
        border.color: Theme.palette.border
        layer.enabled: true
        layer.effect: DropShadow {
            verticalOffset: 3
            radius: 8
            samples: 15
            cached: true
            color: "#22000000"
        }
    }

    onAboutToShow: {
        searchBox.text = ""
        if (!SQUtils.Utils.isMobile)
            searchBox.input.edit.forceActiveFocus()
        if (root.gifUnfurlingEnabled) {
            root.getTrendingsGifs()
        }
    }

    onClosed: {
        root.currentCategory = GifPopupDefinitions.Category.Trending
        root.previousCategory = GifPopupDefinitions.Category.Trending

        if (confirmationPopupLoader.active) {
            confirmationPopupLoader.active = false
        }
    }

    padding: 0

    QtObject {
        id: d

        readonly property int headerMargin: root.Theme.halfPadding
    }

    contentItem: Item {
        implicitWidth: parent.width
        implicitHeight: childrenRect.height

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            SearchBox {
                id: searchBox

                visible: root.thirdpartyServicesEnabled
                placeholderText: qsTr("Search")
                enabled: root.gifUnfurlingEnabled

                Layout.fillWidth: true
                Layout.topMargin: d.headerMargin
                Layout.rightMargin: d.headerMargin
                Layout.leftMargin: d.headerMargin

                input.edit.onTextChanged: {
                    if (searchBox.text === "") {
                        toggleCategory(GifPopupDefinitions.Category.Trending)
                        return
                    }
                    if (root.currentCategory !== GifPopupDefinitions.Category.Search) {
                        root.previousCategory = root.currentCategory
                        root.currentCategory = GifPopupDefinitions.Category.Search
                    }
                    Qt.callLater(searchGif, searchBox.text)
                }
            }

            StatusBaseText {
                id: headerText

                text: {
                    if (currentCategory === GifPopupDefinitions.Category.Trending) {
                        return qsTr("TRENDING")
                    } else if(currentCategory === GifPopupDefinitions.Category.Favorite) {
                        return qsTr("FAVORITES")
                    } else if(currentCategory === GifPopupDefinitions.Category.Recent) {
                        return qsTr("RECENT")
                    }
                    return ""
                }
                visible: root.thirdpartyServicesEnabled && searchBox.text === ""
                color: Theme.palette.secondaryText
                font.pixelSize: Theme.additionalTextSize
                topPadding: d.headerMargin
                leftPadding: d.headerMargin
            }

            Loader {
                id: gifsLoader

                active: root.thirdpartyServicesEnabled && root.opened && root.gifUnfurlingEnabled
                visible: active
                Layout.fillWidth: true
                Layout.fillHeight: true

                sourceComponent: root.gifColumnA.rowCount() === 0 ?
                                     emptyPlaceholderComponent : gifItemsComponent
            }

            Row {
                id: categorySelector

                Layout.fillWidth: true

                visible: root.thirdpartyServicesEnabled
                leftPadding: Theme.smallPadding / 2
                rightPadding: Theme.smallPadding / 2
                spacing: 0

                StatusTabBarIconButton {
                    icon.name: "flash"
                    highlighted: GifPopupDefinitions.Category.Trending === root.currentCategory
                    onClicked: {
                        toggleCategory(GifPopupDefinitions.Category.Trending)
                    }
                    enabled: root.gifUnfurlingEnabled
                }

                StatusTabBarIconButton {
                    icon.name: "time"
                    highlighted: GifPopupDefinitions.Category.Recent === root.currentCategory
                    onClicked: {
                        toggleCategory(GifPopupDefinitions.Category.Recent)
                    }
                    enabled: root.gifUnfurlingEnabled
                }

                StatusTabBarIconButton {
                    icon.name: "favourite"
                    highlighted: GifPopupDefinitions.Category.Favorite === root.currentCategory
                    onClicked: {
                        toggleCategory(GifPopupDefinitions.Category.Favorite)
                    }
                    enabled: root.gifUnfurlingEnabled
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                visible: !root.thirdpartyServicesEnabled
                spacing: Theme.padding

                StatusBaseText {
                    Layout.fillWidth: true

                    wrapMode: Text.Wrap
                    text: qsTr("Enable third-party services for gifs feature to work.")
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.palette.dangerColor1
                }

                StatusButton {
                    Layout.alignment: Qt.AlignHCenter

                    type: StatusBaseButton.Type.Primary
                    normalColor: Theme.palette.privacyColors.primary
                    textColor: Theme.palette.privacyColors.tertiary

                    text: qsTr("Enable third-party services")

                    onClicked: root.enableThirdpartyServicesRequested()
                }
            }
        }

        Rectangle {
            color: 'black'
            opacity: 0.4
            radius: Theme.radius
            anchors.fill: parent
            visible: confirmationPopupLoader.active
        }

        Loader {
            id: confirmationPopupLoader

            anchors.centerIn: parent

            sourceComponent: ConfirmationPopup {
                visible: true

                onEnableGifsRequested: {
                    root.setGifUnfurlingEnabled(true)
                    root.getTrendingsGifs()
                }
            }
            active: !root.gifUnfurlingEnabled
        }
    }

    Component {
        id: gifItemsComponent

        StatusScrollView {
            id: scrollView
            contentWidth: availableWidth

            Row {
                id: gifs
                width: scrollView.availableWidth
                spacing: Theme.halfPadding

                property string lastHoveredId

                StatusGifColumn {
                    gifList.model: root.gifColumnA
                    gifWidth: (root.width / 3) - Theme.padding
                    lastHoveredId: gifs.lastHoveredId

                    toggleFavorite: root.toggleFavorite
                    isFavorite: root.isFavorite
                    addToRecentsGif: root.addToRecentsGif

                    onGifHovered: {
                        gifs.lastHoveredId = id
                    }
                    onGifSelected: url => root.gifSelected(url)
                }

                StatusGifColumn {
                    gifList.model: root.gifColumnB
                    gifWidth: (root.width / 3) - Theme.padding
                    lastHoveredId: gifs.lastHoveredId

                    toggleFavorite: root.toggleFavorite
                    isFavorite: root.isFavorite
                    addToRecentsGif: root.addToRecentsGif

                    onGifHovered: {
                        gifs.lastHoveredId = id
                    }
                    onGifSelected: url => root.gifSelected(url)
                }

                StatusGifColumn {
                    gifList.model: root.gifColumnC
                    gifWidth: (root.width / 3) - Theme.padding
                    lastHoveredId: gifs.lastHoveredId

                    toggleFavorite: root.toggleFavorite
                    isFavorite: root.isFavorite
                    addToRecentsGif: root.addToRecentsGif

                    onGifHovered: {
                        gifs.lastHoveredId = id
                    }
                    onGifSelected: url => root.gifSelected(url)
                }
            }
        }
    }

    Component {
        id: emptyPlaceholderComponent

        EmptyPlaceholder {
            Layout.margins: Theme.smallPadding
            currentCategory: root.currentCategory
            loading: root.loading
            onDoRetry: searchBox.text === ""
                        ? root.getTrendingsGifs()
                        : searchGif(searchBox.text)
        }
    }
}
