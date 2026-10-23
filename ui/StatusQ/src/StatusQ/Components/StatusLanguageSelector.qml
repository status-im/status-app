import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Controls.private
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Models

import SortFilterProxyModel

Button {
    id: root

    // list of language/locale codes, e.g. ["cs_CZ","ko","fr"]
    required property var languageCodes
    required property var activeLanguageCodes

    property bool selectMultiple

    signal languageSelected(string languageCode)
    signal languageToggled(string languageCode, bool checked) // for selectMultiple

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

    text: d.beautifyIsoCodes(activeLanguageCodes)

    QtObject {
        id: d

        readonly property int maxPopupHeight: 400
        readonly property int delegateHeight: 70

        readonly property SortFilterProxyModel languageModel: SortFilterProxyModel {
            id: languageModel
            sourceModel: LanguageModel {
                languageCodes: root.languageCodes
            }
            filters: [
                AnyOf {
                    enabled: searchField.text !== ""
                    SearchFilter {
                        roleName: "code"
                        searchPhrase: searchField.text
                    }
                    SearchFilter {
                        roleName: "name"
                        searchPhrase: searchField.text
                    }
                    SearchFilter {
                        roleName: "nativeName"
                        searchPhrase: searchField.text
                    }
                }
            ]
            sorters: StringSorter {
                roleName: "nativeName"
            }
        }

        function beautifyIsoCode(code) {
            return code.replace('_', '-').toUpperCase()
        }

        function beautifyIsoCodes(codes) {
            return codes.map(code => beautifyIsoCode(code)).join(",")
        }
    }

    background: Rectangle {
        radius: Theme.radius
        color: root.enabled && (root.hovered || dropdown.opened) ? Theme.palette.primaryColor2 : Theme.palette.primaryColor3
        Behavior on color { ColorAnimation { duration: ThemeUtils.AnimationDuration.Fast } }
    }

    contentItem: RowLayout {
        spacing: root.spacing
        StatusIcon {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            icon: "globe"
            color: Theme.palette.primaryColor1
        }
        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Qt.AlignHCenter
            text: root.text
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

        objectName: "statusLanguageSelectorDropdown"

        directParent: root
        relativeX: root.width - width
        relativeY: root.height + 2
        width: 300
        fillHeightOnBottomSheet: true

        margins: Theme.halfPadding
        padding: Theme.padding

        onOpened: if (!Utils.isMobile) searchField.forceActiveFocus()
        onClosed: searchField.input.edit.clear()

        contentItem: ColumnLayout {
            spacing: Theme.halfPadding
            StatusInput {
                id: searchField
                Layout.fillWidth: true
                KeyNavigation.tab: userSelectorPanel
                placeholderText: qsTr("Search")
                input.asset.name: "search"
                input.clearable: true
            }
            StatusListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: contentHeight
                Layout.maximumHeight: dropdown.bottomSheet ? -1 : d.maxPopupHeight

                id: userSelectorPanel
                objectName: "statusLanguageSelectorListView"
                model: d.languageModel
                highlightFollowsCurrentItem: true
                highlight: Rectangle {
                    radius: Theme.radius
                    color: userSelectorPanel.activeFocus ? Theme.palette.primaryColor2 : "transparent"
                }

                delegate: ItemDelegate {
                    id: delegate
                    objectName: "itemDelegate_" + model.code
                    width: ListView.view.width
                    height: d.delegateHeight
                    checked: root.activeLanguageCodes.includes(model.code)
                    checkable: root.selectMultiple
                    background: Rectangle {
                        radius: Theme.radius
                        color: userSelectorPanel.activeFocus ? "transparent" : hovered ? Theme.palette.primaryColor2 : "transparent"
                    }
                    contentItem: RowLayout {
                        ColumnLayout {
                            Layout.fillWidth: true
                            StatusBaseText {
                                Layout.fillWidth: true
                                horizontalAlignment: Qt.AlignLeft // force LTR
                                text: model.nativeName
                                font.capitalization: Font.Capitalize
                                font.pixelSize: root.font.pixelSize
                                font.weight: root.font.weight
                            }
                            StatusBaseText {
                                Layout.fillWidth: true
                                text: "%1 (%2)".arg(model.name).arg(d.beautifyIsoCode(model.code))
                                font: root.font
                                color: Theme.palette.baseColor1
                            }
                        }
                        StatusCheckIndicator {
                            Layout.alignment: Qt.AlignRight
                            checkState: delegate.checked ? Qt.Checked : Qt.Unchecked
                            mirrored: delegate.mirrored
                            hovered: delegate.hovered
                        }
                    }
                    onClicked: {
                        if (!root.selectMultiple) dropdown.close()
                        root.languageSelected(model.code)
                    }
                    onToggled: {
                        root.languageToggled(model.code, checked)
                    }
                    HoverHandler {
                        cursorShape: hovered ? Qt.PointingHandCursor : undefined
                    }
                }
            }

            // Just a filler
            Item {
                Layout.fillHeight: true
            }
        }
    }

    HoverHandler {
        cursorShape: hovered ? Qt.PointingHandCursor : undefined
    }
}
