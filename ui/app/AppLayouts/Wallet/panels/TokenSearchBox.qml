import shared.controls
import StatusQ.Core.Utils

SearchBox {
    implicitHeight: 56
    showBackground: false
    focus: visible && !Utils.isMobile
}
