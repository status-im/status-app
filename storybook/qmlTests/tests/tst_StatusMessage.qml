import QtQuick
import QtTest
import QtQml.Models

import StatusQ.Components
import shared.status

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: componentUnderTest
        StatusMessage {
            anchors.fill: parent
            messageDetails {
                messageText: ""
                contentType: StatusMessage.ContentType.Text
                amISender: false
                sender.id: "zq123456790"
                sender.displayName: "Alice"
                sender.isContact: true
                sender.trustIndicator: StatusContactVerificationIcons.TrustedType.None
                sender.isEnsVerified: false
                sender.profileImage {
                    name: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAAiElEQVR4nOzXUQpAQBRGYWQvLNAyLJDV8C5qpiGnv/M9al5Ot27X0IUwhMYQGkNoDKGJCRlLH67bftx9X+ap/+P9VcxEDKExhKZ4a9Uq3TZviZmIITSG0DRvlqcbqVbrlouZiCE0htD4h0hjCI0hNN5aNIbQGKKPxEzEEBpDaAyhMYTmDAAA//+gYCErzmCpCQAAAABJRU5ErkJggg="
                    color: "red"
                }
            }
            linkAddressAndEnsName: true
            outgoingStatus: StatusMessage.OutgoingStatus.Sending
        }
    }

    property StatusMessage controlUnderTest: null

    TestCase {
        name: "StatusMessage"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }


        function test_different_address_formats_data() {
            return [
                        {messageText: "0x1234567890abcdef1234567890abcdef12345678", validAddressEnsCount: 1},   // Valid ETH address
                        {messageText: "0x1234567890abcdef1234567890abcdef12345678,
                                       0x16437e05858c1a34f0ae63c9ca960d61a5583d5e,
                                       0x75d5673fc25bb4993ea1218d9d415487c3656853", validAddressEnsCount: 3},   // Valid ETH address
                        {messageText: "0xAbCdEf1234567890abcdef1234567890AbCdEf12", validAddressEnsCount: 1},   // Valid ETH address
                        {messageText: "0x123", validAddressEnsCount: 0},                                        // Invalid ETH address (too short)
                        {messageText: "1234567890abcdef1234567890abcdef12345678", validAddressEnsCount: 0},     // Invalid ETH address (no 0x)
                        {messageText: "qwerty.stateofus.eth", validAddressEnsCount: 1},                         // Valid ETH address
                        {messageText: "alice.eth", validAddressEnsCount: 1},                                    // Valid ENS name
                        {messageText: "bob.eth", validAddressEnsCount: 1},                                      // Valid ENS name
                        {messageText: "sub.alice.eth", validAddressEnsCount: 1},                                // Valid ENS name with subdomain
                        {messageText: "bob.stateofus.eth", validAddressEnsCount: 1},                            // Valid ENS name with subdomain
                        {messageText: "ens.sub.sub.eth", validAddressEnsCount: 1},                              // Valid ENS name with multiple subdomains
                        {messageText: "example.com", validAddressEnsCount: 0},                                  // Invalid DNS-based ENS name
                        {messageText: "another.example.xyz", validAddressEnsCount: 0},                          // Invalid DNS-based ENS name
                        {messageText: "my-site.io", validAddressEnsCount: 0},                                   // Invalid DNS-based ENS name
                        {messageText: "invalid.ethaddress", validAddressEnsCount: 0},                           // Invalid ENS-like name
                        {messageText: "bob.eth.invalid", validAddressEnsCount: 0},                              // Invalid ENS-like name (invalid TLD)
                        {messageText: "My wallet is 0x1234567890abcdef1234567890abcdef12345678, and my ENS is alice.eth.", validAddressEnsCount: 2},  // Valid ETH and ENS in sentence
                        {messageText: "You can find me at bob.eth or contact me via 0xAbCdEf1234567890abcdef1234567890AbCdEf12.", validAddressEnsCount: 2},  // Valid ETH and ENS in sentence
                        {messageText: "Invalid address: 0x12345 and valid ENS: sub.alice.eth.", validAddressEnsCount: 1},  // Mixed case with valid and invalid
                        {messageText: "Check 0x123GHIJKLMNOPQRSTUVWXYZ and visit example.com.", validAddressEnsCount: 0},  // Mixed case with valid DNS and invalid ETH
                        {messageText: "0x1234567890abcdef1234567890abcdef12345678, qwerty.stateofus.eth,  0x16437e05858c1a34f0ae63c9ca960d61a5583d5e, 0x75d5673fc25bb4993ea1218d9d415487c3656853", validAddressEnsCount: 4},   // Valid ETH address
                    ]
        }

        function test_different_address_formats(data) {
            verify(!!controlUnderTest)

            controlUnderTest.messageDetails.messageText = data.messageText
            waitForRendering(controlUnderTest)

            const statusTextMessage = findChild(controlUnderTest, "StatusMessage_textMessage")
            verify(!!statusTextMessage)

            // Use regular expression to match all <a> tags in the text
            var linkMatches = statusTextMessage.textField.text.match(/<a\b[^>]*>(.*?)<\/a>/gi)
            var actualLinkCount = linkMatches ? linkMatches.length : 0

            compare(actualLinkCount, data.validAddressEnsCount, "TextEdit should contain a link %1".arg(data.messageText))
        }
    }

    Component {
        id: editModeComponentUnderTest
        StatusMessage {
            anchors.fill: parent
            editMode: true
            messageDetails {
                messageText: "Hello world"
                contentType: StatusMessage.ContentType.Text
                amISender: true
                sender.id: "zq123456790"
                sender.displayName: "Alice"
                sender.isContact: true
                sender.trustIndicator: StatusContactVerificationIcons.TrustedType.None
                sender.isEnsVerified: false
                sender.profileImage {
                    name: ""
                    color: "red"
                }
            }
            linkAddressAndEnsName: true
            outgoingStatus: StatusMessage.OutgoingStatus.Sent
            reactionsModel: ListModel {
                ListElement {
                    emoji: "1f600"
                    didIReactWithThisEmoji: true
                    numberOfReactions: 1
                    jsonArrayOfUsersReactedWithThisEmoji: "[\"You\"]"
                }
            }
        }
    }

    SignalSpy {
        id: signalSpy

        function setup(target, signalName) {
            clear()
            signalSpy.target = target
            signalSpy.signalName = signalName
        }
    }

    TestCase {
        name: "StatusMessageEditMode"
        when: windowShown

        property StatusMessage controlUnderTest: null

        function init() {
            controlUnderTest = createTemporaryObject(editModeComponentUnderTest, root)
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
        }

        function cleanup() {
            signalSpy.target = null
            signalSpy.clear()
            if (controlUnderTest)
                controlUnderTest.destroy()
            controlUnderTest = null
        }

        function test_editMode_highlightsMessageAndKeepsTextVisible() {
            const statusTextMessage = findChild(controlUnderTest, "StatusMessage_textMessage")
            verify(!!statusTextMessage)
            verify(statusTextMessage.visible)
        }

        function test_editMode_headerStillVisible() {
            const displayName = findChild(controlUnderTest, "StatusMessageHeader_DisplayName")
            verify(!!displayName)
            verify(displayName.visible)
            compare(displayName.text, "You")
        }

        function test_editMode_showsReactionsBelowEditor() {
            const reactionsPanel = findChild(controlUnderTest, "statusMessageEmojiReactions")
            verify(!!reactionsPanel)
            verify(reactionsPanel.visible)
        }

    }
}
