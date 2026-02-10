import QtQuick

import QtQuick.Controls as QC
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

/*!
      \qmltype StatusBaseInput
      \inherits Item
      \inqmlmodule StatusQ.Controls
      \since StatusQ.Controls 0.1
      \brief Displays a customized TextInput component.
      Inherits \l{https://doc.qt.io/qt-5/qml-qtquick-item.html}{Item}.

      The \c StatusBaseInput displays an enhanced TextInput for users to type text.
      For example:

      \qml
      StatusBaseInput {
        implicitWidth: parent.width
        implicitHeight: 36
        topPadding: 8
        bottomPadding: 8
        clearable: true
        placeholderText: qsTr("Search")
        icon.name: "search"
      }
      \endqml

      \image status_base_input.png

      For a list of components available see StatusQ.

      \note The scrolling behavior of the \c StatusBaseInput is disabled for non-multiline configurations.
        This is to prevent the \c StatusBaseInput capturing the macOS trackpad input from being propagated.
*/

Item {
    id: root

    // Accessibility properties
    Accessible.name: Utils.formatAccessibleName(placeholderText, objectName)

    /*!
        \qmlproperty bool StatusBaseInput::multiline
        This property indicates whether the StatusBaseInput allows multiline text. Default value is false.
    */
    property bool multiline: false

    /*!
        \qmlproperty bool StatusBaseInput::acceptReturn
        This property indicates whether the StatusBaseInput allows pressing Enter or Return.
        This is used in case multiline is false and we still want to interact using Enter or Return. Default value is false.
    */
    property bool acceptReturn: false
    /*!
        \qmlproperty bool StatusBaseInput::clearable
        This property indicates whether the StatusBaseInput allows clearing all text. Default value is false.
    */
    property bool clearable: false
    /*!
        \qmlproperty alias StatusBaseInput::inputMethodHints
        This property holds a reference to the TextEdit component's inputMethodHints property.
    */
    property alias inputMethodHints: edit.inputMethodHints
    /*!
        \qmlproperty alias StatusBaseInput::selectedText
        This property holds a reference to the TextEdit component's selectedText property.
    */
    property alias selectedText: edit.selectedText
    /*!
        \qmlproperty alias StatusBaseInput::selectedTextColor
        This property holds a reference to the TextEdit component's selectedTextColor property.
    */
    property alias selectedTextColor: edit.selectedTextColor
    /*!
        \qmlproperty alias StatusBaseInput::selectionStart
        This property holds a reference to the TextEdit component's selectionStart property.
    */
    property alias selectionStart: edit.selectionStart
    /*!
        \qmlproperty alias StatusBaseInput::selectionEnd
        This property holds a reference to the TextEdit component's selectionEnd property.
    */
    property alias selectionEnd: edit.selectionEnd
    /*!
        \qmlproperty alias StatusBaseInput::cursorPosition
        This property holds a reference to the TextEdit component's cursorPosition property.
    */
    property alias cursorPosition: edit.cursorPosition

    /*!
        \qmlproperty alias StatusBaseInput::edit
        This property holds a reference to the TextEdit component.
    */
    property alias edit: edit
    /*!
        \qmlproperty alias StatusBaseInput::text
        This property holds a reference to the TextEdit component's text property.
    */
    property alias text: edit.text
    /*!
        \qmlproperty alias StatusBaseInput::background
        This property holds a reference to the background component.
    */
    property alias background: background
    /*!
        \qmlproperty alias StatusBaseInput::color
        This property holds a reference to the TextEdit component's color property.
    */

    property alias color: edit.color
    /*!
        \qmlproperty alias StatusBaseInput::font
        This property holds a reference to the TextEdit component's font property.
    */
    property alias font: edit.font
    /*!
        \qmlproperty alias StatusBaseInput::focussed
        This property holds a reference to the TextEdit component's activeFocus property.
    */
    property alias focussed: edit.activeFocus
    /*!
        \qmlproperty alias StatusBaseInput::verticalAlignment
        This property holds a reference to the TextEdit component's verticalAlignment property.
    */
    property alias verticalAlignment: edit.verticalAlignment
    /*!
        \qmlproperty alias StatusBaseInput::horizontalAlignment
        This property holds a reference to the TextEdit component's horizontalAlignment property.
    */
    property alias horizontalAlignment: edit.horizontalAlignment
    /*!
        \qmlproperty alias StatusBaseInput::placeholder
        This property holds a reference to the placeholder component.
    */
    property alias placeholder: placeholder
    /*!
        \qmlproperty alias StatusBaseInput::placeholderText
        This property holds a reference to the placeholder component's placeholderText property.
    */
    property alias placeholderText: placeholder.text
    /*!
        \qmlproperty alias StatusBaseInput::placeholderTextColor
        This property holds a reference to the placeholder component's placeholderTextColor property.
    */
    property alias placeholderTextColor: placeholder.color
    /*!
        \qmlproperty alias StatusBaseInput::placeholderFont
        This property holds a reference to the placeholder component's font property.
    */
    property alias placeholderFont: placeholder.font

    /*!
        \qmlproperty real StatusBaseInput::leftPadding
        This property sets the left padding.
    */
    property real leftPadding: leftComponentLoader.status === Loader.Ready && leftComponentLoader.item ? 6 : 16
    /*!
        \qmlproperty real StatusBaseInput::rightPadding
        This property sets the right padding.
    */
    property real rightPadding: rightComponentLoader.status === Loader.Ready && rightComponentLoader.item ? 6 : 16
    /*!
        \qmlproperty real StatusBaseInput::topPadding
        This property sets the top padding.
    */
    property real topPadding: 12
    /*!
        \qmlproperty real StatusBaseInput::bottomPadding
        This property sets the bottom padding.
    */
    property real bottomPadding: 12
    /*!
        \qmlproperty var StatusBaseInput::tabNavItem
        This property sets the tab key navigation item.
    */
    property var tabNavItem: null
    /*!
        \qmlproperty int StatusBaseInput::maximumLength
        This property sets the text's maximum length.
    */
    property int maximumLength: 0

    /*!
        \qmlproperty bool StatusBaseInput::valid
        This property sets the valid state. Default value is false.
    */
    property bool valid: false
    /*!
        \qmlproperty bool StatusBaseInput::pristine
        This property sets the pristine. Default value is true.
    */
    property bool pristine: true
    /*!
        \qmlproperty bool StatusBaseInput::dirty
        This property sets the dirty property. Default value is false.
    */
    property bool dirty: false
    /*!
        \qmlproperty bool StatusBaseInput::pending
        This property holds the maximum height of the component. Default value is false.
    */
    property bool pending: false
    /*!
        \qmlproperty bool StatusBaseInput::leftIcon
        This property sets the visibility of the left icon. Default value is true.
    */
    property bool leftIcon: true
    /*!
        \qmlproperty bool StatusBaseInput::isIconSelectable
        This property indicates whether icon is selectable. Default value is false.
    */
    property bool isIconSelectable: false
    /*!
        \qmlproperty bool StatusBaseInput::showBackground
        This property sets the visibility of the background. Default value is true.
    */
    property bool showBackground: true
    /*!
        \qmlproperty bool StatusBaseInput::warningMode
        This property sets warning mode on the input
    */
    property bool warningMode: false
    /*!
        \qmlproperty StatusAssetSettings StatusBaseInput::icon
        This property holds a set of settings for the icon of the StatusBaseInput.
    */
    property StatusAssetSettings asset: StatusAssetSettings {
        width: 24
        height: 24
        name: ""
        color: root.Theme.palette.baseColor1
        emoji: ""
        letterSize: emoji ? 11 : 14
        bgWidth: 30
        bgHeight: 30
        bgColor: root.Theme.palette.indirectColor1
    }

    /*!
        \qmlproperty string StatusBaseInput::letterIconName
        This property holds the letter that should be displayed in the letter identicon component.
    */
    property string letterIconName: ""
    /*!
        \qmlproperty Component StatusBaseInput::leftComponent
        This property sets the left component to be displayed inside the input.
    */
    property Component leftComponent
    /*!
        \qmlproperty Component StatusBaseInput::selectedText
        This property sets the right component to be displayed inside the input.
    */
    property Component rightComponent

    /*!
        \qmlsignal
         This signal is emitted when the icon is clicked.
    */
    signal iconClicked
    /*!
        \qmlsignal
         This signal is emitted when a hard key is pressed passing as parameter the keyboard event.
    */
    signal keyPressed(var event)
    /*!
        \qmlsignal
         This signal is emitted when the text edit is clicked.
    */
    signal editClicked()
    /*!
        \qmlsignal editingFinished
         This signal is emitted when the text edit loses focus.
    */
    signal editingFinished()

    function insert(position, text) {
        let pos = edit.cursorVisible ? edit.cursorPosition : -1
        edit.insert(position, text)
        if (pos >= 0)
            edit.cursorPosition = position <= pos ? pos + 1 : pos
    }

    onFocusChanged: {
        if(focus) edit.forceActiveFocus()
    }

    implicitWidth: contentLayout.implicitWidth + root.leftPadding + root.rightPadding
    implicitHeight: contentLayout.implicitHeight

    Rectangle {
        id: background
        anchors.fill: parent
        color: root.showBackground ? Theme.palette.statusAppNavBar.backgroundColor : "transparent"
        radius: 8

        clip: true

        border.width: 1
        border.color: {
            if (!root.showBackground) {
                return "transparent"
            }
            if (!root.valid && root.dirty) {
                return Theme.palette.dangerColor1
            }
            if(root.warningMode) {
                return Theme.palette.warningColor1
            }
            if (edit.cursorVisible) {
                return Theme.palette.primaryColor1
            }
            return sensor.containsMouse ? Theme.palette.primaryColor2 : "transparent"
        }

        StatusMouseArea {
            id: sensor
            anchors.fill: parent
            enabled: edit.enabled
            hoverEnabled: enabled
            cursorShape: enabled ? Qt.IBeamCursor : undefined
            onClicked: {
                if (edit.activeFocus)
                    return;
                edit.forceActiveFocus()
                root.editClicked()
            }
            RowLayout {
                id: contentLayout
                spacing: 8
                anchors {
                    fill: parent
                    leftMargin: root.leftPadding
                    rightMargin: root.rightPadding
                }

                clip: true

                Loader {
                    id: leftComponentLoader
                    sourceComponent: {
                        if (root.leftComponent) return root.leftComponent
                        if (!root.leftIcon) return undefined
                        if (root.asset.emoji || root.asset.isLetterIdenticon) return identiconComponent
                        if (root.asset.name) return isIconSelectable ? identiconComponent : iconComponent
                        return undefined
                    }
                }

                Flickable {
                    id: flick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: root.multiline ? root.topPadding : 0
                    Layout.bottomMargin: root.multiline ? root.bottomPadding : 0

                    contentWidth: edit.paintedWidth
                    contentHeight: edit.paintedHeight
                    implicitWidth: edit.implicitWidth
                    implicitHeight: edit.implicitHeight

                    boundsBehavior: Flickable.StopAtBounds
                    QC.ScrollBar.vertical: StatusScrollBar {
                        interactive: multiline
                        enabled: multiline
                    }
                    clip: true
                    interactive: multiline && edit.activeFocus

                    TextEdit {
                        id: edit
                        property string previousText: text
                        property var keyEvent

                        // This workaround prevents entering new line on mobile when it's not desired.
                        // Qt.ImhSensitiveData prevents entering new line, instead Keys.returnPressed
                        // is emitted and can be handled in a regular way.
                        inputMethodHints: Utils.isMobile && !multiline ? Qt.ImhSensitiveData : Qt.ImhNone

                        topPadding: root.multiline ? 0 : root.topPadding
                        bottomPadding: root.multiline ? 0: root.bottomPadding
                        width: flick.width
                        height: multiline ? implicitHeight : flick.height
                        verticalAlignment: TextEdit.AlignVCenter
                        selectByMouse: true
                        selectionColor: Theme.palette.primaryColor2
                        selectedTextColor: color
                        focus: !Utils.isMobile
                        font.pixelSize: Theme.primaryTextFontSize
                        font.family: Fonts.baseFont.family
                        color: root.enabled ? Theme.palette.directColor1 : Theme.palette.baseColor1
                        wrapMode: root.multiline ? Text.WrapAtWordBoundaryOrAnywhere : TextEdit.NoWrap

                        Keys.onReturnPressed: function (event) {
                            event.accepted = !multiline && !acceptReturn
                            // Special case for single line inputs, where we want to accept the return key, but notify the parend
                            // Enter and return can be used to accept the input
                            if (event.accepted) {
                                root.keyPressed(event)
                            }
                        }
                        Keys.onEnterPressed: function (event) {
                            event.accepted = !multiline && !acceptReturn
                            // Special case for single line inputs, where we want to accept the return key, but notify the parend
                            // Enter and return can be used to accept the input
                            if (event.accepted) {
                                root.keyPressed(event)
                            }
                        }
                        Keys.forwardTo: [root]
                        KeyNavigation.priority: !!root.tabNavItem ? KeyNavigation.BeforeItem : KeyNavigation.AfterItem
                        KeyNavigation.tab: root.tabNavItem
                        Keys.onPressed: (event) => {
                            edit.keyEvent = event.key
                            root.keyPressed(event)
                        }
                        onCursorRectangleChanged: Utils.ensureVisible(flick, cursorRectangle)
                        onActiveFocusChanged: if (root.pristine) root.pristine = false
                        onTextChanged: {
                            if (previousText === text || (previousText === "" && length === 0 && length !== text.length)) {
                                // Not sure why, but the textChanged event was triggered even if it didn't really

                                // Avoid further processing on initial condition when previousText is empty
                                // but text is set to default rich text, as it will mark input dirty and
                                // trigger validation, with likely not valid state
                                return
                            }

                            root.dirty = true
                            if (root.maximumLength > 0) {
                                let utf8Length = Utils.encodeUtf8(text).length
                                if (utf8Length > root.maximumLength) {
                                    var cursor = cursorPosition
                                    text = text.slice(0, maximumLength)
                                    if (cursor > edit.length) {
                                        cursorPosition = edit.length
                                    } else {
                                        cursorPosition = cursor - 1
                                    }
                                }
                                previousText = text
                            }
                        }
                        onEditingFinished: {
                            root.editingFinished()
                        }

                        cursorDelegate: StatusCursorDelegate {
                            cursorVisible: edit.cursorVisible
                        }

                        StatusBaseText {
                            id: placeholder
                            visible: (edit.length === 0)
                            anchors.fill: parent
                            verticalAlignment: parent.verticalAlignment
                            wrapMode: root.multiline ? Text.WrapAnywhere : Text.NoWrap
                            elide: root.multiline? Text.ElideNone : Text.ElideRight
                            color: root.enabled ? Theme.palette.baseColor1 : Theme.palette.directColor6
                        }
                    }
                } // Flickable

                Loader {
                    id: rightComponentLoader
                    sourceComponent: {
                        if (root.rightComponent) return root.rightComponent
                        if (root.clearable) return clearButton
                        if (root.leftIcon) return undefined
                        if (root.asset.emoji) return identiconComponent
                        if (root.asset.name) return isIconSelectable ? identiconComponent : iconComponent
                        return undefined
                    }
                }
            }
        }
    } // Rectangle


    Component {
        id: clearButton

        StatusClearButton {
            visible: edit.length != 0 && root.clearable && !root.multiline
                     && edit.activeFocus
            onClicked: {
                edit.clear()
            }
        }
    }

    Component {
        id: identiconComponent

        StatusSmartIdenticon {
            id: identicon

            asset.width: 24
            asset.height: 24
            asset.bgWidth: root.asset.bgWidth
            asset.bgHeight: root.asset.bgHeight
            asset.bgColor: root.asset.bgColor
            asset.color: root.asset.color
            asset.letterSize: root.asset.letterSize
            asset.emoji: root.asset.emoji
            asset.name: !root.asset.emoji ? root.asset.name : ""
            asset.isLetterIdenticon: root.asset.isLetterIdenticon
            name: root.letterIconName

            StatusMouseArea {
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                anchors.fill: parent
                hoverEnabled: true
                enabled: identicon.visible
                onClicked: root.iconClicked()
            }
        }
    }

    Component {
        id: iconComponent

        StatusIcon {
            id: statusIcon

            icon: root.asset.name
            width: root.asset.width
            height: root.asset.height
            color: root.asset.color
        }
    }
}
