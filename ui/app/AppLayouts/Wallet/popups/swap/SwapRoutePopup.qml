import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import utils

/** How the provider should rank the routes it returns. The value is one of
    Constants.swap.routeOrder*, passed straight through to the router. **/
StatusDialog {
    id: root

    /** currently applied order; see Constants.swap.routeOrder* **/
    required property string routeOrder

    signal routeOrderSelected(string routeOrder)

    objectName: "swapRoutePopup"

    title: qsTr("Swap route")
    implicitWidth: 480
    standardButtons: Dialog.NoButton

    readonly property var _options: [
        {
            order: Constants.swap.routeOrderBestReturn,
            name: qsTr("Best return"),
            description: qsTr("Best received amount")
        },
        {
            order: Constants.swap.routeOrderFastest,
            name: qsTr("Fastest"),
            description: qsTr("Shortest execution time")
        },
        {
            order: Constants.swap.routeOrderLowestFee,
            name: qsTr("Lowest fee"),
            description: qsTr("Lowest network cost")
        }
    ]

    contentItem: ColumnLayout {
        spacing: 0

        Repeater {
            model: root._options

            delegate: ItemDelegate {
                id: optionDelegate

                required property var modelData

                objectName: "routeOrderOption_" + modelData.order

                readonly property bool selected: modelData.order === root.routeOrder

                Layout.fillWidth: true

                horizontalPadding: Theme.padding
                verticalPadding: Theme.halfPadding

                background: Rectangle {
                    radius: Theme.radius
                    color: optionDelegate.hovered || optionDelegate.selected
                           ? Theme.palette.baseColor2 : "transparent"

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                contentItem: RowLayout {
                    spacing: Theme.padding

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StatusBaseText {
                            objectName: "routeOrderName"
                            Layout.fillWidth: true
                            text: optionDelegate.modelData.name
                            font.pixelSize: Theme.primaryTextFontSize
                            font.weight: Font.Medium
                            color: Theme.palette.directColor1
                            elide: Text.ElideRight
                        }

                        StatusBaseText {
                            Layout.fillWidth: true
                            text: optionDelegate.modelData.description
                            font.pixelSize: Theme.additionalTextSize
                            color: Theme.palette.directColor5
                            elide: Text.ElideRight
                        }
                    }

                    StatusIcon {
                        Layout.alignment: Qt.AlignVCenter
                        width: 20
                        height: 20
                        icon: "checkmark"
                        color: Theme.palette.primaryColor1
                        visible: optionDelegate.selected
                    }
                }

                onClicked: {
                    root.routeOrderSelected(optionDelegate.modelData.order)
                    root.close()
                }
            }
        }
    }
}
