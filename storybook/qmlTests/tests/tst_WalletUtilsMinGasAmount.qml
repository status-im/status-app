import QtQuick
import QtTest

import AppLayouts.Wallet

TestCase {
    name: "WalletUtilsMinGasAmount"

    function test_minGasAmountFromSuggested_data() {
        return [
            // Sepolia USDC to a first-time holder: raw ~154,138 * 1.05 = 161,845
            { tag: "same-chain transfer uses 1.05", suggested: "161845", fromChain: 11155111, toChain: 11155111,
              isApproval: false, expected: "154138" },
            // ETH to a new address: 217,760 / 1.05 = 207,390.48, rounded down to 207,390
            { tag: "same-chain ETH send", suggested: "217760", fromChain: 1, toChain: 1,
              isApproval: false, expected: "207390" },
            { tag: "bridge uses 1.2", suggested: "240000", fromChain: 1, toChain: 10,
              isApproval: false, expected: "200000" },
            { tag: "approval is not buffered", suggested: "46000", fromChain: 1, toChain: 10,
              isApproval: true, expected: "46000" },
            { tag: "unknown suggestion", suggested: "", fromChain: 1, toChain: 1,
              isApproval: false, expected: "" },
            { tag: "malformed suggestion", suggested: "abc", fromChain: 1, toChain: 1,
              isApproval: false, expected: "" },
        ]
    }

    function test_minGasAmountFromSuggested(data) {
        compare(WalletUtils.minGasAmountFromSuggested(data.suggested, data.fromChain, data.toChain, data.isApproval),
                data.expected)
    }
}
