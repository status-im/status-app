import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import QtQml

import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Core
import StatusQ.Core.Theme

import AppLayouts.Wallet.controls

import utils
import shared.controls

StatusDraggableListItem {
    id: root

    property alias actionComponent: additionalActionsLoader.sourceComponent

    property int showcaseVisibility: Constants.ShowcaseVisibility.NoOne
    property int showcaseMaxVisibility: Constants.ShowcaseVisibility.Everyone

    property bool blurState: false
    property bool contextMenuEnabled: true
    property string tooltipTextWhenContextMenuDisabled

    signal showcaseVisibilityRequested(int value)

    component ShowcaseVisibilityAction: StatusMenuItem {
        id: menuItem
        required property int showcaseVisibility

        objectName: "visibilityAction_" + showcaseVisibility

        ButtonGroup.group: showcaseVisibilityGroup
        icon.name: ProfileUtils.visibilityIcon(showcaseVisibility)
        icon.color: Theme.palette.primaryColor1
        checked: root.showcaseVisibility === showcaseVisibility
        
        enabled: root.showcaseMaxVisibility >= showcaseVisibility
    }

    layer.enabled: root.blurState
    layer.effect: fastBlur

    height: ProfileUtils.defaultDelegateHeight
    topInset: 0
    bottomInset: 0
    changeColorOnDragActive: false
    bgColor: StatusColors.getColor(Theme.palette.statusAppLayout.rightPanelBackgroundColor, 0.7)

    icon.width: 40
    icon.height: 40

    draggable: true
    dragAxis: Drag.XAndYAxis

    actions: [
        Loader {
            id: additionalActionsLoader

            Layout.maximumWidth: root.width *.4
        },
        StatusButton {
            interactive: root.contextMenuEnabled
            tooltip.text: root.tooltipTextWhenContextMenuDisabled
            icon.name: ProfileUtils.visibilityIcon(root.showcaseVisibility)
            horizontalPadding: Theme.halfPadding
            verticalPadding: 3
            Layout.preferredWidth: 72
            Layout.preferredHeight: root.height/2
            radius: height/2
            highlighted: menuLoader.item && menuLoader.item.opened
            onClicked: {
                menuLoader.active = true
                menuLoader.item.popup(width - menuLoader.item.width, height)
            }
            text: "    " // NB to give the icon and indicator some even space

            indicator: StatusIcon {
                anchors.right: parent.right
                anchors.rightMargin: parent.horizontalPadding
                anchors.verticalCenter: parent.verticalCenter
                icon: "chevron-down"
                color: parent.interactive ? Theme.palette.primaryColor1 : Theme.palette.baseColor1
            }

            ButtonGroup {
                id: showcaseVisibilityGroup
                exclusive: true
                onClicked: function(button) {
                    const newVisibility = (button as ShowcaseVisibilityAction).showcaseVisibility
                    if (newVisibility !== root.showcaseVisibility)
                        root.showcaseVisibilityRequested(newVisibility)
                }
            }

            Loader {
                id: menuLoader
                active: false
                sourceComponent: StatusMenu {
                    onClosed: menuLoader.active = false
                    StatusMenuHeadline { text: qsTr("Show to") }

                    ShowcaseVisibilityAction {
                        id: everyoneAction
                        showcaseVisibility: Constants.ShowcaseVisibility.Everyone
                        text: enabled ? qsTr("Everyone") : qsTr("Everyone (set account to Everyone)")
                    }
                    ShowcaseVisibilityAction {
                        id: contactsAction
                        showcaseVisibility: Constants.ShowcaseVisibility.Contacts
                        text: enabled ? qsTr("Contacts") : qsTr("Contacts (set account to Contacts)")
                    }

                    StatusMenuSeparator {}

                    ShowcaseVisibilityAction {
                        showcaseVisibility: Constants.ShowcaseVisibility.NoOne
                        text: qsTr("No one")
                    }
                }
            }
        }
    ]

    Component {
        id: fastBlur

        FastBlur {
            radius: 32
            transparentBorder: true
        }
    }
}
