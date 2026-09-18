import QtQuick
import QtTest

import AppLayouts.Browser.adapters

TestCase {
    name: "BrowserUserAgent"

    function test_honestUserAgent_data() {
        return [
            {
                tag: "desktop Qt WebEngine drops its engine token",
                engine: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) QtWebEngine/6.11.0 Chrome/134.0.6998.208 Safari/537.36",
                version: "2.39.0",
                expected: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.6998.208 Safari/537.36 Status/2.39.0"
            },
            {
                tag: "Windows keeps its real platform",
                engine: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) QtWebEngine/6.11.0 Chrome/134.0.6998.208 Safari/537.36",
                version: "2.39.0",
                expected: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.6998.208 Safari/537.36 Status/2.39.0"
            },
            {
                tag: "Android WebView drops wv and Version/4.0",
                engine: "Mozilla/5.0 (Linux; Android 16; A059 Build/BP2A.250605.031.A3; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/140.0.7339.207 Mobile Safari/537.36",
                version: "2.39.0",
                expected: "Mozilla/5.0 (Linux; Android 16; A059 Build/BP2A.250605.031.A3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.7339.207 Mobile Safari/537.36 Status/2.39.0"
            },
            {
                tag: "iOS WKWebView gains the Safari token every iOS browser sends",
                engine: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
                version: "2.39.0",
                expected: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1 Status/2.39.0"
            },
            {
                tag: "build suffix is not part of the product version",
                engine: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) QtWebEngine/6.11.0 Chrome/134.0.6998.208 Safari/537.36",
                version: "2.39.0-rc.6-17-g35bc2a4eae",
                expected: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.6998.208 Safari/537.36 Status/2.39.0"
            },
            {
                tag: "leading v is dropped",
                engine: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.6998.208 Safari/537.36",
                version: "v2.40.1",
                expected: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.6998.208 Safari/537.36 Status/2.40.1"
            },
            {
                tag: "no version, no product token",
                engine: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.6998.208 Safari/537.36",
                version: "",
                expected: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.6998.208 Safari/537.36"
            },
            {
                // Not reported yet: an empty override leaves the engine's own string.
                tag: "unknown engine default stays empty",
                engine: "",
                version: "2.39.0",
                expected: ""
            }
        ]
    }

    function test_honestUserAgent(data) {
        compare(UserAgentUtils.honestUserAgent(data.engine, data.version), data.expected)
    }
}
