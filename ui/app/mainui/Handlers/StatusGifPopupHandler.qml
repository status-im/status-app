import QtQuick
import QtQuick.Controls

import shared.stores

import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

QtObject {
    id: root

    required property GifStore gifStore
    required property bool gifUnfurlingEnabled
    required property bool thirdpartyServicesEnabled

    signal enableThirdpartyServicesRequested

    property QtObject _d: QtObject {
        id: _d
        property var cbOnGifSelected: function () {} // It stores callback for gifSelected
        property var cbOnClose: function () {} // It stores callback for popup closed
        property bool closeAfterSelection: true
    }

    function openGifs(params, cbOnGifSelected, cbOnClose)
    {
        _d.cbOnGifSelected = cbOnGifSelected
        _d.cbOnClose = cbOnClose
        _d.closeAfterSelection = params.closeAfterSelection

        gifPopupComponent.open(params.popupParent, {
            directParent: params.popupParent,
            preferredRelativeX: params.relativeX
        })
    }

    readonly property SQUtils.DeferredComponent gifPopupComponent: SQUtils.DeferredComponent {
        source: Qt.resolvedUrl("StatusGifPopupInstance.qml")
        destroyOnClose: true
        properties: ({
            gifStore: root.gifStore,
            gifUnfurlingEnabled: Qt.binding(() => root.gifUnfurlingEnabled),
            thirdpartyServicesEnabled: Qt.binding(() => root.thirdpartyServicesEnabled)
        })
        onCreated: popup => {
            popup.gifSelected.connect(url => {
                _d.cbOnGifSelected(url)

                if (_d.closeAfterSelection) {
                    popup.close()
                }
            })
            popup.enableThirdpartyServicesRequested.connect(root.enableThirdpartyServicesRequested)
            popup.closed.connect(() => _d.cbOnClose())
        }
    }
}
