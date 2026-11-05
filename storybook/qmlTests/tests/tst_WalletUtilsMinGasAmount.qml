import QtQuick
import QtTest

import AppLayouts.Wallet

TestCase {
    name: "WalletUtilsMinGasAmount"

    function test_minGasAmountFromSuggested_data() {
        return [
            // status-go: suggested = floor(raw * factor); expected = raw
            // Sepolia USDC to a first-time holder: floor(154,139 * 1.05) = 161,845
            { tag: "same-chain transfer uses 1.05", suggested: "161845", fromChain: 11155111, toChain: 11155111,
              isApproval: false, expected: "154139" },
            // ETH to a new address: floor(207,391 * 1.05) = 217,760
            { tag: "same-chain ETH send", suggested: "217760", fromChain: 1, toChain: 1,
              isApproval: false, expected: "207391" },
            // non-divisible: floor(21,001 * 1.05) = 22,051
            { tag: "same-chain non-divisible", suggested: "22051", fromChain: 1, toChain: 1,
              isApproval: false, expected: "21001" },
            // divisible: 21,000 * 1.05 = 22,050
            { tag: "same-chain divisible", suggested: "22050", fromChain: 1, toChain: 1,
              isApproval: false, expected: "21000" },
            // divisible: 200,000 * 1.2 = 240,000
            { tag: "bridge uses 1.2", suggested: "240000", fromChain: 1, toChain: 10,
              isApproval: false, expected: "200000" },
            // non-divisible: floor(200,001 * 1.2) = 240,001
            { tag: "bridge non-divisible", suggested: "240001", fromChain: 1, toChain: 10,
              isApproval: false, expected: "200001" },
            // approvals use 1.05 even on a bridge path: floor(46,001 * 1.05) = 48,301
            { tag: "approval uses 1.05 on a bridge path", suggested: "48301", fromChain: 1, toChain: 10,
              isApproval: true, expected: "46001" },
            { tag: "approval uses 1.05 on a same-chain path", suggested: "48300", fromChain: 1, toChain: 1,
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

    // Mirrors status-go's uint64(float64(raw) * factor) (JS numbers are float64 too) and checks
    // the helper recovers every raw estimate exactly.
    function test_minGasAmountRoundTrip() {
        const cases = [ { factor: 1.05, fromChain: 1, toChain: 1, isApproval: false },
                        { factor: 1.2, fromChain: 1, toChain: 10, isApproval: false },
                        { factor: 1.05, fromChain: 1, toChain: 10, isApproval: true } ]
        for (const c of cases) {
            for (let raw = 12000; raw < 22000; ++raw)
                checkRoundTrip(raw, c)
            for (let raw = 4294000000; raw < 4294001000; ++raw)
                checkRoundTrip(raw, c)
        }
    }

    function checkRoundTrip(raw, c) {
        const suggested = Math.floor(raw * c.factor).toString()
        const min = WalletUtils.minGasAmountFromSuggested(suggested, c.fromChain, c.toChain, c.isApproval)
        if (min !== raw.toString())
            fail("factor %1: raw %2 -> suggested %3 -> %4".arg(c.factor).arg(raw).arg(suggested).arg(min))
    }
}
