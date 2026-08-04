import QtQuick
import QtQml
import QtQuick.Layouts
import QtQml.Models

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups.Dialog

import shared.controls
import utils

import SortFilterProxyModel

/*!
    Traffic of the QML network access manager, per host, split into what came
    from the network and what came from the cache. Counters are process-lifetime
    and reset on demand; they are not persisted, because a measurement run
    starts from a cold start anyway.
*/
StatusDialog {
    id: root

    implicitHeight: 610

    QtObject {
        id: d

        property var totals: ({networkRequests: 0, networkBytes: 0, cacheRequests: 0, cacheBytes: 0})
        property var cache: ({directory: "", size: 0, maximumSize: 0})

        function formatBytes(bytes) {
            return Qt.locale().formattedDataSize(bytes, 2, Locale.DataSizeTraditionalFormat)
        }

        function summary(networkRequests, networkBytes, cacheRequests, cacheBytes) {
            return qsTr("network %1 in %2 req · cache %3 in %4 req")
                     .arg(formatBytes(networkBytes)).arg(networkRequests)
                     .arg(formatBytes(cacheBytes)).arg(cacheRequests)
        }

        //! Counters only: reads the in-memory tally, never touches the disk.
        function updateCounters() {
            const hosts = HttpStats.hosts()
            sourceModel.clear()
            for (let i = 0; i < hosts.length; i++)
                sourceModel.append(hosts[i])
            d.totals = HttpStats.totals()
        }

        //! Walks the cache directory, so it is driven by what the reader asked
        //! for — opening the screen, Refresh, a finished Clear — and never by
        //! the reply counter, which ticks several times a second while media
        //! loads and would re-measure tens of thousands of files each time.
        function updateCacheInfo() {
            d.cache = HttpStats.cache()
        }

        function updateAll() {
            updateCounters()
            updateCacheInfo()
        }
    }

    // The counter emits on every finished reply; coalesce so the list does not
    // rebuild once per image.
    Timer {
        id: refreshTimer
        interval: 500
        onTriggered: d.updateCounters()
    }

    Connections {
        target: HttpStats
        function onChanged() {
            if (!refreshTimer.running)
                refreshTimer.start()
        }
        function onCacheCleared() {
            d.updateCacheInfo()
        }
    }

    contentItem: ColumnLayout {
        spacing: 0

        StatusBaseText {
            Layout.fillWidth: true
            Layout.bottomMargin: 8

            text: qsTr("Total: %1").arg(d.summary(d.totals.networkRequests, d.totals.networkBytes,
                                                  d.totals.cacheRequests, d.totals.cacheBytes))
            font.pixelSize: Theme.additionalTextSize
            font.bold: true
            wrapMode: Text.WordWrap
        }

        // Outside the bar: StatusProgressBar's own label hides when it does not fit.
        StatusBaseText {
            Layout.fillWidth: true
            Layout.bottomMargin: 4

            text: qsTr("Disk cache: %1 of %2")
                    .arg(d.formatBytes(d.cache.size))
                    .arg(d.formatBytes(d.cache.maximumSize))
            font.pixelSize: Theme.additionalTextSize
        }

        StatusProgressBar {
            Layout.fillWidth: true
            Layout.bottomMargin: 4

            from: 0
            to: Math.max(d.cache.maximumSize, 1)
            value: Math.min(d.cache.size, d.cache.maximumSize)
            fillColor: Theme.palette.primaryColor1
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.bottomMargin: 12

            text: d.cache.directory
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.baseColor1
            elide: Text.ElideMiddle
        }

        SearchBox {
            id: searchBox

            Layout.fillWidth: true
            Layout.bottomMargin: 16
        }

        StatusListView {
            id: resultsListView

            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            ListModel {
                id: sourceModel
            }

            model: SortFilterProxyModel {
                sourceModel: sourceModel

                // Already ordered by HttpStats::hosts() (network + cache bytes).
                filters: SearchFilter {
                    roleName: "host"
                    searchPhrase: searchBox.text
                }
            }

            delegate: StatusListItem {
                width: ListView.view.width
                title: model.host
                subTitle: d.summary(model.networkRequests, model.networkBytes,
                                    model.cacheRequests, model.cacheBytes)
                enabled: false
            }

            Component.onCompleted: d.updateAll()
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.topMargin: 8

            text: qsTr("Not counted here: status-go, messaging, the webviews, and requests made outside the QML network access manager.")
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.baseColor1
            wrapMode: Text.WordWrap
        }
    }

    footer: StatusDialogFooter {
        leftButtons: ObjectModel {
            StatusButton {
                text: qsTr("Refresh")
                onClicked: d.updateAll()
            }
            StatusButton {
                text: qsTr("Reset")
                onClicked: {
                    // Counters only: reset does not touch the cache, so there is
                    // nothing new to measure on disk.
                    HttpStats.reset()
                    d.updateCounters()
                }
            }
            StatusButton {
                text: qsTr("Clear cache")
                // No refresh here on purpose: the cache empties on its own
                // thread and reports back through onCacheCleared, so refreshing
                // now would measure the directory before the clear happened.
                onClicked: HttpStats.clearCache()
            }
        }

        rightButtons: ObjectModel {
            CopyToClipBoardButton {
                onCopyClicked: ClipboardUtils.setText(textToCopy)
                onPressed: function() {
                    let copiedText = qsTr("Total") + '\t'
                            + d.summary(d.totals.networkRequests, d.totals.networkBytes,
                                        d.totals.cacheRequests, d.totals.cacheBytes) + '\n' + '\n'
                    for (let i = 0; i < resultsListView.model.count; i++) {
                        const item = resultsListView.model.get(i)
                        copiedText += item.host + '\t'
                                + d.summary(item.networkRequests, item.networkBytes,
                                            item.cacheRequests, item.cacheBytes) + '\n'
                    }
                    textToCopy = copiedText
                }
            }
        }
    }
}
