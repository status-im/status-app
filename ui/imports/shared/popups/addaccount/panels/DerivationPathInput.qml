import QtQuick
import QtQuick.Controls

import StatusQ.Controls
import StatusQ.Core.Theme

import "DerivationPathInput" as Internals

/// Custom text input with guiding markers and layout for entering derivation paths
/// \note don't allow input control to change text, this will generate too many states from all events combinations
/// \note all modifiable events affect data model only which is then used to generate the final HTML displayable input.text
/// \note we allow non-modifiable events only (e.g. cursor movement) to propagate to the input control
/// \note d.currentIndex is always on a Number type element
/// \note implementation relies that all the events are handled serially on the same thread
Item {
    id: root

    readonly property alias derivationPath: d.currentDerivationPath
    readonly property alias basePath: d.currentBasePath

    property alias levelsLimit: controller.levelsLimit

    property alias errorMessage: d.errorMessage
    property alias warningMessage: d.warningMessage

    property alias input: input

    readonly property alias detectedStandardBasePath: d.detectedStandardBasePath

    signal editingFinished()

    implicitWidth: input.implicitWidth
    implicitHeight: input.implicitHeight

    // returns true if the derivation path is valid and false otherwise. Will also set the appropriate errorMessage if the derivation path is invalid
    function resetDerivationPath(basePath, newDerivationPath) {
        var res = controller.completeDerivationPath(basePath, newDerivationPath)

        if(res.errorMessage) {
            return false
        }
        d.resetMessages()
        d.elements = res.elements

        // Check if we enforced a standard derivation path
        d.frozenLevelCount = d.elements.filter((e) => e.isFrozen && e.isNumber()).length

        d.updateText(d.elements)
        d.currentBasePath = basePath
        input.cursorPosition = d.elements[d.elements.length - 1].endIndex
        return true
    }

    QtObject {
        id: d

        property string currentDerivationPath: ""
        property string currentBasePath: ""

        property var elements: []
        /// element index at cursor position
        property int currentIndex: -1

        property int cursorPositionToRestore: -1

        property string errorMessage: ""
        property string warningMessage: ""

        property int frozenLevelCount: 0
        property bool detectedStandardBasePath: frozenLevelCount >= 3

        function resetMessages() { errorMessage = ""; warningMessage = "" }

        readonly property bool selectionIsActive: Math.abs(input.selectionEnd - input.selectionStart) > 0

        property bool expectTextUpdate: false

        // Updates input text with elements content
        function updateText(elements, cursorOffset = 0) {
            d.cursorPositionToRestore = input.cursorPosition + cursorOffset
            expectTextUpdate = true
            input.text = controller.generateHtmlFromElements(elements)
        }

        // Plain text corresponding to the current data model
        function modelText() {
            return elements.map(e => e.content).join("")
        }

        // Checks whether input.text was changed by simply inserting characters
        // into the model's text. Mobile virtual keyboards deliver characters this way,
        // without ever producing the key events this control is built around.
        // \return {text, position} describing the inserted characters, or null
        function externalInsertion() {
            const modelText = d.modelText()
            const currentText = input.edit.getText(0, input.text.length)
            if (currentText.length <= modelText.length)
                return null
            var prefix = 0
            while (prefix < modelText.length && modelText[prefix] === currentText[prefix])
                prefix++
            var suffix = 0
            while (suffix < modelText.length - prefix
                   && modelText[modelText.length - 1 - suffix] === currentText[currentText.length - 1 - suffix])
                suffix++
            if (prefix + suffix !== modelText.length)
                return null
            return { text: currentText.slice(prefix, currentText.length - suffix), position: prefix }
        }

        // Applies characters that arrived as an input-method commit as if they
        // had been typed one by one: each character goes through the same
        // controller operations as in Keys.onPressed, so the data model stays
        // the single source of truth regardless of how the text was entered.
        // \param insertion the {text, position} object built by externalInsertion()
        function replayInsertion(insertion) {
            input.cursorPosition = insertion.position
            for (const character of insertion.text) {
                if (character === '/' || character === '\\'
                        || character === "'" || character === '`') {
                    const newElementIndex = controller.tryAddAndFixSeparators(d.elements, d.currentIndex, d.elements[d.currentIndex].startIndex === input.cursorPosition)
                    if (newElementIndex > -1)
                        d.updateText(d.elements, d.elements[newElementIndex].endIndex - input.cursorPosition)
                } else if (d.currentIndex >= 0 && d.currentIndex < d.elements.length) {
                    controller.insertContent(d.elements, d.currentIndex, character, input.cursorPosition)
                    d.updateText(d.elements, 1)
                }
            }
        }
    }

    Internals.Controller {
        id: controller

        enabledColor: root.enabled ? Theme.palette.directColor1 : Theme.palette.baseColor1
        frozenColor: StatusColors.grey5
        errorColor: Theme.palette.dangerColor1
        warningColor: Theme.palette.warningColor1
        complainTooBigAccIndex: d.detectedStandardBasePath
    }

    StatusBaseInput {
        id: input

        anchors.fill: parent

        edit.textFormat: TextEdit.RichText
        edit.inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

        topPadding: 11
        bottomPadding: 11
        valid: d.errorMessage.length === 0

        readonly property var passthroughKeys: [Qt.Key_Left, Qt.Key_Right, Qt.Key_Escape]

        Shortcut {
            sequences: [StandardKey.Copy]
            enabled: d.selectionIsActive
            onActivated: input.copy()
        }

        Keys.onPressed: (event)=> {
            // Stop propagation of all modifiable events
            for(const key of passthroughKeys) {
                if(event.key === key) {
                    event.accepted = false
                    return
                }
            }
            if(event.modifiers !== Qt.NoModifier && event.text.length === 0) {
                event.accepted = false
                return
            }

            event.accepted = true

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.editingFinished()

            } else if (event.key === Qt.Key_Delete) {
                if(d.selectionIsActive) {
                    controller.deleteFromStartToEnd(d.elements, selectionStart, selectionEnd)
                    d.updateText(d.elements, selectionStart - cursorPosition)
                    return
                }
                if(d.currentIndex >= 0) {
                    const cursorOffset = controller.deleteInContent(d.elements, d.currentIndex, cursorPosition)
                    d.updateText(d.elements, cursorOffset)
                }
            } else if (event.key === Qt.Key_Backspace) {
                if(d.currentIndex >= 0) {
                    const cursorOffset = controller.deleteInContent(d.elements, d.currentIndex, cursorPosition, false)
                    d.updateText(d.elements, cursorOffset)
                }
            } else if (event.key === Qt.Key_Space
                    || event.key === Qt.Key_Tab) {
                const nextIndex = d.currentIndex + 1
                if(nextIndex < d.elements.length) {
                    input.cursorPosition = d.elements[nextIndex].endIndex
                } else {
                    const newElementIndex = controller.tryAddAndFixSeparators(d.elements, nextIndex)
                    if(newElementIndex > -1) {
                        d.updateText(d.elements, d.elements[newElementIndex].endIndex - cursorPosition)
                    }
                }
            } else if (event.key === Qt.Key_Slash
                    || event.key === Qt.Key_Backslash
                    || event.key === Qt.Key_Apostrophe
                    || event.key === Qt.Key_QuoteLeft) {
                const newElementIndex = controller.tryAddAndFixSeparators(d.elements, d.currentIndex, d.elements[d.currentIndex].startIndex === cursorPosition)
                if(newElementIndex > -1) {
                    d.updateText(d.elements, d.elements[newElementIndex].endIndex - cursorPosition)
                }
            } else if(event.text) {
                if(d.currentIndex >= 0 && d.currentIndex < d.elements.length) {
                    controller.insertContent(d.elements, d.currentIndex, event.text, cursorPosition)
                    d.updateText(d.elements, event.text.length)
                }
            }
        }

        property int prevCursorPosition: cursorPosition
        onCursorPositionChanged: {
            if(d.selectionIsActive)
                return
            var nextIndex = -1
            for(const i in d.elements) {
                // Prioritize cursor on editable elements
                if(cursorPosition >= d.elements[i].startIndex && d.elements[i].isFrozen ? cursorPosition < d.elements[i].endIndex : cursorPosition <= d.elements[i].endIndex) {
                    nextIndex = Number(i)
                    break
                }
            }
            var movingLeft = cursorPosition < prevCursorPosition
            if(nextIndex > -1) {
                if(d.elements[nextIndex].isFrozen) {
                    const foundIndex = nextIndex
                    while(nextIndex < d.elements.length && d.elements[nextIndex].isFrozen) {
                        nextIndex += movingLeft ? -1 : 1
                        if(nextIndex < 0) {
                            nextIndex = foundIndex
                            movingLeft = false
                        }
                    }
                    if(nextIndex < d.elements.length) {
                        cursorPosition = movingLeft ? d.elements[nextIndex].endIndex : d.elements[nextIndex].startIndex
                    } else {
                        nextIndex = d.elements.length - 1
                        cursorPosition = d.elements[nextIndex].endIndex
                    }
                }
            } else {
                // On the last element which is frozen
                nextIndex = d.elements.length - 1
            }

            d.currentIndex = nextIndex
            prevCursorPosition = cursorPosition

        }

        onTextChanged: {
            if(d.expectTextUpdate) {
                d.expectTextUpdate = false
            } else {
                const insertion = d.externalInsertion()
                d.cursorPositionToRestore = prevCursorPosition
                d.updateText(d.elements)
                if (insertion)
                    d.replayInsertion(insertion)
                return
            }
            const currentText = edit.getText(0, text.length)
            const validationRes = controller.validateAllElements(d.elements)

            if(d.cursorPositionToRestore >= 0) {
                input.cursorPosition = d.cursorPositionToRestore
                d.cursorPositionToRestore = -1
            }

            d.errorMessage = validationRes.error
            d.warningMessage = validationRes.warning
            if(d.errorMessage.length > 0 || !d.elements.slice(0, -1).every(obj => obj.content.length > 0)) {
                d.currentDerivationPath = ""
            } else {
                d.currentDerivationPath = currentText
            }
        }
    }
}
