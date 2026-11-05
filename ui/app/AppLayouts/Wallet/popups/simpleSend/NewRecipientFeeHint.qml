import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme

/**
  Fee hint for a transfer that costs more because its recipient is new.
**/
StatusBaseText {
    text: qsTr("Higher fee: this is a first transfer to this address, and the network charges for creating its account or token balance")
    color: Theme.palette.baseColor1
    font.pixelSize: Theme.additionalTextSize
    wrapMode: Text.Wrap
}
