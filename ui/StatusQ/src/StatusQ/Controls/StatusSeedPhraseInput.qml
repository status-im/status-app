pragma ComponentBehavior: Bound

import QtQuick
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import SortFilterProxyModel

/*!
   \qmltype StatusSeedPhraseInput
   \inherits Item
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief Displays a text input with suggestions. Inherits \l{https://doc.qt.io/qt-5/qml-qtquick-item.html}{Item}.

   The \c StatusSeedPhraseInput item displays a text input with suggestions filtered based on the typed text.
   For example:

   \qml
       StatusSeedPhraseInput {
           id: statusSeedInput
           anchors.left: parent.left
           anchors.right: parent.right
           textEdit.input.anchors.leftMargin: 16
           textEdit.input.anchors.rightMargin: 16
           textEdit.input.anchors.topMargin: 11
           leftComponentText: "1"
           inputList: ListModel {
               ListElement {
                   seedWord: "panda"
               }
               ListElement {
                   seedWord: "posible"
               }
               ListElement {
                   seedWord: "wing"
               }
           }
       }
   \endqml

   \image status_seed_phrase_input.png

   For a list of components available see StatusQ.
*/

Item {
    id: root
    width: 162
    height: 44
    /*!
        \qmlproperty alias StatusSeedPhraseInput::textEdit
        This property is an alias to the StatusInput's textEdit property.
    */
    property alias textEdit: seedWordInput
    /*!
        \qmlproperty alias StatusSeedPhraseInput::text
        This property is an alias to the StatusInput's text property.
    */
    property alias text: seedWordInput.text
    /*!
        \qmlproperty string StatusSeedPhraseInput::leftComponentText
        This property sets the StatusInput's left component's text.
    */
    property string leftComponentText: ""
    /*!
        \qmlproperty var StatusSeedPhraseInput::inputList
        This property holds the seed words dictionary
    */
    property var inputList

    QtObject {
        id: d

        property string filteringPrefix: ""
    }

    SortFilterProxyModel {
        id: filteredList

        sourceModel: d.filteringPrefix && root.inputList ? root.inputList : null

        filters: RegExpFilter {
            id: filter

            syntax: RegExpFilter.Wildcard
            pattern: `${d.filteringPrefix}*`
        }
    }


    property bool isError

    readonly property bool suggestionsOpened: suggListContainer.opened

    /*!
        \qmlsignal doneInsertingWord
        This signal is emitted when the user selects a word from the suggestions list
        either by mouse click or by typing 4 characters that match and passes as a parameter
        the selected word. The corresponding handler is \c onDoneInsertingWord.
    */
    signal doneInsertingWord(string word)
    /*!
        \qmlsignal keyPressed
        This signal is emitted when the user presses a keyboard key and passes as a
        parameter the event.
    */
    signal keyPressed(var event)
    /*!
        \qmlsignal editClicked
        This signal is emitted when the user clicks inside the StatusInput.
    */
    signal editClicked()
    /*!
        \qmlsignal editingFinished
        This signal is emitted when the text edit loses focus.
    */
    signal editingFinished()

    function setWord(seedWord: string): void {
        let seedWordTrimmed = seedWord.trim()
        seedWordInput.input.edit.text = seedWordTrimmed
        seedWordInput.input.edit.cursorPosition = seedWordInput.text.length
        d.filteringPrefix = ""
        root.doneInsertingWord(seedWordTrimmed)
    }

    onActiveFocusChanged: {
        if (SQUtils.Utils.isMobile)
            return
        if (root.activeFocus) {
            seedWordInput.input.edit.forceActiveFocus();
        }
    }

    Component {
        id: seedInputLeftComponent
        StatusBaseText {
            leftPadding: text.length === 1 ? 10 : 6
            rightPadding: 4
            text: root.leftComponentText
            font.family: Fonts.monoFont.family
            horizontalAlignment: Qt.AlignHCenter
            color: root.isError ? Theme.palette.dangerColor1
                                : seedWordInput.input.edit.activeFocus ? Theme.palette.primaryColor1
                                                                       : Theme.palette.baseColor1
        }
    }

    StatusInput {
        id: seedWordInput

        implicitWidth: parent.width
        input.leftComponent: seedInputLeftComponent
        input.acceptReturn: true
        input.edit.inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhPreferLowercase

        Binding on input.background.border.color {
            when: root.isError && seedWordInput.input.edit.activeFocus
            value: Theme.palette.dangerColor1
        }

        onTextChanged: {
            const trimmedLowercase = text.trim().toLowerCase()
            d.filteringPrefix = trimmedLowercase

            if (filteredList.count === 1 && input.edit.keyEvent !== Qt.Key_Backspace
                    && input.edit.keyEvent !== Qt.Key_Delete
                    && filteredList.get(0).seedWord.trim() === trimmedLowercase) {
                seedWordInput.input.edit.cursorPosition = trimmedLowercase.length
                d.filteringPrefix = ""
                root.doneInsertingWord(trimmedLowercase)
            }
        }
        onKeyPressed: function (event) {
            switch (input.edit.keyEvent) {
                case Qt.Key_Tab:
                case Qt.Key_Return:
                case Qt.Key_Enter: {
                    if (!!text && filteredList.count > 0) {
                        root.setWord(filteredList.get(seedSuggestionsList.currentIndex).seedWord)
                        event.accepted = true
                        return
                    }
                    break;
                }
                case Qt.Key_Down: {
                    seedSuggestionsList.incrementCurrentIndex()
                    input.edit.keyEvent = null
                    break;
                }
                case Qt.Key_Up: {
                    seedSuggestionsList.decrementCurrentIndex()
                    input.edit.keyEvent = null
                    break;
                }
                case Qt.Key_Space: {
                    event.accepted = !event.text.match(/^[a-zA-Z]$/)
                    break;
                }
            }

            root.keyPressed(event);
        }
        onEditClicked: {
            root.editClicked();
        }

        onEditingFinished: {
            root.editingFinished();
        }
    }

    StatusDropdown {
        id: suggListContainer

        directParent: seedWordInput
        relativeY: seedWordInput.height + 4
        contentWidth: seedSuggestionsList.width
        contentHeight: ((seedSuggestionsList.count <= 5) ? seedSuggestionsList.count : 5) *34
        topPadding: 8
        bottomPadding: 8
        leftPadding: 0
        rightPadding: 0

        // On mobile, force popup to remain a dropdown instead of a bottom sheet.
        // Reason: a bottom sheet would be hidden behind the on-screen keyboard.
        bottomSheetAllowed: false

        visible: ((filteredList.count > 0) && seedWordInput.input.edit.activeFocus)

        StatusListView {
            id: seedSuggestionsList
            width: (((seedSuggestionsList.contentItem.childrenRect.width + 24) > root.width) ? root.width
                    : (seedSuggestionsList.contentItem.childrenRect.width + 24)) + 8
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            onCountChanged: seedSuggestionsList.currentIndex = 0

            model: filteredList

            delegate: Item {
                id: txtDelegate
                width: suggWord.contentWidth
                height: 34
                Rectangle {
                    width: seedSuggestionsList.width
                    height: parent.height
                    color: mouseArea.containsMouse || index === seedSuggestionsList.currentIndex ?
                        Theme.palette.primaryColor1 : "transparent"
                }
                StatusBaseText {
                    id: suggWord
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: seedWord
                    color: mouseArea.containsMouse || index === seedSuggestionsList.currentIndex ? Theme.palette.indirectColor1 : Theme.palette.directColor1
                    font.pixelSize: Theme.additionalTextSize
                    elide: Text.ElideRight
                }
                StatusMouseArea {
                    id: mouseArea
                    width: seedSuggestionsList.width
                    height: parent.height
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.setWord(seedWord)
                }
            }
        }
    }
}
