import QtQuick
import QtTest

import AppLayouts.Profile.popups

Item {
    id: root

    width: 1024
    height: 768

    ListModel {
        id: tokensModel

        ListElement {
            name: "Ether"
            symbol: "ETH"
            image: ""
            chainId: 1
            chainName: "Ethereum"
            address: "0x0000000000000000000000000000000000000000"
            blockExplorerURL: "https://etherscan.io"
            isTest: false
        }
        ListElement {
            name: "USDC"
            symbol: "USDC"
            image: ""
            chainId: 1
            chainName: "Ethereum"
            address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
            blockExplorerURL: "https://etherscan.io"
            isTest: false
        }
    }

    Component {
        id: componentUnderTest

        TokenListPopup {
            destroyOnClose: false
            title: "Uniswap Token List"
            sourceImage: ""
            sourceUrl: "https://tokens.uniswap.org"
            sourceVersion: "11.6.0"
            updatedAt: 1710538948
            tokensListModel: tokensModel
        }
    }

    property TokenListPopup controlUnderTest: null

    SignalSpy {
        id: linkClickedSpy
        target: controlUnderTest
        signalName: "linkClicked"
    }

    TestCase {
        name: "TokenListPopup"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root);
            linkClickedSpy.clear();
        }

        function cleanup() {
            if (controlUnderTest) {
                controlUnderTest.close();
                controlUnderTest.destroy();
                controlUnderTest = null;
            }
            linkClickedSpy.clear();
        }

        function openDialog() {
            verify(!!controlUnderTest);
            controlUnderTest.open();
            tryCompare(controlUnderTest, "opened", true);
        }

        function test_subtitle_shows_token_count() {
            openDialog();
            verify(controlUnderTest.subtitle.includes("2"));
        }

        function test_done_button_closes_dialog() {
            openDialog();

            const doneButton = findChild(controlUnderTest, "tokenListPopupDoneButton");
            verify(!!doneButton);

            mouseClick(doneButton);

            tryCompare(controlUnderTest, "opened", false);
        }

        function test_content_host_is_present() {
            openDialog();

            const contentHost = findChild(controlUnderTest, "statusAdaptiveDialogContentHost");
            verify(!!contentHost);
            verify(contentHost.visible);
        }

        function test_link_clicked_signal_emitted() {
            openDialog();

            controlUnderTest.linkClicked("https://etherscan.io/token/0x0000000000000000000000000000000000000000");

            compare(linkClickedSpy.count, 1);
            compare(linkClickedSpy.signalArguments[0][0],
                    "https://etherscan.io/token/0x0000000000000000000000000000000000000000");
        }
    }
}
