import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

ApplicationWindow {
    id: root

    required property var controller

    property var mainWindow: null

    readonly property bool loggedIn: !!(mainWindow && mainWindow.userLoggedIn)

    title: qsTr("Keycard Simulator Controller")
    width: 380
    minimumWidth: 380
    height: 890
    minimumHeight: 890

    x: mainWindow ? Math.max(0, mainWindow.x + mainWindow.width + 4) : 100
    y: mainWindow ? mainWindow.y + 32 : 100

    QtObject {
        id: d

        property bool simulatorStarted: false
        property string simulatorError: ""
        property var cardIds: []
        property bool readerPlugged: false
        property bool cardInserted: false

        property bool creatingCard: false
        property bool creationFailed: false
        property string creationStatus: ""
        property string pendingCardId: ""

        readonly property string keycardVersion32: "3.2"
        readonly property string keycardVersion40: "4.0"
        readonly property string selectedVersion: useTag40Check.checked?
                                                      d.keycardVersion40
                                                    : d.keycardVersion32

        readonly property string selectedCardId: cardSelector.currentIndex >= 0
                                                 && cardSelector.currentIndex < d.cardIds.length?
                                                     d.cardIds[cardSelector.currentIndex]
                                                   : ""

        function resetState() {
            d.cardIds = []
            d.readerPlugged = false
            d.cardInserted = false
            d.creatingCard = false
            d.creationFailed = false
            d.creationStatus = ""
            cardSelector.currentIndex = -1
        }
    }

    Connections {
        target: root.controller

        function onCardCreationFinished(error) {
            d.creatingCard = false
            d.creationFailed = !!error
            d.creationStatus = !!error ? qsTr("Keycard \"%1\" not created: %2").arg(d.pendingCardId).arg(error)
                                       : qsTr("Keycard \"%1\" created").arg(d.pendingCardId)
            if (!!error) {
                d.cardIds = d.cardIds.filter(id => id !== d.pendingCardId)
            }
            d.pendingCardId = ""
        }
    }

    component SectionHeader: StatusBaseText {
        font.bold: true
        Layout.topMargin: 4
    }
    component Separator: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.palette.directColor2
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        // ---- Section 0. Applet version ----
        SectionHeader { text: qsTr("Applet version") }
        CheckBox {
            id: useTag40Check
            objectName: "keycardSimUseTag40"
            text: qsTr("Use applet tag 4.0 (SecureChannel V2)")
            checked: false
            enabled: !d.simulatorStarted
        }
        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            color: Theme.palette.baseColor1
            text: useTag40Check.checked
                  ? qsTr("Tag 4.0 needs keycard-qt SecureChannel V2 support — not driveable by the app yet and refers to status-keycard after #72e9574 commit.")
                  : qsTr("Default: tag 3.2 (classic password pairing), matches the current keycard-qt and refers to status-keycard #72e9574 commit.")
        }

        Separator {}

        // ---- Section 1. Simulator ----
        SectionHeader { text: qsTr("1. Simulator") }
        StatusButton {
            objectName: "keycardSimStartButton"
            Layout.fillWidth: true
            text: d.simulatorStarted ? qsTr("Restart Keycard Simulator")
                                     : qsTr("Start Keycard Simulator")
            onClicked: {
                d.simulatorError = root.controller.startSimulator(d.selectedVersion)
                d.simulatorStarted = !d.simulatorError
                if (d.simulatorStarted)
                    d.resetState()
            }
        }
        StatusBaseText {
            objectName: "keycardSimStartError"
            Layout.fillWidth: true
            visible: !!d.simulatorError
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            color: Theme.palette.dangerColor1
            text: d.simulatorError
        }

        Separator {}

        // ---- Section 2. Create keycard ----
        SectionHeader { text: qsTr("2. Create keycard") }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StatusBaseText { text: qsTr("Card id:") }
            TextField {
                id: cardIdField
                objectName: "keycardSimCardId"
                enabled: d.simulatorStarted
                selectByMouse: true
                Layout.fillWidth: true
            }
        }

        StatusButton {
            objectName: "keycardSimCreateEmptyButton"
            Layout.fillWidth: true
            text: qsTr("Create Empty Keycard")
            enabled: d.simulatorStarted
                     && cardIdField.text.trim() !== ""
                     && d.cardIds.indexOf(cardIdField.text.trim()) === -1
            onClicked: {
                const id = cardIdField.text.trim()
                root.controller.createCard(id)
                d.cardIds = d.cardIds.concat([id])
                cardIdField.clear()
            }
        }

        StatusBaseText {
            Layout.topMargin: 4
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            color: Theme.palette.baseColor1
            text: qsTr("— or create one with a seed —")
        }
        TextField {
            id: seedField
            objectName: "keycardSimSeed"
            enabled: d.simulatorStarted
            selectByMouse: true
            Layout.fillWidth: true
            placeholderText: qsTr("Seed phrase (mandatory)")
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StatusBaseText { text: qsTr("PIN:") }
            TextField {
                id: pinField
                objectName: "keycardSimPin"
                enabled: d.simulatorStarted
                Layout.preferredWidth: 90
                text: "111111"
                maximumLength: 6
                inputMethodHints: Qt.ImhDigitsOnly
                validator: RegularExpressionValidator { regularExpression: /[0-9]{0,6}/ }
            }
            StatusBaseText { text: qsTr("PUK:") }
            TextField {
                id: pukField
                objectName: "keycardSimPuk"
                enabled: d.simulatorStarted
                Layout.fillWidth: true
                text: "000000000000"
                maximumLength: 12
                inputMethodHints: Qt.ImhDigitsOnly
                validator: RegularExpressionValidator { regularExpression: /[0-9]{0,12}/ }
            }
        }
        TextField {
            id: nameField
            objectName: "keycardSimName"
            enabled: d.simulatorStarted
            selectByMouse: true
            Layout.fillWidth: true
            text: "StatusKeycard"
            placeholderText: qsTr("Keycard name (optional)")
        }
        TextField {
            id: pathsField
            objectName: "keycardSimPaths"
            enabled: d.simulatorStarted
            selectByMouse: true
            Layout.fillWidth: true
            text: "m/44'/60'/0'/0/0"
            placeholderText: qsTr("Paths, comma-separated (optional)")
        }
        TextField {
            id: pairingPasswordField
            objectName: "keycardSimPairingPassword"
            enabled: d.simulatorStarted
            selectByMouse: true
            Layout.fillWidth: true
            placeholderText: qsTr("Pairing password (optional, default if empty)")
        }
        StatusButton {
            objectName: "keycardSimCreateWithSeedButton"
            Layout.fillWidth: true
            text: d.creatingCard ? qsTr("Creating Keycard...") : qsTr("Create Keycard")
            enabled: d.simulatorStarted
                     && !d.creatingCard
                     && cardIdField.text.trim() !== ""
                     && d.cardIds.indexOf(cardIdField.text.trim()) === -1
                     && seedField.text.trim() !== ""
                     && pinField.text.length === 6
                     && pukField.text.length === 12
            onClicked: {
                const id = cardIdField.text.trim()
                d.creatingCard = true
                d.creationStatus = ""
                d.pendingCardId = id
                root.controller.createKeycardWithSeed(id, seedField.text.trim(),
                                                      pinField.text, pukField.text, nameField.text.trim(), pathsField.text.trim(),
                                                      pairingPasswordField.text)
                d.cardIds = d.cardIds.concat([id])
                cardIdField.clear()
                seedField.clear()
            }
        }
        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            visible: !!text
            color: d.creationFailed ? Theme.palette.dangerColor1 : Theme.palette.successColor1
            // A failed Load leaves the card empty, and that only shows up much later as "the
            // keycard is empty" in whatever flow the card is used in — report it here, at the source.
            text: d.creationStatus
        }
        StatusButton {
            objectName: "keycardSimClearLocalPairingsButton"
            Layout.fillWidth: true
            text: qsTr("Clear local pairings")
            onClicked: {
                root.controller.clearLocalPairings()
            }
        }

        Separator {}

        // ---- Section 3. Select keycard ----
        SectionHeader { text: qsTr("3. Select keycard (does not insert it)") }
        ComboBox {
            id: cardSelector
            objectName: "keycardSimCardSelector"
            Layout.fillWidth: true
            enabled: d.simulatorStarted && !d.cardInserted && d.cardIds.length > 0
            model: d.cardIds
            displayText: d.selectedCardId === "" ? qsTr("<no keycard selected>")
                                                 : d.selectedCardId
            Component.onCompleted: currentIndex = -1
            onCountChanged: currentIndex = -1
        }

        Separator {}

        // ---- Section 4. Reader & card (one reader, one card at a time) ----
        SectionHeader { text: qsTr("4. Reader & card") }
        Flow {
            Layout.fillWidth: true
            spacing: 8

            StatusButton {
                objectName: "keycardSimInsertButton"
                text: qsTr("Insert keycard")
                ToolTip.text: qsTr("Inserts the selected keycard")
                ToolTip.visible: hovered
                enabled: d.simulatorStarted && d.readerPlugged
                         && d.selectedCardId !== "" && !d.cardInserted
                onClicked: {
                    root.controller.insertCard(d.selectedCardId)
                    d.cardInserted = true
                }
            }
            StatusButton {
                objectName: "keycardSimRemoveButton"
                text: qsTr("Remove keycard")
                ToolTip.text: qsTr("Removes the selected keycard")
                ToolTip.visible: hovered
                enabled: d.cardInserted
                onClicked: {
                    root.controller.removeCard()
                    d.cardInserted = false
                    cardSelector.currentIndex = -1   // no selection once removed
                }
            }
            StatusButton {
                objectName: "keycardSimPlugReaderButton"
                text: qsTr("Plug reader")
                enabled: d.simulatorStarted && !d.readerPlugged
                onClicked: {
                    root.controller.plugReader()
                    d.readerPlugged = true
                }
            }
            StatusButton {
                objectName: "keycardSimUnplugReaderButton"
                text: qsTr("Unplug reader")
                enabled: d.readerPlugged
                onClicked: {
                    root.controller.unplugReader()
                    d.readerPlugged = false
                    if (d.cardInserted) {
                        d.cardInserted = false
                        cardSelector.currentIndex = -1
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
