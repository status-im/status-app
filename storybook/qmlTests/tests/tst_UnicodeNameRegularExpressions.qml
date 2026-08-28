import QtQuick
import QtTest

import StatusQ.Controls
import StatusQ.Controls.Validators

import shared.validators
import utils

// Guards the app-wide "names in any language" rules from Constants.regularExpressions:
// the expressions use Unicode property classes (\p{L}, \p{M}, \p{N}, ...) and are evaluated by
// PCRE2 through StatusRegularExpressionValidator. Each case lists what every rule must accept
// and reject.
Item {
    id: root

    width: 400
    height: 200

    Component {
        id: inputComponent

        StatusInput {
            property alias regularExpression: regexValidator.regularExpression

            width: 300
            validationMode: StatusInput.ValidationMode.Always
            validators: [
                StatusRegularExpressionValidator {
                    id: regexValidator
                    errorMessage: "invalid"
                }
            ]
        }
    }

    TestCase {
        name: "UnicodeNameRegularExpressions"
        when: windowShown

        // the regex rule of the real display name validator list (the other rules need stores)
        readonly property var displayNameRegexValidator: displayNameValidators.validators.find(v => v.name === "regex")

        DisplayNameValidators { id: displayNameValidators }

        readonly property var anyScriptWords: [
            "Latin", "Саша", "Saša", "Їжак", "Straße", "Élodie", "Αλέξανδρος",
            "我的钱包", "ワレット", "지갑", "محفظتي", "שלי", "मेरा", "กระเป๋า", "tôi", "٣٤٥"
        ]

        function isValid(regularExpression, text) {
            const input = createTemporaryObject(inputComponent, root, { regularExpression })
            verify(!!input)
            input.text = text
            input.validate(true)
            return input.valid
        }

        function verifyAll(regularExpression, texts, expectedValid, ruleName) {
            for (const text of texts) {
                compare(isValid(regularExpression, text), expectedValid,
                        `${ruleName}: "${text}" expected ${expectedValid ? "valid" : "invalid"}`)
            }
        }

        function test_rules_data() {
            const re = Constants.regularExpressions
            return [
                {
                    tag: "alphanumerical",
                    re: re.alphanumerical,
                    valid: anyScriptWords.concat(["abc123", ""]),
                    invalid: ["a b", "a-b", "a_b", "a.b", "a!", "🙂"]
                },
                {
                    tag: "alphanumericalExpanded (community/channel/category/token name)",
                    re: re.alphanumericalExpanded,
                    valid: anyScriptWords.concat(["Саша Ђенић", "my-community_1.0", " leading", "trailing ", ""]),
                    invalid: ["a&b", "a,b", "a!", "我的钱包。", "🙂"]
                },
                {
                    tag: "alphanumericalExpanded1 (saved address name, search)",
                    re: re.alphanumericalExpanded1,
                    valid: anyScriptWords.concat(["Саша Ђенић", "my-name_1"]),
                    invalid: ["", " leading", "trailing ", "double  space", "a.b", "a!", "🙂"]
                },
                {
                    tag: "alphanumericalExpanded2 (group chat name)",
                    re: re.alphanumericalExpanded2,
                    valid: anyScriptWords.concat(["Саша & Ђенић", "a-b_c.d", ""]),
                    invalid: ["a,b", "a!", "🙂"]
                },
                {
                    tag: "alphanumericalExpanded3 (channel description)",
                    re: re.alphanumericalExpanded3,
                    valid: anyScriptWords.concat(["Саша, Ђенић & co.", ""]),
                    invalid: ["a!", "line\nbreak", "🙂"]
                },
                {
                    tag: "alphanumericalExpanded4 (community description)",
                    re: re.alphanumericalExpanded4,
                    valid: anyScriptWords.concat(["Саша, Ђенић & co.", "line\nbreak", "crlf\r\nbreak", ""]),
                    invalid: ["a!", "🙂"]
                },
                {
                    tag: "alphanumericalWithSpace (wallet account name)",
                    re: re.alphanumericalWithSpace,
                    valid: anyScriptWords.concat(["Саша Ђенић", "Straße Ärger Öl", "財布 ワレット", "Account 1", ""]),
                    invalid: ["a-b", "a_b", "a.b", "Саша!", "我的钱包。", "🙂"]
                },
                {
                    tag: "textWithEmoji (profile bio, token description)",
                    re: re.textWithEmoji,
                    valid: anyScriptWords.concat(["Hello, world! #1 (ok) - 100% <b>", "Саша!? 我的钱包。 ¿Qué?",
                                                  "🙂", "👨‍👩‍👧‍👦 🇷🇸 👍🏽", "line\nbreak", ""]),
                    invalid: ["", "￾"]
                },
                {
                    tag: "ascii (unchanged, ASCII-only)",
                    re: re.ascii,
                    valid: ["abc 123 !@#", ""],
                    invalid: ["Саша", "Straße", "我"]
                },
                {
                    tag: "capitalOnly (token symbol, unchanged)",
                    re: re.capitalOnly,
                    valid: ["ABC", ""],
                    invalid: ["abc", "САША", "A1"]
                },
                {
                    tag: "numerical (unchanged, ASCII digits only)",
                    re: re.numerical,
                    valid: ["0123", ""],
                    invalid: ["١٢٣", "1a", "1.0"]
                },
                {
                    tag: "keypairName validator",
                    re: /^[\p{L}\p{M}\p{N}\-_ ]+$/,
                    valid: anyScriptWords.concat(["Кључ-1 main_key"]),
                    invalid: ["", "a.b", "Саша!", "🙂"]
                },
                {
                    tag: "displayName validator",
                    re: displayNameRegexValidator.regularExpression,
                    valid: anyScriptWords.concat(["Саша Ђенић", "Straße Ärger Öl", "財布 ワレット", "my_name-1", ""]),
                    invalid: ["a.b", "Саша!", "我的钱包。", "🙂"]
                },
            ]
        }

        function test_rules(data) {
            verifyAll(data.re, data.valid, true, data.tag)
            verifyAll(data.re, data.invalid, false, data.tag)
        }

        function test_keypairNameValidatorMatchesConstants() {
            // Constants.validators.keypairName is a validator list; make sure its regex rule is the one tested above
            const regexValidators = Constants.validators.keypairName.filter(v => v.name === "regex")
            compare(regexValidators.length, 1)
            compare(regexValidators[0].regularExpression.toString(), (/^[\p{L}\p{M}\p{N}\-_ ]+$/).toString())
        }
    }
}
