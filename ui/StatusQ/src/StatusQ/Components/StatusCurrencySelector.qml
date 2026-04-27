import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme

import SortFilterProxyModel
import QtModelsToolkit

Button {
    id: root

    required property string currentCurrency
    required property var currenciesModel

    signal currencySelected(string shortName)

    function close() {
        dropdown.close()
    }

    font.family: Fonts.baseFont.family
    font.weight: Font.Medium
    font.pixelSize: Theme.additionalTextSize

    horizontalPadding: Theme.smallPadding
    verticalPadding: Theme.halfPadding
    spacing: 4

    opacity: enabled ? 1.0 : ThemeUtils.disabledOpacity

    icon.source: d.currentEntry?.imageSource ?? ""

    QtObject {
        id: d

        readonly property string selectedCurrency: root.currentCurrency || "USD"

        readonly property int maxPopupHeight: 400
        readonly property int delegateHeight: 70

        readonly property var currentEntry: itemData?.item ?? null
        readonly property var itemData: ModelEntry {
            id: itemData
            sourceModel: root.currenciesModel
            key: "shortName"
            value: d.selectedCurrency
        }

        readonly property SortFilterProxyModel searchableModel: SortFilterProxyModel {
            sourceModel: root.currenciesModel
            filters: [
                AnyOf {
                    enabled: searchField.text !== ""
                    SearchFilter {
                        roleName: "name"
                        searchPhrase: searchField.text
                    }
                    SearchFilter {
                        roleName: "shortName"
                        searchPhrase: searchField.text
                    }
                }
            ]
            sorters: StringSorter {
                roleName: "name"
            }
        }
    }

    background: Rectangle {
        radius: Theme.radius
        color: root.enabled && (root.hovered || dropdown.opened) ? Theme.palette.primaryColor2 : Theme.palette.primaryColor3
        Behavior on color { ColorAnimation { duration: ThemeUtils.AnimationDuration.Fast } }
    }

    contentItem: RowLayout {
        spacing: root.spacing
        StatusImage {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            source: root.icon.source
        }
        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Qt.AlignHCenter
            text: d.currentEntry?.shortName ?? "???"
            color: Theme.palette.primaryColor1
            font: root.font
        }
        StatusIcon {
            icon: "chevron-down"
            color: Theme.palette.primaryColor1
        }
    }

    onClicked: dropdown.opened ? dropdown.close() : dropdown.open()

    StatusDropdown {
        id: dropdown

        objectName: "statusCurrencySelectorDropdown"

        directParent: root
        relativeX: root.width - width
        relativeY: root.height + 2
        width: 300
        fillHeightOnBottomSheet: true

        margins: Theme.halfPadding
        padding: Theme.padding

        onOpened: {
            if (!Utils.isMobile)
                searchField.forceActiveFocus()
            currencySelectorPanel.positionViewAtIndex(d.searchableModel.mapFromSource(d.itemData?.row ?? 0), ListView.Visible)
        }
        onClosed: searchField.input.edit.clear()

        contentItem: ColumnLayout {
            spacing: Theme.halfPadding
            StatusInput {
                id: searchField
                Layout.fillWidth: true
                placeholderText: qsTr("Search")
                input.asset.name: "search"
                input.clearable: true
                KeyNavigation.tab: currencySelectorPanel
            }
            StatusListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: contentHeight
                Layout.maximumHeight: dropdown.bottomSheet ? -1 : d.maxPopupHeight

                id: currencySelectorPanel
                model: d.searchableModel
                highlightFollowsCurrentItem: true
                highlight: Rectangle {
                    radius: Theme.radius
                    color: currencySelectorPanel.activeFocus ? Theme.palette.primaryColor2 : "transparent"
                }

                delegate: ItemDelegate {
                    objectName: "itemDelegate_" + model.shortName
                    width: ListView.view.width
                    height: d.delegateHeight
                    checked: model.shortName === d.selectedCurrency
                    background: Rectangle {
                        radius: Theme.radius
                        color: currencySelectorPanel.activeFocus ? "transparent" : hovered ? Theme.palette.primaryColor2 : "transparent"
                    }
                    contentItem: RowLayout {
                        ColumnLayout {
                            Layout.fillWidth: true
                            RowLayout {
                                Layout.fillWidth: true
                                StatusImage {
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    source: model.imageSource
                                }
                                StatusBaseText {
                                    Layout.fillWidth: true
                                    text: model.name
                                    font.pixelSize: root.font.pixelSize
                                    font.weight: root.font.weight
                                }
                            }
                            StatusBaseText {
                                Layout.fillWidth: true
                                text: model.symbol ? "%1 (%2)".arg(model.shortName).arg(model.symbol) : model.shortName
                                font.pixelSize: root.font.pixelSize
                                color: Theme.palette.baseColor1
                            }
                        }
                        StatusIcon {
                            Layout.preferredHeight: 20
                            Layout.alignment: Qt.AlignRight
                            visible: checked
                            icon: "tiny/checkmark"
                            color: Theme.palette.primaryColor1
                        }
                    }
                    onClicked: {
                        dropdown.close()
                        root.currencySelected(model.shortName)
                    }
                    HoverHandler {
                        cursorShape: hovered ? Qt.PointingHandCursor : undefined
                    }
                }
            }
        }
    }

    HoverHandler {
        cursorShape: hovered ? Qt.PointingHandCursor : undefined
    }
}
