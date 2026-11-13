import QtQuick
import QtTest

import StatusQ.Components
import StatusQ.Core.Theme
import Benchmark
import Storybook.Testing

// Isolates the QML opt-in cost using the same C++ renderer in every variant.
// The baseline is the text-message QML snapshot before inline-link support.
Item {
    id: root
    width: 1000
    height: 800

    readonly property string variant: (Qt.application.arguments.find(arg => arg.startsWith("Bench::test_")) || "Bench::test_plain").split("test_")[1]
    readonly property string url: variant === "thread"
        ? "https://status.app/g/?a2=travel-group&thread-id=release-thread"
        : "https://status.app/u#zQ3shwQPhRuDJSjVGVBnTjCdgXy5i9WQaeVPdGJD6yTarJQSj"
    readonly property string source: "Hello **team**, please contact " + url + " before the next release."
    readonly property var links: variant === "profile"
        ? ({[url]: {title: "JohnDoe.ETH"}})
        : variant === "thread"
            ? ({[url]: {title: "Status App", path: [{text: "# feedback-desktop"}, {text: "Release summary", icon: "thread"}], trailingIcons: ["chat"]}})
            : ({})
    readonly property MessageTextAppearance appearance: MessageTextAppearance { theme: root.Theme }

    Component {
        id: baselineComponent
        BaselineTextMessage {
            width: runner.cellWidth
            appearance: root.appearance
            messageDetails: StatusMessageDetails { unparsedText: root.source }
        }
    }
    Component {
        id: currentComponent
        BenchmarkTextMessage {
            width: runner.cellWidth
            appearance: root.appearance
            messageDetails: StatusMessageDetails {
                unparsedText: root.source
                inlineLinks: root.links
            }
        }
    }

    BenchmarkRunner {
        id: runner
        anchors.fill: parent
        count: 200
        cellWidth: 300
        cellHeight: 150
        scenarios: ["static", "scroll"]
        delegate: Loader {
            required property int index
            width: runner.cellWidth
            height: runner.cellHeight
            sourceComponent: root.variant === "baseline" ? baselineComponent : currentComponent
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown && runner.result !== null
        onWindowShownChanged: {
            if (windowShown)
                runner.start()
        }

        function report() {
            verify(runner.result.valid)
            compare(runner.result.build.ready, runner.count)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
        function test_baseline() { report() }
        function test_plain() { report() }
        function test_profile() { report() }
        function test_thread() { report() }
    }
}
