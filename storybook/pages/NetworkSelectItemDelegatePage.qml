import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme

import AppLayouts.Wallet.controls

import Models
import Storybook

import SortFilterProxyModel

import utils

SplitView {
    id: root

    Item {
        implicitWidth: delegate.width
        NetworkSelectItemDelegate {
            id: delegate
            title: "Ethereum"
            iconUrl: Assets.svg("network/ethereum")
            showIndicator: true
            multiSelection: true
            checkState: checkStateSelector.checkState
            nextCheckState: checkState === Qt.Unchecked ? Qt.PartiallyChecked :
                        checkState === Qt.PartiallyChecked ? Qt.Checked : Qt.Unchecked

            onCheckStateChanged: {
                checkStateSelector.checkState = checkState
            }
        }
    }

    Pane {
        id: pane
        SplitView.fillWidth: true
        ColumnLayout {
            CheckBox {
                text: "showIndicator"
                checked: delegate.showIndicator
                onCheckedChanged: {
                    delegate.showIndicator = checked
                }
            }

            CheckBox {
                text: "multiSelection"
                checked: delegate.multiSelection
                onCheckedChanged: {
                    delegate.multiSelection = checked
                }
            }

            CheckBox {
                text: "showNewIcon"
                checked: delegate.showNewIcon
                onCheckedChanged: {
                    delegate.showNewIcon = checked
                }
            }

            Label {
                text: "title"
            }
            TextField {
                text: delegate.title
                onTextChanged: {
                    delegate.title = text
                }
            }

            Label {
                text: "iconUrl"
            }
            TextField {
                text: delegate.iconUrl
                onTextChanged: {
                    delegate.iconUrl = text
                }
            }

            CheckBox {
                id: checkStateSelector
                text: "checkedState"
                tristate: true
                checked: true
                onCheckStateChanged: {
                    if(delegate.checkState !== checkState) {
                        delegate.checkState = checkState
                    }
                }
            }
        }
    }
}

// category: Controls
