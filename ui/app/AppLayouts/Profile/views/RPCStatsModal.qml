import QtQuick
import QtQml
import QtQuick.Layouts
import QtQml.Models

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups.Dialog

import shared.controls
import utils

import QtModelsToolkit
import SortFilterProxyModel

import "../stores"


StatusDialog {
    id: root

    implicitHeight: 610

    property WalletStore walletStore

    QtObject {
        id: d

        property int totalCalls
        property int totalFilteredCalls: countAggregator.value

        function updateModel() {
            sourceModel.clear()

            const jsonStatsRaw = root.walletStore.getRpcStats()
            const jsonStats = JSON.parse(jsonStatsRaw)
            if (jsonStats.result && jsonStats.result.methods) {
                const methods = jsonStats.result.methods
                d.totalCalls = jsonStats.result.total

                for (const method in methods) {
                    sourceModel.append({ method: method, count: methods[method] })
                }
            }
        }

        function resetStats() {
            root.walletStore.resetRpcStats()
            updateModel()
        }
    }

    contentItem: ColumnLayout {
        id: contentColumn

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

            header: StatusListItem {
                width: ListView.view.width
                title: qsTr("Total")
                statusListItemTitle.customColor: Theme.palette.directColor1
                statusListItemLabel.customColor: Theme.palette.directColor1
                label: qsTr("%1 of %2").arg(d.totalFilteredCalls).arg(d.totalCalls)
                enabled: false
                z: 3 // Above delegate (z=1) and above section.delegate (z = 2)
            }
            headerPositioning: ListView.OverlayHeader

            model: SortFilterProxyModel {
                sourceModel: sourceModel
                sorters: RoleSorter {
                    roleName: "count"
                    sortOrder: Qt.DescendingOrder
                }

                filters: FastExpressionFilter {
                    function spellingTolerantSearch(data, searchKeyword) {
                        const regex = new RegExp(searchKeyword.split('').join('.{0,1}'), 'i')
                        return regex.test(data)
                    }

                    enabled: !!searchBox.text
                    expression: {
                        searchBox.text
                        let keyword = searchBox.text.trim().toUpperCase()
                        return spellingTolerantSearch(model.method, keyword)
                    }
                    expectedRoles: ["method"]
                }
            }

            SumAggregator {
                id: countAggregator

                model: resultsListView.model
                roleName: "count"
            }

            delegate: StatusListItem {
                width: ListView.view.width
                title: model.method
                label: model.count
                enabled: false
            }

            Component.onCompleted: {
                d.updateModel()
            }
        }
    }

    footer: StatusDialogFooter {
        leftButtons: ObjectModel {
            StatusButton {
                text: qsTr("Refresh")
                onClicked: {
                    d.updateModel()
                }
            }
            StatusButton {
                text: qsTr("Reset")
                onClicked: {
                    root.walletStore.resetRpcStats()
                    d.updateModel()
                }
            }
        }

        rightButtons: ObjectModel {
            CopyToClipBoardButton {
                id: copyToClipboardButton

                onCopyClicked: ClipboardUtils.setText(textToCopy)
                onPressed: function() {
                    let copiedText = "Total" + '\t' + d.totalFilteredCalls + " of " + d.totalCalls + '\n' + '\n'
                    for (let i = 0; i < resultsListView.model.count; i++) {
                        const item = resultsListView.model.get(i)
                        copiedText += item.method + '\t' + item.count + '\n'
                    }
                    textToCopy = copiedText
                }
            }
        }
    }
}
