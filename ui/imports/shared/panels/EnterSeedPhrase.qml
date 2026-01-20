import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Controls

import QtModelsToolkit
import SortFilterProxyModel

Control {
    id: root

    // Model representing dictionary of valid words. Single role "seedWord" of
    // string type is expected.
    property alias dictionary: suggestionsModel.sourceModel

    // Error text presented by the component. Set internally when provided words
    // are not present in the dictionary or externally via setError method.
    readonly property alias errorText: errorText.text

    // Indicates if correct words are provided and no external error is set.
    readonly property alias seedPhraseIsValid: d.isValid

    // Seed phrase as an array of words from a dictionary.
    readonly property alias seedPhrase: d.seedPhrase

    // Emitted when all fields are filled with words from dictionary.
    // "seedPhrase" contains array of provided words. Handler is responsible
    // for further validation and setting error via setError message or calling
    // setError with empty string to clear previous error if phrase is valid.
    signal seedPhraseProvided(var seedPhrase)

    // Emitted when seed phrase is marked as valid, suggestions bar not visible
    // and last word is accepted by keyboard.
    signal seedPhraseAccepted

    // An optional Flickable whose content will be automatically positioned to
    // make the focused field visible.
    property Flickable flickable

    // Sets error by providing error message or clears it by setting empty string.
    function setError(errorMessage: string) {
        d.customErrorString = errorMessage
        d.isValid = errorMessage === ""
    }

    QtObject {
        id: d

        readonly property alias markedAsInvalidCount: validityAggregator.value

        property var seedPhrase: []
        property bool isValid
        property string customErrorString

        property int currentIndex
        property Item currentItem

        // automatically position current item in a visible area
        onCurrentItemChanged: {
            if (!root.flickable || !currentItem)
                return

            const rect = Qt.rect(0, -currentItem.height - spacing,
                                 currentItem.width,
                                 currentItem.height + currentItem.height + spacing)
            Utils.ensureVisible(
                        flickable, flickable.contentItem.mapFromItem(
                            currentItem, rect))
        }

        property string filteringPrefix

        readonly property int twoColsThreshold: 450
        readonly property int oneColThreshold: 400

        readonly property int spacing: 8
        readonly property int rowHeight: 44

        function isInDictionary(word: string) : bool {
            return ModelUtils.contains(root. dictionary, "seedWord", word)
        }
    }

    ListModel {
        id: inputModel

        function setEntry(idx: int, phrase: string, valid: bool) {
            setProperty(idx, "currentPhrase", phrase)
            setProperty(idx, "committedValidPhrase", valid ? phrase : "")
            setProperty(idx, "markAsInvalid", !valid)
        }

        Component.onCompleted: {
            const emptyEntry = {
                currentPhrase: "",
                committedValidPhrase: "",
                markAsInvalid: false
            }

            append(Array(24).fill(emptyEntry))
        }
    }

    SortFilterProxyModel {
        id: filteredInputModel

        filters: IndexFilter {
            maximumIndex: lengthBar.selectedLength - 1
        }

        sourceModel: inputModel
    }

    SortFilterProxyModel {
        id: suggestionsModel

        function takeFirst() {
            return get(0).seedWord
        }

        filters: RegExpFilter {
            id: filter

            syntax: RegExpFilter.Wildcard
            pattern: `${d.filteringPrefix || "-"}*`
        }
    }

    FunctionAggregator {
        id: validityAggregator

        model: filteredInputModel
        initialValue: 0
        roleName: "markAsInvalid"
        aggregateFunction: (aggr, value) => aggr + value
    }

    FunctionAggregator {
        id: contentAggregator

        model: filteredInputModel
        initialValue: []
        roleName: "committedValidPhrase"
        aggregateFunction: (aggr, value) => [...aggr, value]

        onValueChanged: {
            d.seedPhrase = value

            if (d.seedPhrase.length === 0)
                return

            if (d.seedPhrase.every(d.isInDictionary))
                root.seedPhraseProvided(seedPhrase)
        }
    }

    SuggestionsBar {
        id: suggestionsBar
        objectName: "suggestionsBar"

        visible: false

        model: suggestionsModel

        onWordSelected: word => {
            inputModel.setEntry(d.currentIndex, word, true)

            // don't lose focus on the list entry, close suggestions
            if (d.currentIndex === repeater.count - 1) {
                d.filteringPrefix = ""
                return
            }

            const next = d.currentItem.nextItemInFocusChain(true)
            if (next)
                next.forceActiveFocus()
        }
    }


    contentItem: ColumnLayout {
        spacing: d.spacing

        StatusSeedPhraseTabBar {
            id: lengthBar

            objectName: "enterSeedPhraseSwitchBar"

            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 458
            Layout.fillWidth: parent.width <= Layout.preferredWidth

            contentHeight: d.rowHeight
        }

        GridLayout {
            id: grid

            columnSpacing: d.spacing
            rowSpacing: d.spacing

            columns: {
                if (width < d.oneColThreshold)
                    return 1
                else if (width < d.twoColsThreshold || lengthBar.selectedLength === 12)
                    return 2
                else
                    return 3
            }

            uniformCellWidths: true

            Repeater {
                id: repeater

                model: filteredInputModel

                onCountChanged: {
                    if (count) {
                        repeater.itemAt(0).forceActiveFocus()
                        d.filteringPrefix = ""
                    }
                }

                delegate: StatusSeedPhraseField {
                    objectName: `enterSeedPhraseInputField${displayIndex}`

                    Layout.fillWidth: true
                    Layout.preferredHeight: d.rowHeight

                    activeFocusOnTab: true
                    focus: false

                    text: model.currentPhrase
                    displayIndex: index + 1
                    valid: !text || !model.markAsInvalid

                    onTextChanged: {
                        if (model.currentPhrase !== text)
                            model.currentPhrase = text
                    }

                    LayoutItemProxy {
                        id: proxy

                        visible: parent.activeFocus && suggestionsModel.count

                        x: -parent.x
                        y: -parent.height - grid.rowSpacing
                        width: grid.width
                        height: parent.height

                        target: suggestionsBar
                    }

                    property bool backspaceOrDeletePressed

                    Keys.onPressed: event => {
                        // this info is stored in order to distingush regular changes
                        // done by inserting content, from those done by removing via
                        // backspace or delete
                        backspaceOrDeletePressed =
                                        event.key === Qt.Key_Backspace ||
                                        event.key === Qt.Key_Delete

                        // insert words when pasted in any field
                        if (event.matches(StandardKey.Paste)) {
                            const words = ClipboardUtils.text.trim().split(/[, \s]+/)
                            const length = words.length

                            if (lengthBar.lengths.includes(length)) {
                                words.forEach((word, idx) => {
                                    inputModel.setEntry(idx, word, d.isInDictionary(word))
                                })

                                repeater.itemAt(length - 1).forceActiveFocus()
                                d.filteringPrefix = ""

                                lengthBar.selectLength(length)
                                event.accepted = true
                            }
                        }
                    }

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            d.currentIndex = index
                            d.currentItem = this

                            d.filteringPrefix = d.isInDictionary(text) ? "" : text
                        }

                        if (!activeFocus && text)
                            inputModel.setEntry(index, text, d.isInDictionary(text))
                    }

                    onAccepted: {
                        // do nothing if word is empty
                        if (!text)
                            return

                        // auto-fill with suggestion or accept whatever is provided
                        if (suggestionsModel.count)
                            inputModel.setEntry(index, suggestionsModel.takeFirst(), true)
                        else
                            inputModel.setEntry(index, text, d.isInDictionary(text))

                        // close suggestions bar
                        d.filteringPrefix = ""

                        // if all words are from dictionary, accept the entire seed phrase
                        if (root.seedPhraseIsValid) {
                            root.seedPhraseAccepted()
                            return
                        }

                        // don't pass focus to next item in the chain in case of last item
                        if (index === repeater.count - 1)
                            return

                        const next = nextItemInFocusChain(true)

                        if (next)
                            next.forceActiveFocus()
                    }

                    Keys.onTabPressed: event => {
                        // auto-complete with first suggestion if available
                        if (suggestionsModel.count)
                            inputModel.setEntry(index, suggestionsModel.takeFirst(), true)

                        // close suggestions
                        d.filteringPrefix = ""

                        // stop forward traversal on the last input
                        event.accepted = index === repeater.count - 1
                    }

                    Keys.onBacktabPressed: event => {
                        // stop backward traversal on the first input
                        event.accepted = index === 0
                    }

                    // block spaces
                    Keys.onSpacePressed: event => {
                        event.accepted = true
                    }

                    onTextEdited: {
                        d.customErrorString = ""
                        d.isValid = false
                        d.filteringPrefix = text

                        if (!text)
                            inputModel.setEntry(index, "", true)
                        else
                            model.committedValidPhrase = ""

                        if (backspaceOrDeletePressed)
                            return

                        if (suggestionsModel.count === 1 &&
                                text === suggestionsModel.takeFirst()) {

                            if (index !== repeater.count - 1) {
                                const next = nextItemInFocusChain(true)

                                if (next)
                                    next.forceActiveFocus()
                            } else {
                                inputModel.setEntry(index, text, d.isInDictionary(text))
                                d.filteringPrefix = ""
                            }
                        } else if (suggestionsModel.count > 1 && text.length === 3 && text === suggestionsModel.takeFirst()) {
                            // Some valid words have only three letters, but they have more than one suggestion
                            // In that case, we set it as an entry to possibly enable the user to submit without further input
                            // This also fixes the e2e test
                            // If the valid word is longer, the user can still finish typing or select from suggestions
                            inputModel.setEntry(index, suggestionsModel.takeFirst(), true)
                        }
                    }
                }

                Component.onCompleted: {
                    repeater.itemAt(0).forceActiveFocus()
                }
            }
        }

        StatusBaseText {
            id: errorText

            objectName: "enterSeedPhraseInvalidSeedText"

            text: d.markedAsInvalidCount
                  ? qsTr("The phrase you’ve entered is invalid")
                  : d.customErrorString

            visible: !!text

            onVisibleChanged: {
                if (!visible)
                    return

                Qt.callLater(() => {
                    if (!flickable || !flickable.contentItem)
                        return

                    const rect = Qt.rect(0, 0, errorText.width, errorText.height)
                    Utils.ensureVisible(flickable, flickable.contentItem.mapFromItem(errorText, rect))
                })
            }

            Layout.topMargin: Theme.padding
            Layout.fillWidth: true
            Layout.fillHeight: true

            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Theme.palette.dangerColor1
        }
    }
}
