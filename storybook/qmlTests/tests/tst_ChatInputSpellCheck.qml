import QtQuick
import QtTest
import StatusQ
import Storybook.Testing

Item {
    id: root
    width: 600
    height: 400
    TextDocumentTester { id: documentTester }

    Component {
        id: editorComponent
        TextEdit {
            id: documentEditor
            width: 500
            height: 300
            textFormat: TextEdit.PlainText
            property alias highlighter: highlighter
            ChatInputHighlighter {
                id: highlighter
                quickTextDocument: documentEditor.textDocument
                textColor: documentEditor.color
            }
        }
    }

    SignalSpy {
        id: finishedSpy
        signalName: "checkFinished"
    }

    TestCase {
        name: "ChatInputSpellCheck"
        when: windowShown
        property var editor
        property var checker

        function init() {
            editor = createTemporaryObject(editorComponent, root)
            verify(editor)
            checker = editor.highlighter.spellChecker
            finishedSpy.target = checker
            finishedSpy.clear()
        }

        function load(text, count) {
            finishedSpy.clear()
            editor.text = text
            tryVerify(() => finishedSpy.count > 0)
            compare(checker.issues.length, count)
        }

        function test_dictionaryAndPositions() {
            load("hello wrld ", 1)
            compare(checker.issues[0].start, 6)
            compare(checker.issues[0].length, 4)
            compare(checker.issues[0].word, "wrld")
        }

        function test_disabledDoesNotCheck() {
            checker.enabled = false
            editor.text = "wrld "
            compare(checker.checkPending, false)
            compare(finishedSpy.count, 0)
            compare(checker.issues.length, 0)
        }

        function test_underlinesPreserveFormatting() {
            load("**wrld** *wrngg* hello ", 2)
            tryVerify(() => documentTester.formatAt(editor.textDocument, 2).spelling === true)
            const bold = documentTester.formatAt(editor.textDocument, 2)
            verify(bold.bold)
            compare(bold.underlineColor, "#ff0000")
            const italic = documentTester.formatAt(editor.textDocument, 10)
            verify(italic.italic)
            verify(italic.spelling)
            checker.enabled = false
            tryVerify(() => !documentTester.formatAt(editor.textDocument, 2).spelling)
            verify(documentTester.formatAt(editor.textDocument, 2).bold)
        }

        function test_completedWords() {
            for (const letter of "wrld") {
                editor.insert(editor.length, letter)
                checker.cursorPosition = editor.length
                compare(checker.checkPending, false)
            }
            compare(checker.issues.length, 0)
            editor.insert(editor.length, " ")
            checker.cursorPosition = 5
            tryVerify(() => checker.issues.length === 1)
            checker.cursorPosition = 2
            compare(checker.issues.length, 1)
            checker.cursorPosition = 5
            compare(checker.issues.length, 1)
        }

        function test_underlineColorUpdatesExistingIssues() {
            load("**wrld** ", 1)
            compare(editor.highlighter.spellCheckUnderlineColor, "#ff0000")
            editor.highlighter.spellCheckUnderlineColor = "#12ab34"
            compare(documentTester.formatAt(editor.textDocument, 2).underlineColor, "#12ab34")
            verify(documentTester.formatAt(editor.textDocument, 2).bold)
            compare(checker.issues.length, 1)
            editor.highlighter.spellCheckUnderlineColor = "#ff0000"
            compare(documentTester.formatAt(editor.textDocument, 2).underlineColor, "#ff0000")
        }

        function test_underlinesPreserveTextColors() {
            editor.color = "#123456"
            editor.highlighter.quoteTextColor = "#654321"
            load("wrld\n> wrngg ", 2)
            tryVerify(() => documentTester.formatAt(editor.textDocument, 0).spelling === true)
            compare(documentTester.formatAt(editor.textDocument, 0).foreground, "#123456")
            compare(documentTester.formatAt(editor.textDocument, 7).foreground, "#654321")
            editor.color = "#abcdef"
            compare(documentTester.formatAt(editor.textDocument, 0).foreground, "#abcdef")
            compare(documentTester.formatAt(editor.textDocument, 7).foreground, "#654321")
            verify(documentTester.formatAt(editor.textDocument, 0).spelling)
            verify(documentTester.formatAt(editor.textDocument, 7).spelling)
        }

        function test_completionBoundaries_data() {
            return [{tag: "space", separator: " "}, {tag: "punctuation", separator: "."},
                    {tag: "newline", separator: "\n"}]
        }

        function test_completionBoundaries(data) {
            checker.cursorPosition = 5
            load("wrld" + data.separator, 1)
        }

        function test_editedWordCheckedWhenCaretLeaves() {
            load("world friend ", 0)
            checker.cursorPosition = 1
            editor.remove(1, 2)
            checker.cursorPosition = 1
            compare(checker.checkPending, false)
            compare(checker.issues.length, 0)
            checker.cursorPosition = 5
            tryVerify(() => checker.issues.length === 1)
            compare(checker.issues[0].word, "wrld")
        }

        function test_pastedWordIsCheckedImmediately() {
            checker.cursorPosition = 0
            editor.insert(0, "wrld")
            checker.cursorPosition = 4
            tryVerify(() => checker.issues.length === 1)
            compare(checker.issues[0].word, "wrld")
        }

        function test_caretMovementKeepsIssuesAndSuggestions() {
            load("hello wrld friend ", 1)
            checker.requestSuggestions(7)
            tryVerify(() => !checker.suggestionsPending)
            verify(checker.suggestions.indexOf("world") >= 0)
            finishedSpy.clear()
            for (let position = 0; position <= editor.length; ++position) {
                checker.cursorPosition = position
                compare(checker.issues.length, 1)
                compare(checker.suggestionWord, "wrld")
            }
            compare(checker.checkPending, false)
            compare(finishedSpy.count, 0)
            compare(checker.issues.length, 1)
        }

        function test_caretMovementWhileCheckPending() {
            editor.text = "hello wrld friend "
            checker.cursorPosition = 8
            tryVerify(() => finishedSpy.count > 0)
            compare(checker.issues.length, 1)
            compare(checker.issues[0].word, "wrld")
        }

        function test_lettersDoNotCheckOrClearOtherIssues() {
            load("wrld hello ", 1)
            finishedSpy.clear()
            for (const letter of "trpo") {
                editor.insert(editor.length, letter)
                checker.cursorPosition = editor.length
                compare(checker.checkPending, false)
                compare(checker.issues.length, 1)
                compare(checker.issues[0].word, "wrld")
                verify(documentTester.formatAt(editor.textDocument, 0).spelling)
            }
            checker.cursorPosition = 2
            compare(checker.issues.length, 1)
            tryVerify(() => checker.issues.length === 2)
            compare(checker.issues[0].word, "wrld")
            compare(checker.issues[1].word, "trpo")
            checker.cursorPosition = editor.length
            compare(checker.issues.length, 2)
        }

        function test_editBeforeIssueShiftsUnderlineWithoutChecking() {
            load("hello wrld ", 1)
            finishedSpy.clear()
            editor.insert(0, "a")
            checker.cursorPosition = 1
            compare(checker.issues.length, 1)
            compare(checker.issues[0].start, 7)
            compare(checker.checkPending, false)
            compare(finishedSpy.count, 0)
            verify(documentTester.formatAt(editor.textDocument, 7).spelling)
        }

        // A multi-character edit (paste, IME commit, undo) continuing a flagged word edits
        // that word, so its old underline must not be kept: it would end inside the new
        // word. An edit separated from the word by a boundary leaves the underline alone.
        function test_multiCharacterEditNextToIssue_data() {
            return [
                {tag: "joins suffix", position: 4, insertion: "xy", expected: "wrldxy ",
                    start: -1, word: "wrldxy"},
                {tag: "joins prefix", position: 0, insertion: "xy", expected: "xywrld ",
                    start: -1, word: "xywrld"},
                {tag: "separated suffix", position: 4, insertion: " xy", expected: "wrld xy ",
                    start: 0, word: "wrld"},
                {tag: "separated prefix", position: 0, insertion: "xy ", expected: "xy wrld ",
                    start: 3, word: "wrld"}
            ]
        }

        function test_multiCharacterEditNextToIssue(data) {
            load("wrld ", 1)
            editor.insert(data.position, data.insertion)
            compare(editor.text, data.expected)
            if (data.start < 0) {
                compare(checker.issues.length, 0)
                verify(!documentTester.formatAt(editor.textDocument, 0).spelling)
                tryVerify(() => checker.issues.length === 1)
            } else {
                compare(checker.issues.length, 1)
                compare(checker.issues[0].start, data.start)
            }
            compare(checker.issues[0].word, data.word)
        }

        function test_editingFlaggedWordRechecksIt_data() {
            return [
                {tag: "corrected suffix", text: "improv ", position: 6, insertion: "e",
                    removal: 0, expected: "improve ", issues: 0},
                {tag: "misspelled suffix", text: "threee ", position: 6, insertion: "e",
                    removal: 0, expected: "threeee ", issues: 1},
                {tag: "misspelled prefix", text: "improv ", position: 0, insertion: "a",
                    removal: 0, expected: "aimprov ", issues: 1},
                {tag: "corrected deletion", text: "threee ", position: 5, insertion: "",
                    removal: 1, expected: "three ", issues: 0},
                {tag: "misspelled middle", text: "wrld ", position: 2, insertion: "x",
                    removal: 0, expected: "wrxld ", issues: 1}
            ]
        }

        function test_editingFlaggedWordRechecksIt(data) {
            load(data.text, 1)
            checker.cursorPosition = data.position
            if (data.removal > 0)
                editor.remove(data.position, data.position + data.removal)
            else
                editor.insert(data.position, data.insertion)
            checker.cursorPosition = data.position + data.insertion.length
            compare(editor.text, data.expected)
            const length = data.expected.length - 1
            compare(checker.issues.length, 1, "the underline stays until the recheck")
            compare(checker.issues[0].start, 0)
            compare(checker.issues[0].length, length)
            verify(checker.checkPending)
            tryVerify(() => !checker.checkPending)
            compare(checker.issues.length, data.issues)
            tryVerify(() => {
                for (let position = 0; position < length; ++position) {
                    if ((documentTester.formatAt(editor.textDocument, position).spelling === true)
                            !== data.issues > 0)
                        return false
                }
                return true
            })
        }

        function test_exclusions() {
            load("NASA Londn iPhne v2ray MP3 v\u{1D7DA}ray `wrld` https://wrld.invalid\n```cpp\nwrld\n```\nhello ", 0)
            editor.text += "wrld "
            tryVerify(() => checker.issues.length === 1)
        }

        function test_linkLabelsAreChecked() {
            load("[wrld](https://wrld.invalid) ", 1)
            compare(checker.issues[0].start, 1)
        }

        function test_independentEditors() {
            const other = createTemporaryObject(editorComponent, root)
            verify(other)
            other.text = "wrngg "
            load("wrld ", 1)
            tryVerify(() => other.highlighter.spellChecker.issues.length === 1)
            compare(checker.issues[0].word, "wrld")
            compare(other.highlighter.spellChecker.issues[0].word, "wrngg")
            checker.enabled = false
            compare(other.highlighter.spellChecker.issues.length, 1)
        }

        function test_capitalizationConfigurable() {
            load("Londn NASA iPhne ", 0)
            checker.skipCapitalizedWords = false
            tryVerify(() => checker.issues.some(issue => issue.word === "Londn"))
        }

        function test_duplicateWords() {
            load("hello hello world. world ", 1)
            compare(checker.issues[0].word, "hello")
            compare(checker.issues[0].start, 6)
            compare(checker.issues[0].duplicate, true)
        }

        function test_disableAndUnsupportedLanguage() {
            load("wrld ", 1)
            checker.enabled = false
            compare(checker.issues.length, 0)
            checker.enabled = true
            tryVerify(() => checker.issues.length === 1)
            checker.language = "fr"
            compare(checker.issues.length, 0)
            checker.language = "en_US"
            tryVerify(() => checker.issues.length === 1)
        }

        function test_suggestionsAndUndo() {
            load("hello wrld friend ", 1)
            checker.requestSuggestions(7)
            tryVerify(() => !checker.suggestionsPending)
            verify(checker.suggestions.length > 0 && checker.suggestions.length <= 5)
            verify(checker.suggestions.indexOf("world") >= 0)
            const result = editor.highlighter.replaceSpellingSuggestion("world", 18, 18)
            compare(editor.text, "hello world friend ")
            compare(result.selectionStart, 19)
            editor.undo()
            compare(editor.text, "hello wrld friend ")
        }

        function test_staleSuggestions() {
            load("wrld ", 1)
            checker.requestSuggestions(1)
            editor.text = "hello "
            tryVerify(() => !checker.suggestionsPending)
            editor.highlighter.replaceSpellingSuggestion("world", 6, 6)
            compare(editor.text, "hello ")
            compare(checker.issues.length, 0)
        }

        function test_latestSuggestionRequestWins() {
            load("wrld wrngg ", 2)
            checker.requestSuggestions(1)
            checker.requestSuggestions(7)
            tryVerify(() => !checker.suggestionsPending)
            compare(checker.suggestionWord, "wrngg")
            compare(checker.suggestionStart, 5)
            checker.clearSuggestions()
            compare(checker.suggestions.length, 0)
        }

        function test_latestTextWins() {
            editor.text = "wrld ".repeat(2000)
            editor.text = "hello world "
            checker.enabled = false
            compare(checker.checkPending, false)
            compare(checker.issues.length, 0)
            checker.enabled = true
            finishedSpy.clear()
            tryVerify(() => finishedSpy.count > 0)
            compare(checker.issues.length, 0)
        }

        function test_unicodeOffsetsAndContractions() {
            load("😀 don't can't wrld ", 1)
            compare(checker.issues[0].start, 15)
        }

        function test_largeMessage_data() {
            return [{tag: "single paragraph", separator: " ", allMisspelled: false},
                    {tag: "many paragraphs", separator: "\n", allMisspelled: false},
                    {tag: "many misspellings", separator: "\n", allMisspelled: true}]
        }

        function test_largeMessage(data) {
            const text = data.allMisspelled ? "wrld\nwrngg\n".repeat(1000)
                       : ("hello" + data.separator + "world" + data.separator).repeat(999)
                         + "hello" + data.separator + "wrld" + data.separator
            const started = Date.now()
            load(text, data.allMisspelled ? 2000 : 1)
            tryVerify(() => documentTester.formatAt(editor.textDocument, text.lastIndexOf("wrld")).spelling === true)
            const elapsed = Date.now() - started
            verify(elapsed < 200, "2000-word completion-to-underline took " + elapsed + " ms (limit: 200 ms)")
        }
    }
}
