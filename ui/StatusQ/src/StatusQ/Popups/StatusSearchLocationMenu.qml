pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import QtQuick.Controls

import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Core.Utils as StatusQUtils

import SortFilterProxyModel

StatusMenu {
    id: root

    property var locationModel
    readonly property int numDefaultItems: 2

    signal itemClicked(string firstLevelItemValue, string secondLevelItemValue)

    signal resetSearchSelection()

    signal setSearchSelection(string text,
                              string secondaryText,
                              string imageSource,
                              bool isIdenticon,
                              string iconName,
                              string iconColor,
                              bool isUserIcon,
                              int colorId)

    StatusAction {
        text: qsTr("Anywhere")
        onTriggered: {
            root.resetSearchSelection();
            root.itemClicked("", "");
        }
    }

    StatusMenuSeparator { }

    StatusMenuInstantiator {
        model: root.locationModel
        menu: root

        delegate: DelegateChooser {
            role: "hasSubItems"

            DelegateChoice {
                roleValue: false
                delegate: StatusSearchPopupMenuItem {
                    text: model.title
                    assetSettings.name: !!model.imageSource ? !!model.imageSource : model.iconName
                    assetSettings.isImage: !!model.imageSource
                    assetSettings.isLetterIdenticon: !model.imageSource && !model.iconName
                    assetSettings.imgIsIdenticon: false
                    onTriggered: {
                        root.resetSearchSelection()
                        root.setSearchSelection(text,
                                                "",
                                                "",
                                                assetSettings.imgIsIdenticon,
                                                assetSettings.name,
                                                assetSettings.color,
                                                model.isUserIcon,
                                                model.colorId)
                        root.itemClicked(model.value, "")
                    }
                }
            }

            DelegateChoice {
                roleValue: true
                delegate: StatusMenu {
                    id: subMenuDelegate

                    readonly property var subItemsModel: model.subItems
                    readonly property string parentValue: model.value
                    readonly property string parentIconName: model.iconName
                    readonly property string parentImageSource: model.imageSource
                    readonly property string parentIdenticonColor: !!model.iconColor ? model.iconColor : defaultIconColor
                    readonly property bool parentIsIdenticon: false

                    title: model.title
                    assetSettings.name: !!model.iconName ? model.iconName : model.imageSource
                    assetSettings.color: !!model.iconColor ? model.iconColor : defaultIconColor
                    assetSettings.isImage: !!model.imageSource
                    assetSettings.imgIsIdenticon: false
                    assetSettings.isLetterIdenticon: !model.imageSource && !model.iconName

                    StatusMenuInstantiator {
                        id: menuLoader

                        readonly property string parentValue: subMenuDelegate.parentValue
                        readonly property string parentTitleText: subMenuDelegate.title
                        readonly property string parentIconName: subMenuDelegate.parentIconName
                        readonly property string parentImageSource: subMenuDelegate.parentImageSource
                        readonly property string parentIdenticonColor: subMenuDelegate.parentIdenticonColor
                        readonly property bool parentIsIdenticon: subMenuDelegate.parentIsIdenticon

                        menu: subMenuDelegate
                        model: SortFilterProxyModel {
                            sourceModel: subMenuDelegate.subItemsModel
                            sorters: [
                                RoleSorter {
                                    roleName: "position"
                                    sortOrder: Qt.AscendingOrder
                                },
                                RoleSorter {
                                    roleName: "lastMessageTimestamp"
                                    sortOrder: Qt.DescendingOrder
                                }
                            ]
                        }

                        delegate: StatusSearchPopupMenuItem {
                            value: model.value
                            text: model.text

                            assetSettings.name: model.isImage ? model.imageSource : ""
                            assetSettings.emoji: !model.isUserIcon ? model.imageSource : ""
                            assetSettings.color: model.isUserIcon ? Theme.palette.userCustomizationColors[model.colorId] : model.iconColor
                            assetSettings.bgColor: model.iconColor
                            assetSettings.charactersLen: model.isUserIcon ? 2 : 1

                            onTriggered: {
                                root.resetSearchSelection()
                                if (menuLoader.parentTitleText === "Chat") {
                                    root.setSearchSelection(model.text,
                                                            "",
                                                            model.imageSource,
                                                            false,
                                                            model.iconName,
                                                            model.iconColor,
                                                            model.isUserIcon,
                                                            model.colorId)
                                } else {
                                    root.setSearchSelection(menuLoader.parentTitleText,
                                                            model.text,
                                                            menuLoader.parentImageSource,
                                                            menuLoader.parentIsIdenticon,
                                                            menuLoader.parentIconName,
                                                            menuLoader.parentIdenticonColor,
                                                            "",
                                                            -1)
                                }
                                root.itemClicked(subMenuDelegate.parentValue, value)
                                root.dismiss()
                            }
                        }
                    }
                }
            }
        }
    }
}
