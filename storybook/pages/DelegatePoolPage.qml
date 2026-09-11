import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ

SplitView {
    id: root

    QtObject {
        id: d
        property var acquired: []
    }

    DelegatePool {
        id: pool
        backgroundIntervalMs: intervalSlider.value

        DelegatePoolKind {
            id: cardKind
            kind: "card"
            target: 8
            delegate: Component {
                Rectangle {
                    width: 140
                    height: 72
                    radius: 8
                    color: "#4360df"
                    border.color: "#2946c4"

                    Text {
                        anchors.centerIn: parent
                        color: "white"
                        text: "pooled item"
                    }
                }
            }
        }
    }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Flow {
            id: acquiredFlow
            anchors.fill: parent
            spacing: 8
        }
    }

    Pane {
        SplitView.preferredWidth: 320
        SplitView.fillHeight: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            Label {
                text: "ready %1 / target %2".arg(cardKind.readyCount).arg(cardKind.target)
            }

            ProgressBar {
                Layout.fillWidth: true
                from: 0
                to: cardKind.target
                value: cardKind.readyCount
            }

            Label {
                text: "boosted: %1, acquired: %2".arg(pool.boosted).arg(d.acquired.length)
            }

            RowLayout {
                Button {
                    text: "Acquire"
                    enabled: cardKind.readyCount > 0
                    onClicked: {
                        const item = pool.acquire("card")
                        if (!item)
                            return
                        item.parent = acquiredFlow
                        d.acquired = d.acquired.concat([item])
                    }
                }
                Button {
                    text: "Release"
                    enabled: d.acquired.length > 0
                    onClicked: {
                        const item = d.acquired[d.acquired.length - 1]
                        d.acquired = d.acquired.slice(0, -1)
                        pool.release(item)
                    }
                }
            }

            RowLayout {
                Button {
                    text: "Grow target +4"
                    onClicked: pool.setTarget("card", cardKind.target + 4)
                }
                Button {
                    text: "Boost to target"
                    onClicked: pool.boost("card", cardKind.target)
                }
            }

            Label {
                text: "background interval: %1 ms".arg(intervalSlider.value)
            }

            Slider {
                id: intervalSlider
                Layout.fillWidth: true
                from: 0
                to: 1000
                stepSize: 50
                value: 400
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
