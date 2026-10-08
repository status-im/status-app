import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups
import StatusQ.Components

Item {

    ColumnLayout {
        id: layout
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: 20

        RowLayout {
            Layout.fillWidth: true

            StatusCard {
                id: card
                Layout.alignment: Qt.AlignVCenter
                primaryText: "Mainnet"
                secondaryText: state === "unavailable" ? "No Gas" : "75,0000000"
                tertiaryText: state === "unpreferred"  ? "UNPREFERRED" : "BALANCE: " + 250
                cardIconName: "status"
                advancedInputText: "75,0000000"
                disabledText: "Disabled"
                onLockCard: locked = !lock
                disableText: "Disable"
                enableText: "Enable"
            }

            StatusComboBox {
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: 200
                label: "Card State"
                onCurrentValueChanged: card.state = currentValue
                model: ListModel {
                    ListElement {
                        name: "default"
                    }
                    ListElement {
                        name: "unavailable"
                    }
                    ListElement {
                        name: "error"
                    }
                    ListElement {
                        name: "unpreferred"
                    }
                }
            }

            StatusCheckBox {
                Layout.alignment: Qt.AlignVCenter
                text: "advancedMode"
                font.family: Fonts.monoFont.family
                font.features: Fonts.monoFont.features
                onClicked: {
                    card.advancedMode = checked
                }
            }


            StatusCheckBox {
                Layout.alignment: Qt.AlignVCenter
                text: "loading"
                font.family: Fonts.monoFont.family
                font.features: Fonts.monoFont.features
                onClicked: {
                    card.loading = checked
                }
            }
        }

        Rectangle {
            height: 1
            width: 700
            color: "black"
        }

        // Below is an example on how to implement the network routing using StatusCard and Canvas, also the function in Utils to draw an arrow
        Row {
            id: cards
            spacing: 200
            Column {
                id: leftColumn
                spacing: 20
                Repeater {
                    model: fromNetworksList
                    StatusCard {
                        primaryText: name
                        secondaryText: balance === 0 ? "No Balance" : !hasGas ? "No Gas" : tokensToSend
                        tertiaryText: "BALANCE: " + balance
                        state: balance === 0 || !hasGas ? "unavailable" :  "default"
                        cardIconName: iconName
                        advancedMode: card.advancedMode
                        advancedInputText: tokensToSend
                        disabledText: "Disabled"
                        onLockCard: (lock) => locked = !lock
                        disableText: "Disable"
                        enableText: "Enable"
                    }
                }
            }

            Column {
                id: rightColumn
                spacing: 20
                Repeater {
                    model: toNetworksList
                    StatusCard {
                        primaryText: name
                        secondaryText: tokensToReceive
                        tertiaryText: ""
                        state: preferred ? "default" : "unprefeered"
                        cardIconName: iconName
                        opacity: preferred ? 1 : 0
                        advancedMode: card.advancedMode
                        advancedInputText: tokensToReceive
                        disabledText: "Disabled"
                        onLockCard: (lock) => locked = !lock
                        disableText: "Disable"
                        enableText: "Enable"
                    }
                }
            }
        }
    }

    Canvas {
        id: canvas
        x: layout.x + leftColumn.x
        y: cards.y
        width: cards.width
        height: cards.height

        function clear() {
            var ctx = getContext("2d");
            ctx.reset()
        }

        onPaint: {
            // Get the canvas context
            var ctx = getContext("2d");

            for(var i = 0; i< fromNetworksList.count; i++) {
                if(fromNetworksList.get(i).routedTo !== "") {
                    for(var j = 0; j< toNetworksList.count; j++) {
                        if(fromNetworksList.get(i).routedTo === toNetworksList.get(j).name) {
                            Utils.drawArrow(ctx, leftColumn.children[i].x + leftColumn.children[i].width,
                                            leftColumn.children[i].y + leftColumn.children[i].height/2,
                                            rightColumn.x + rightColumn.children[j].x,
                                            rightColumn.children[j].y + rightColumn.children[j].height/2,
                                            '#627EEA')
                        }
                    }
                }
            }
        }
    }


    ListModel {
        id: toNetworksList
        ListElement {
            name: "Mainnet"
            iconName: "status"
            tokensToReceive: 75
            preferred: true
        }
        ListElement {
            name: "Aztec"
            iconName: "status"
            tokensToReceive: 0
            preferred: false
        }
        ListElement {
            name: "Hermez"
            iconName: "status"
            tokensToReceive: 75
            preferred: true
        }
        ListElement {
            name: "Loppring"
            iconName: "status"
            tokensToReceive: 0
            preferred: true
        }
        ListElement {
            name: "Optimism"
            iconName: "status"
            tokensToReceive: 100
            preferred: true
        }
        ListElement {
            name: "zkSync"
            iconName: "status"
            tokensToReceive: 0
            preferred: false
        }
    }

    ListModel {
        id: fromNetworksList
        ListElement {
            name: "Mainnet"
            iconName: "status"
            tokensToSend: 75
            balance: 75
            routedTo: "Mainnet"
            hasGas: true
        }
        ListElement {
            name: "Aztec"
            iconName: "status"
            tokensToSend: 0
            balance: 75
            routedTo: ""
            hasGas: false
        }
        ListElement {
            name: "Hermez"
            iconName: "status"
            tokensToSend: 75
            balance: 75
            routedTo: "Hermez"
            hasGas: true
        }
        ListElement {
            name: "Loppring"
            iconName: "status"
            tokensToSend: 0
            balance: 0
            routedTo: ""
            hasGas: false
        }
        ListElement {
            name: "Optimism"
            iconName: "status"
            tokensToSend: 75
            balance: 75
            routedTo: "Optimism"
            hasGas: true
        }
        ListElement {
            name: "zkSync"
            iconName: "status"
            tokensToSend: 25
            balance: 25
            routedTo: "Optimism"
            hasGas: true
        }
    }
}

// category: Components
