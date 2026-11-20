import QtQuick
import QtTest

import StatusQ.Components
import StatusQ.Core.Theme
import Benchmark
import Storybook.Testing

// One benchmark iteration updates 200 existing messages synchronously.
// Native layout work is included; frame presentation is measured separately.
Item {
    id: root
    width: 1000
    height: 800

    property int revision: 0
    readonly property int count: 200
    readonly property string variant: (Qt.application.arguments.find(arg => arg.startsWith("BenchUpdates::benchmark_")) || "BenchUpdates::benchmark_plain").split("benchmark_")[1]
    readonly property string url: "https://status.app/u#zQ3shwQPhRuDJSjVGVBnTjCdgXy5i9WQaeVPdGJD6yTarJQSj"
    readonly property string source: "Hello **team**, please contact " + url + " before release " + revision + "."
    readonly property var links: variant === "profile"
        ? ({[url]: {title: "JohnDoe.ETH"}})
        : variant === "thread"
            ? ({[url]: {title: "Status App", path: [{text: "# feedback-desktop"}, {text: "Release summary", icon: "thread"}], trailingIcons: ["chat"]}})
            : ({})
    readonly property MessageTextAppearance appearance: MessageTextAppearance { theme: root.Theme }

    Component {
        id: baselineComponent
        BaselineTextMessage {
            width: 300
            appearance: root.appearance
            messageDetails: StatusMessageDetails { unparsedText: root.source }
        }
    }
    Component {
        id: currentComponent
        BenchmarkTextMessage {
            width: 300
            appearance: root.appearance
            messageDetails: StatusMessageDetails {
                unparsedText: root.source
                inlineLinks: root.links
            }
        }
    }

    Repeater {
        model: root.count
        delegate: Loader {
            required property int index
            sourceComponent: root.variant === "baseline" ? baselineComponent : currentComponent
        }
    }

    TestCase {
        name: "BenchUpdates"
        when: windowShown

        function benchmark_baseline() { ++root.revision }
        function benchmark_plain() { ++root.revision }
        function benchmark_profile() { ++root.revision }
        function benchmark_thread() { ++root.revision }
    }
}
