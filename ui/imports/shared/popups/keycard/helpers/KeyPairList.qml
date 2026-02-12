import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme

import utils

import SortFilterProxyModel

Control {
    id: root

    property var keyPairModel
    property ButtonGroup buttonGroup
    property bool disableSelectionForKeypairsWithNonDefaultDerivationPath: true
    property bool displayRadioButtonForSelection: true
    property bool useTransparentItemBackgroundColor: false
    property string optionLabel: ""
    property alias modelFilters: proxyModel.filters

    signal keyPairSelected(string keyUid)

    SortFilterProxyModel {
        id: proxyModel
        sourceModel: root.keyPairModel
    }

    implicitHeight: listView.contentHeight
    implicitWidth: listView.contentWidth

    contentItem: ListView {
        id: listView
        spacing: Theme.padding
        clip: true
        model: proxyModel
        delegate: KeyPairItem {
            width: ListView.view.width

            label: root.optionLabel
            buttonGroup: root.buttonGroup
            usedAsSelectOption: true
            canBeSelected: !root.disableSelectionForKeypairsWithNonDefaultDerivationPath ||
                           !model.keyPair.containsPathOutOfTheDefaultStatusDerivationTree()
            displayRadioButtonForSelection: root.displayRadioButtonForSelection
            useTransparentItemBackgroundColor: root.useTransparentItemBackgroundColor

            keyPairType: model.keyPair.pairType
            keyPairKeyUid: model.keyPair.keyUid
            keyPairName: model.keyPair.name
            keyPairIcon: model.keyPair.icon
            keyPairImage: model.keyPair.image
            keyPairDerivedFrom: model.keyPair.derivedFrom
            keyPairAccounts: model.keyPair.accounts

            onKeyPairSelected: {
                root.keyPairSelected(model.keyPair.keyUid)
            }
        }
    }
}
