import QtQuick
import QtQuick.Controls
import QtQml
import QtQml.Models

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import utils

import QtModelsToolkit

import "../controls"

StatusListView {
    id: root
    /**
      Model is expected to be sorted by layer
      Expected model structure:
        chainName      [string]          - chain long name. e.g. "Ethereum" or "Optimism"
        chainId        [int]             - chain unique identifier
        iconUrl        [string]          - SVG icon name. e.g. "network/ethereum"
        layer          [int]             - chain layer. e.g. 1 or 2
        isTest         [bool]            - true if the chain is a testnet
    **/
    property bool disableChainsWithNoCommunitiesSupport: false
    property bool showIndicator: true
    property bool multiSelection: false
    property bool selectOnlyClickedNetworkWhenAllSelected: false
    property bool selectionAllowed: true
    property bool showNewChainIcon: false

    /**
        The list selected of chain ids
        It is a read/write property
        WARNING: Update the array, not the internal content
    **/
    property var selection: []

    signal toggleNetwork(int chainId, int index)

    objectName: "networkSelectorList"
    implicitWidth: 300
    implicitHeight: contentHeight

    spacing: 4
    delegate: NetworkSelectItemDelegate {
        id: delegateItem

        required property var model
        required property int index

        autoExclusive: !root.multiSelection

        objectName: "networkSelectorDelegate_" + model.chainName
        width: ListView.view.width
        text: model.chainName
        icon.source: Assets.svg(model.iconUrl)
        showIndicator: root.showIndicator
        interactive: root.selectionAllowed && (!root.disableChainsWithNoCommunitiesSupport || model.communitiesSupported)
        showNewIcon: root.showNewChainIcon && Constants.chains.newChains.indexOf(model.chainId) >= 0

        checked: root.selection.includes(model.chainId)

        onToggled: {
            d.onToggled(checked, model.chainId)
            root.toggleNetwork(model.chainId, index)
        }
    }

    QtObject {
        id: d
        readonly property int networksCount: root.model.ModelCount.count
        // Handle multiple property changes from single changed signal
        property var combinedPropertyChangedHandler: [
            root.selection,
            root.multiSelection,
            d.networksCount]
        onCombinedPropertyChangedHandlerChanged: d.reprocessSelection()

        function onToggled(checked, chainId) {
            let selection = [...root.selection]
            if (root.multiSelection && root.selectOnlyClickedNetworkWhenAllSelected
                    && selection.length === d.networksCount) {
                selection = [chainId]
            } else if (checked) {
                if (!root.multiSelection)
                    selection = []

                selection.push(chainId)
            } else if (root.multiSelection) {
                selection = selection.filter((id) => id !== chainId)
            }

            d.commitSelection(selection)
        }

        function reprocessSelection() {
            // an empty model (still loading or resetting) cannot validate the
            // selection; keep it untouched until rows are available again
            if (d.networksCount === 0)
                return

            let selection = root.selection

            if (!root.multiSelection) {
                // One and only one chain must be selected
                if (selection.length === 0) {
                    selection = [ModelUtils.get(root.model, 0, "chainId")]
                } else if (selection.length > 1) {
                    console.warn("Warning: Multi-selection is disabled, but multiple items are selected. Automatically selecting the first inserted item.")
                    selection = [selection[0]]
                }
            }

            d.commitSelection(selection)
        }

        // in-place commit: swapping the array pointer would detach literal
        // bindings installed on `selection` by the owner of this view
        function commitSelection(newSelection) {
            if (JSON.stringify(root.selection) === JSON.stringify(newSelection))
                return
            root.selection.splice(0, root.selection.length, ...newSelection)
            root.selectionChanged()
        }
    }
}
