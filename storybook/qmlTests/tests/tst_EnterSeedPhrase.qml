import QtTest

import QtQuick
import StatusQ

import shared.panels

Item {
    id: root

    width: 600
    height: 400

    Component {
        id: enterSeedPhraseComponent

        EnterSeedPhrase {
            id: enterSeedPhrase

            anchors.fill: parent
            dictionary: ListModel {}

            readonly property SignalSpy acceptedSpy: SignalSpy {
                target: enterSeedPhrase
                signalName: "seedPhraseAccepted"
            }

            readonly property SignalSpy seedPhraseProvidedSpy: SignalSpy {
                target: enterSeedPhrase
                signalName: "seedPhraseProvided"
            }
        }
    }

    TestCase {
        name: "EnterSeedPhraseTest"
        when: windowShown

        property EnterSeedPhrase itemUnderTest: null

        function generateDictionaryVariation(baseDictionary) {
            let dictionaryVariation = baseDictionary.map((word) => word + "a")
            dictionaryVariation = baseDictionary.map((word) => word + "b").concat(dictionaryVariation)
            dictionaryVariation = baseDictionary.map((word) => word + "c").concat(dictionaryVariation)
            dictionaryVariation = baseDictionary.map((word) => word + "d").concat(dictionaryVariation)
            dictionaryVariation.sort()
            return dictionaryVariation
        }

        function init() {
            itemUnderTest = createTemporaryObject(enterSeedPhraseComponent, root)
            waitForItemPolished(itemUnderTest)
            waitForRendering(itemUnderTest)
        }

        // regression test for https://github.com/status-im/status-desktop/issues/16291
        function test_threeLetterPrefixSuggestionInput() {
            const commonPrefixToTest = "cat"

            //generate a seed phrase
            const expectedSeedPhrase = ["abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse", "access", commonPrefixToTest]
            const baseDictionary = [...expectedSeedPhrase, "cow", "catalog", "catch", "category", "cattle"]

            itemUnderTest.dictionary.append(baseDictionary.map((word) => ({seedWord: word})))

            //Type the seed phrase except the last word
            const str = expectedSeedPhrase.join(" ")
            for (let i = 0; i < str.length - commonPrefixToTest.length; i++) {
                keyPress(str.charAt(i))
            }

            const lastInputField = findChild(itemUnderTest, "enterSeedPhraseInputField12")
            verify(!!lastInputField)
            mouseClick(lastInputField)
            tryCompare(lastInputField, "activeFocus", true)

            // type the common prefix -> "cat..."
            keyClick(Qt.Key_C)
            keyClick(Qt.Key_A)
            keyClick(Qt.Key_T)
            tryCompare(lastInputField, "text", "cat")

            // hit Enter to accept "cat"
            keyClick(Qt.Key_Enter)

            // This signal is emitted one time when all words are provided
            tryCompare(itemUnderTest.seedPhraseProvidedSpy, "count", 1)

            itemUnderTest.setError("")

            // hit Enter to submit the form
            keyClick(Qt.Key_Enter)

            tryCompare(itemUnderTest.acceptedSpy, "count", 1)
        }

        function test_componentCreation() {
            verify(itemUnderTest !== null, "Component creation failed")
        }

        // Test seed phrase input by typing on the keyboard
        // The seed phrase is valid and the typing is done without any space between words
        // This is the most common way to input a seed phrase
        function test_seedPhraseKeyboardInput() {
            //generate a seed phrase
            const expectedSeedPhrase = ["abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse", "access", "accident"]
            expectedSeedPhrase.sort();

            itemUnderTest.dictionary.append(expectedSeedPhrase.map((word) => ({seedWord: word})))
            itemUnderTest.seedPhraseProvided.connect(() => itemUnderTest.setError(""))

            //Type the seed phrase. No space is needed between words
            const str = expectedSeedPhrase.join("")
            for (let i = 0; i < str.length; i++) {
                keyPress(str.charAt(i))
            }

            // This signal is emitted one time when all words are provided
            // (no additional enter is needed because provided word is not ambiguous)
            tryCompare(itemUnderTest.seedPhraseProvidedSpy, "count", 1)

            keyClick(Qt.Key_Enter)
            tryCompare(itemUnderTest.acceptedSpy, "count", 1)
        }

        // Test seed phrase input by typing on the keyboard
        // The seed phrase is valid and the typing is done with a space between words
        // The space between words is ignored and the seed should be valid
        function test_seedPhraseKeyboardInputWithExtraSpace() {
            //generate a seed phrase
            const expectedSeedPhrase = ["abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse", "access", "accident"]
            expectedSeedPhrase.sort();

            itemUnderTest.dictionary.append(expectedSeedPhrase.map((word) => ({seedWord: word})))
            itemUnderTest.seedPhraseProvided.connect(() => itemUnderTest.setError(""))

            //Type the seed phrase. A space is needed between words
            const str = expectedSeedPhrase.join(" ")
            for (let i = 0; i < str.length; i++) {
                keyPress(str.charAt(i))
            }

            // This signal is emitted once when all words are provided
            // (no additional enter is needed because provided word is not ambiguous)
            tryCompare(itemUnderTest.seedPhraseProvidedSpy, "count", 1)

            keyClick(Qt.Key_Enter)

            tryCompare(itemUnderTest.acceptedSpy, "count", 1)
        }

        // Test seed phrase input by pasting from clipboard
        // The seed phrase is valid and the clipboard seed is space separated
        function test_seedPhrasePaste() {
            //generate a seed phrase
            const expectedSeedPhrase = ["abandona", "abilityb", "ablec", "aboutd", "abovea", "absentb", "absorbc", "abstractd", "absurda", "abuseb", "accessc", "accidentd"]
            const baseDictionary = ["abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse", "access", "accident"]

            expectedSeedPhrase.sort();
            
            itemUnderTest.dictionary.append(expectedSeedPhrase.map((word) => ({seedWord: word})))
            itemUnderTest.seedPhraseProvided.connect(() => itemUnderTest.setError(""))

            ClipboardUtils.setText(expectedSeedPhrase.join(" "))

            // Trigger the paste action
            keySequence(StandardKey.Paste)

            // verify the last field has focus (https://github.com/status-im/status-desktop/issues/17105; issue 18)
            const lastInputField = findChild(itemUnderTest, "enterSeedPhraseInputField12")
            verify(!!lastInputField)
            tryCompare(lastInputField, "activeFocus", true)

            // This signal is emitted once when all words are provided
            // (no additional enter is needed because provided word is not ambiguous)
            tryCompare(itemUnderTest.seedPhraseProvidedSpy, "count", 1)

            keyClick(Qt.Key_Enter)
            tryCompare(itemUnderTest.acceptedSpy, "count", 1)
        }

        // Test the seed phrase by choosing from the suggestions
        // The seed phrase is valid and the user selects the words from the suggestions
        function test_seedPhraseChooseFromSuggestions() {
            //generate a seed phrase
            const expectedSeedPhrase = ["abandona", "abilityb", "ablec", "aboutd", "abovea", "absentb", "absorbc", "abstractd", "absurda", "abuseb", "accessc", "accidentd"]
            expectedSeedPhrase.sort()

            const baseDictionary = ["abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse", "access", "accident"]
            let dictionaryVariation = generateDictionaryVariation(baseDictionary)

            itemUnderTest.dictionary.append(dictionaryVariation.map((word) => ({seedWord: word})))
            itemUnderTest.seedPhraseProvided.connect(() => itemUnderTest.setError(""))

            // Suggestions dialog is expected to receive key events when there's multiple suggestions
            let downKeyEvents = 0
            for (let i = 0; i < expectedSeedPhrase.length; i++) {
                const input = findChild(itemUnderTest, "enterSeedPhraseInputField%1".arg(i+1))
                verify(!!input)
                tryCompare(input, "visible", true)
                tryCompare(input, "activeFocus", true)

                keySequence(expectedSeedPhrase[i].substring(0, 4).split('').join(','))

                const bar = findChild(input, "suggestionsBar")
                verify(!!bar)
                waitForRendering(bar)
                tryCompare(bar, "visible", true)

                const suggestion = findChild(bar, `seedWordSuggestion${downKeyEvents}`)
                verify(!!suggestion)
                waitForRendering(suggestion)
                tryCompare(suggestion, "visible", true)
                mouseMove(suggestion)
                mouseClick(suggestion)

                downKeyEvents = downKeyEvents === 3 ? 0 : downKeyEvents + 1
            }

            tryCompare(itemUnderTest.seedPhraseProvidedSpy, "count", 1)

            keyPress(Qt.Key_Enter)
            tryCompare(itemUnderTest.acceptedSpy, "count", 1)
        }

        // Test seed phrase input by typing on the keyboard
        // The seed phrase is invalidated by the external isSeedPhraseValid
        function test_invalidatedSeedPhraseKeyboardInput() {
            //generate a seed phrase
            const expectedSeedPhrase = ["abandona", "abilityb", "ablec", "aboutd", "abovea", "absentb", "absorbc", "abstractd", "absurda", "abuseb", "accessc", "accidentd"]
            expectedSeedPhrase.sort()

            const baseDictionary = ["abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse", "access", "accident"]
            let dictionaryVariation = generateDictionaryVariation(baseDictionary)

            itemUnderTest.dictionary.append(dictionaryVariation.map((word) => ({seedWord: word})))
            itemUnderTest.seedPhraseProvided.connect(() => itemUnderTest.setError("error"))

            //Type the seed phrase
            const str = expectedSeedPhrase.join("")
            for (let i = 0; i < str.length; i++) {
                keyPress(str.charAt(i))
            }

            tryCompare(itemUnderTest.seedPhraseProvidedSpy, "count", 1)

            keyClick(Qt.Key_Enter)
            verify(itemUnderTest.acceptedSpy.count === 0, "submitSeedPhrase signal was emitted")
        }

        // Test seed phrase input by pasting from clipboard
        // The seed phrase is invalidated by the external isSeedPhraseValid
        function test_invalidatedSeedPhrasePaste() {
            //generate a seed phrase
            const expectedSeedPhrase = ["abandona", "abilityb", "ablec", "aboutd", "abovea", "absentb", "absorbc", "abstractd", "absurda", "abuseb", "accessc", "accidentd"]
            expectedSeedPhrase.sort()

            const baseDictionary = ["abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse", "access", "accident"]
            let dictionaryVariation = generateDictionaryVariation(baseDictionary)

            itemUnderTest.dictionary.append(dictionaryVariation.map((word) => ({seedWord: word})))
            itemUnderTest.seedPhraseProvided.connect(() => itemUnderTest.setError("error"))

            ClipboardUtils.setText(expectedSeedPhrase.join(" "))

            // Trigger the paste action
            keyClick("v", Qt.ControlModifier)

            tryCompare(itemUnderTest.seedPhraseProvidedSpy, "count", 1)

            keyClick(Qt.Key_Enter)
            verify(itemUnderTest.acceptedSpy.count === 0, "submitSeedPhrase signal was emitted")
        }

        // Test seed phrase input by typing on the keyboard
        // The seed phrase is invalid due to the length
        function test_invalidLengthSeedPhrase() {
            const expectedSeedPhrase = ["abandona", "abilityb", "ablec"]
            expectedSeedPhrase.sort()

            const baseDictionary = ["abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse", "access", "accident"]
            let dictionaryVariation = generateDictionaryVariation(baseDictionary)

            itemUnderTest.dictionary.append(dictionaryVariation.map((word) => ({seedWord: word})))

            //Type the seed phrase
            const str = expectedSeedPhrase.join("")
            for (let i = 0; i < str.length; i++) {
                keyPress(str.charAt(i))
            }

            verify(itemUnderTest.seedPhraseProvidedSpy.count === 0)

            keyClick(Qt.Key_Enter)
            verify(itemUnderTest.acceptedSpy.count === 0, "submitSeedPhrase signal was emitted")
        }

        // Test seed phrase input by typing on the keyboard
        // The seed phrase is invalid due to the dictionary word
        function test_invalidDictionarySeedPhrase() {
            const expectedSeedPhrase = ["abandonna", "abilityb", "ablec", "aboutd", "abovea", "absentb", "absorbc", "abstractd", "absurda", "abuseb", "accessc", "accidentd"]
            //                              ^^ invalid word
            expectedSeedPhrase.sort()

            const baseDictionary = ["abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse", "access", "accident"]
            let dictionaryVariation = generateDictionaryVariation(baseDictionary)

            itemUnderTest.dictionary.append(dictionaryVariation.map((word) => ({seedWord: word})))
            itemUnderTest.seedPhraseProvided.connect(() => itemUnderTest.setError(""))

            //Type the seed phrase
            const str = expectedSeedPhrase.join("")
            for (let i = 0; i < str.length; i++) {
                keyPress(str.charAt(i))
                if (i === 8) {
                    // The first word is invalid. Move on to the next word
                    keyPress(Qt.Key_Tab)
                }
            }

            keyClick(Qt.Key_Enter)
            verify(itemUnderTest.acceptedSpy.count === 0, "submitSeedPhrase signal was emitted")
            verify(itemUnderTest.seedPhraseProvidedSpy.count === 0, "seedPhraseUpdate signal was emitted")
        }

        // Test suggestions are active after the seed phrase word is updated
        function test_suggestionsActiveAfterUpdatingWord() {
            const expectedSeedPhrase = ["abandona", "abilityb", "ablec", "aboutd", "abovea", "absentb", "absorbc", "abstractd", "absurda", "abuseb", "accessc", "accidentd"]
            expectedSeedPhrase.sort()

            const baseDictionary = ["abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse", "access", "accident"]
            let dictionaryVariation = generateDictionaryVariation(baseDictionary)

            let lastVerifiedSeedPhrase = ""

            itemUnderTest.dictionary.append(dictionaryVariation.map((word) => ({seedWord: word})))

            // Suggestions panel is expected to receive events when there's multiple suggestions
            let downKeyEvents = 0
            for (let i = 0; i < expectedSeedPhrase.length; i++) {
                const input = findChild(itemUnderTest, "enterSeedPhraseInputField%1".arg(i+1))
                verify(!!input)
                tryCompare(input, "visible", true)
                tryCompare(input, "activeFocus", true)

                keySequence(expectedSeedPhrase[i].substring(0, 4).split('').join(','))

                const bar = findChild(input, "suggestionsBar")
                waitForRendering(bar)

                const suggestion = findChild(bar, `seedWordSuggestion${downKeyEvents}`)
                mouseClick(suggestion)
            }

            const input = findChild(itemUnderTest, "enterSeedPhraseInputField12")
            verify(!!input)
            tryCompare(input, "visible", true)
            tryCompare(input, "activeFocus", true)

            const bar = findChild(input, "suggestionsBar")
            tryCompare(bar, "visible", false)

            keyPress(Qt.Key_Backspace)
            tryCompare(bar, "visible", true)
        }

        // Test suggestions are active after the seed phrase word is fixed
        function test_suggestionsActiveAfterFixingWord() {
            const expectedSeedPhrase = ["abandona", "abilityb", "ablec", "aboutd", "abovea", "absentb", "absorbc", "abstractd", "absurda", "abuseb", "accessc", "accidenntd"]
            expectedSeedPhrase.sort()

            const baseDictionary = ["abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse", "access", "accident"]
            let dictionaryVariation = generateDictionaryVariation(baseDictionary)

            itemUnderTest.dictionary.append(dictionaryVariation.map((word) => ({seedWord: word})))
            itemUnderTest.seedPhraseProvided.connect(() => itemUnderTest.setError(""))

            // Suggestions bar is expected to receive events when there's multiple suggestions
            let downKeyEvents = 0
            for (let i = 0; i < expectedSeedPhrase.length; i++) {
                const input = findChild(itemUnderTest, "enterSeedPhraseInputField%1".arg(i+1))
                verify(!!input)
                tryCompare(input, "visible", true)
                tryCompare(input, "activeFocus", true)

                keySequence(expectedSeedPhrase[i].substring(0, 4).split('').join(','))

                const bar = findChild(input, "suggestionsBar")
                waitForRendering(bar)

                const suggestion = findChild(bar, `seedWordSuggestion${downKeyEvents}`)
                mouseClick(suggestion)
            }

            keyPress(Qt.Key_Backspace)
            keyPress(Qt.Key_Backspace)

            const input = findChild(itemUnderTest, "enterSeedPhraseInputField12")
            verify(!!input)
            tryCompare(input, "visible", true)
            tryCompare(input, "activeFocus", true)

            const bar = findChild(input, "suggestionsBar")
            waitForRendering(bar)
            tryCompare(bar, "visible", true)

            keyClick(Qt.Key_Tab)
            keyClick(Qt.Key_Enter)

            tryCompare(itemUnderTest.seedPhraseProvidedSpy, "count", 2)
            tryCompare(itemUnderTest.acceptedSpy, "count", 1)
        }

        function test_doubleClickWordAndDelete_data() {
            return [
              { tag: "Delete", key: Qt.Key_Delete, resultText: "" },
              { tag: "Backspace", key: Qt.Key_Backspace, resultText: "" },
              { tag: "x", key: Qt.Key_X, resultText: "x" }, // overwrite the text with "x"
            ]
        }

        // regression test for: https://github.com/status-im/status-desktop/issues/17105 (issue 20)
        function test_doubleClickWordAndDelete(data) {
            //generate a seed phrase
            const expectedSeedPhrase = ["abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse", "access", "asphalt"]
            const baseDictionary = [...expectedSeedPhrase, "cow", "catalog", "catch", "category", "cattle"]

            itemUnderTest.dictionary.append(baseDictionary.map((word) => ({seedWord: word})))
            itemUnderTest.seedPhraseProvided.connect(() => itemUnderTest.setError(""))

            // Type the seed phrase. No space is needed between words
            const str = expectedSeedPhrase.join("")
            for (let i = 0; i < str.length; i++) {
                keyPress(str.charAt(i))
            }

            // move to the first field, double click to select the whole text there
            const firstInputField = findChild(itemUnderTest, "enterSeedPhraseInputField1")
            verify(!!firstInputField)
            mouseClick(firstInputField)
            mouseDoubleClickSequence(firstInputField)
            tryCompare(firstInputField, "activeFocus", true)
            tryCompare(firstInputField, "selectedText", expectedSeedPhrase[0])

            // try to delete or overwrite the selected text
            keyPress(data.key)
            tryCompare(firstInputField, "text", data.resultText)
            tryCompare(firstInputField, "selectedText", "")
        }
    }
}
