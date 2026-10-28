import QtQuick

import QtTest

import shared.popups.keycard_new.helpers 1.0

Item {
    id: root

    width: 400
    height: 200

    Component {
        id: componentUnderTest

        Item {
            property alias certificateTrusted: stateInfo.certificateTrusted
            readonly property alias warning: warning

            KeycardStateInfo {
                id: stateInfo
            }

            KeycardCertificateWarning {
                id: warning
                width: parent.width
                text: stateInfo.certificateWarning
            }
        }
    }

    TestCase {
        name: "KeycardCertificateWarning"
        when: windowShown

        function test_hiddenForATrustedCard() {
            const item = createTemporaryObject(componentUnderTest, root)
            verify(!!item)
            verify(!item.warning.visible)
            compare(item.warning.text, "")
        }

        function test_shownForACardFromAnUnknownCa() {
            const item = createTemporaryObject(componentUnderTest, root, { certificateTrusted: false })
            verify(!!item)
            verify(item.warning.visible)
            verify(item.warning.text.indexOf("development or custom-made card") >= 0)
        }
    }
}
