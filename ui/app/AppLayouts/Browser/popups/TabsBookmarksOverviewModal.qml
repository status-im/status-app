import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups.Dialog

import utils
import shared.controls

import SortFilterProxyModel

StatusDialog {
    id: root

    enum Mode {
        OpenTabs,
        Bookmarks
    }
    property int initialMode: TabsBookmarksOverviewModal.Mode.OpenTabs

    //< [{title: "", url: ""}, {...}]
    required property var tabsModel
    required property int currentTabIndex
    property var getTitleFn: (tabIndex) => {console.error("getTitleFn not implemented"); return ""}
    property var getFaviconFn: (tabIndex) => {console.error("getFaviconFn not implemented"); return ""}
    property var getWebViewScreenshot: (tabIndex, targetImage) => {console.error("getWebViewScreenshot not implemented"); return ""}

    signal activateTabRequested(int tabIndex)
    signal addTabRequested()

    // bookmarks
    required property var bookmarksModel

    signal editBookmarkRequested(string url, string name)
    signal deleteBookmarkRequested(string url)
    signal bookmarkClicked(string url)

    title: mainTabBar.currentIndex === TabsBookmarksOverviewModal.Mode.OpenTabs ? qsTr("Open tabs") : qsTr("Bookmarks")
    destroyOnClose: true
    fillHeightOnBottomSheet: true
    width: 560
    backgroundColor: Theme.palette.baseColor2

    horizontalPadding: 12
    verticalPadding: 0

    QtObject {
        id: d

        // Tabs Overview
        readonly property int cardWidth: 162
        readonly property int cardHeight: 200
        readonly property real cardSpacing: 10
        readonly property int columnCount: root.bottomSheet ? 2 : 3
        readonly property int iconSize: 28

        readonly property var searchableTabsModel: SortFilterProxyModel {
            sourceModel: ListModel {
                Component.onCompleted: {
                    clear()
                    root.tabsModel.forEach(tabItem => { append(tabItem) })
                }
            }
            proxyRoles: [
                FastExpressionRole {
                    name: "title"
                    expression: root.getTitleFn(model.index)
                    expectedRoles: ["index"]
                }
            ]
            filters: SQUtils.SearchFilter {
                roleName: "title"
                searchPhrase: searchField.text
                enabled: searchField.visible
            }
        }

        // Bookmarks
        readonly property var searchableBookmarksModel: SortFilterProxyModel {
            sourceModel: root.bookmarksModel
            filters: [
                SQUtils.SearchFilter {
                    roleName: "name"
                    searchPhrase: searchField.text
                    enabled: searchField.visible
                },
                ValueFilter {
                    roleName: "url"
                    value: Constants.newBookmark
                    inverted: true
                }
            ]
        }
    }

    contentItem: ColumnLayout {
        spacing: Theme.defaultPadding

        SearchBox {
            id: searchField

            Layout.fillWidth: true
            visible: searchButton.checked
            onVisibleChanged: clear()

            placeholderText: mainTabBar.currentIndex === TabsBookmarksOverviewModal.Mode.OpenTabs ? qsTr("Search in open tabs")
                                                                                                  : qsTr("Search in bookmarks")
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            currentIndex: mainTabBar.currentIndex

            StatusGridView {
                Layout.preferredWidth: (d.columnCount * d.cardWidth) + ((d.columnCount - 1) * d.cardSpacing) + Theme.padding // 2 or 3 cards wide + scrollbar
                Layout.maximumWidth: parent.width
                Layout.alignment: Qt.AlignHCenter
                Layout.minimumHeight: 300
                Layout.preferredHeight: Math.min(root.availableHeight, contentHeight)
                Layout.fillHeight: true

                model: d.searchableTabsModel

                cellWidth: d.cardWidth + d.cardSpacing
                cellHeight: d.cardHeight + d.cardSpacing

                ScrollBar.vertical: StatusScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: ItemDelegate {
                    id: openTabDelegate

                    required property int index
                    required property var model

                    highlighted: d.searchableTabsModel.mapToSource(index) === root.currentTabIndex

                    width: d.cardWidth
                    height: d.cardHeight
                    padding: 0
                    spacing: Theme.defaultHalfPadding

                    background: Rectangle {
                        id: openTabDelegateBg
                        radius: Theme.radius
                        color: Theme.palette.cardColor
                        border.color: openTabDelegate.highlighted ? Theme.palette.primaryColor1 : Theme.palette.separator
                        border.width: openTabDelegate.highlighted ? 2 : 1
                    }

                    contentItem: ColumnLayout {
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            Layout.leftMargin: openTabDelegate.spacing
                            Layout.rightMargin: openTabDelegate.spacing
                            spacing: openTabDelegate.spacing

                            StatusRoundedImage {
                                Layout.preferredWidth: d.iconSize
                                Layout.preferredHeight: d.iconSize
                                image.source: root.getFaviconFn(d.searchableTabsModel.mapToSource(index))
                            }
                            StatusBaseText {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                maximumLineCount: 2
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                color: Theme.palette.primaryColor1
                                font.pixelSize: Theme.fontSize(13)
                                font.weight: Font.Medium
                                wrapMode: Text.WordWrap
                                text: model.title
                            }
                        }
                        Image {
                            Layout.preferredWidth: parent.width - openTabDelegateBg.border.width*2
                            Layout.preferredHeight: 150 - openTabDelegateBg.border.width*2
                            Layout.alignment: Qt.AlignHCenter
                            fillMode: Image.PreserveAspectCrop
                            mipmap: true
                            Component.onCompleted: root.getWebViewScreenshot(d.searchableTabsModel.mapToSource(index), this)
                        }
                    }

                    onClicked: {
                        root.activateTabRequested(d.searchableTabsModel.mapToSource(index))
                        root.close()
                    }

                    HoverHandler {
                        cursorShape: hovered ? Qt.PointingHandCursor : undefined
                    }
                }
            }

            StatusListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(root.availableHeight, contentHeight)
                Layout.fillHeight: true
                model: d.searchableBookmarksModel
                delegate: ItemDelegate {
                    id: bookmarkDelegate
                    required property int index
                    required property var model

                    spacing: Theme.padding
                    width: ListView.view.width

                    icon.source: model.imageUrl || Assets.svg("globe")
                    icon.width: d.iconSize
                    icon.height: d.iconSize

                    background: Rectangle {
                        radius: Theme.radius
                        color: bookmarkDelegate.hovered ? Theme.palette.primaryColor3 : StatusColors.transparent
                    }

                    contentItem: RowLayout {
                        spacing: bookmarkDelegate.spacing
                        StatusRoundedImage {
                            Layout.preferredWidth: bookmarkDelegate.icon.width
                            Layout.preferredHeight: bookmarkDelegate.icon.height
                            image.sourceSize: Qt.size(width, height)
                            image.source: bookmarkDelegate.icon.source
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            StatusBaseText {
                                Layout.fillWidth: true
                                text: model.name
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontSize(14)
                            }
                            StatusBaseText {
                                Layout.fillWidth: true
                                text: model.url
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontSize(14)
                                color: Theme.palette.baseColor1
                            }
                        }
                        StatusFlatButton {
                            icon.name: "edit_pencil"
                            type: StatusBaseButton.Type.Primary
                            tooltip.text: qsTr("Edit bookmark")
                            onClicked: {
                                root.editBookmarkRequested(model.url, model.name)
                                root.close()
                            }
                        }
                        StatusFlatButton {
                            icon.name: "delete"
                            type: StatusBaseButton.Type.Danger
                            tooltip.text: qsTr("Delete bookmark")
                            onClicked: root.deleteBookmarkRequested(model.url)
                        }
                    }

                    onClicked: {
                        root.close()
                        root.bookmarkClicked(model.url)
                    }

                    HoverHandler {
                        cursorShape: hovered ? Qt.PointingHandCursor : undefined
                    }
                }
            }
        }
    }

    footer: StatusDialogFooter {
        dropShadowEnabled: true
        leftButtons: ObjectModel {
            StatusSwitchTabBar {
                id: mainTabBar
                currentIndex: root.initialMode
                CustomSwitchButton {
                    icon.name: "open-tabs"

                    StatusBaseText {
                        anchors.centerIn: parent

                        font.pixelSize: Theme.fontSize(12)
                        color: parent.icon.color
                        font.weight: Font.DemiBold
                        text: d.searchableTabsModel.count
                    }
                }
                CustomSwitchButton {
                    icon.name: "bookmark"
                }
            }
        }
        rightButtons: ObjectModel {
            StatusFlatButton {
                id: searchButton
                icon.name: "search"
                icon.width: d.iconSize
                icon.height: d.iconSize
                checkable: true
                tooltip.text: qsTr("Search")
                onToggled: searchField.focus = checked
            }
            StatusFlatButton {
                icon.name: "add"
                icon.width: d.iconSize
                icon.height: d.iconSize
                tooltip.text: qsTr("Add")
                onClicked: {
                    root.addTabRequested()
                    root.close()
                }
            }
        }
    }

    component CustomSwitchButton: StatusSwitchTabButton {
        id: customSwitchButton
        icon.color: checked ? StatusColors.white : Theme.palette.primaryColor1
        contentItem: Item {
            StatusIcon {
                anchors.centerIn: parent
                icon: customSwitchButton.icon.name
                color: customSwitchButton.icon.color
                width: d.iconSize
                height: d.iconSize
            }
        }
    }
}
