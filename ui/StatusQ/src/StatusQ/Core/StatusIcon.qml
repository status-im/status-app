pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl // for ColorImage

ColorImage {
    property string icon: ""

    width: 24
    height: 24
    // SVGs must have sourceSize, PNGs not; otherwise blurry
    sourceSize: !!icon ? Qt.size(width, height) : undefined
    fillMode: Image.PreserveAspectFit

    onIconChanged: {
        if(icon.startsWith("data:image/") || icon.startsWith("https://") || icon.startsWith("qrc:/") || icon.startsWith("file:/")) {
            //raw image data
            source = icon
            objectName = "custom-icon"
        } else if (icon !== "") {
            source = Qt.resolvedUrl("../../assets/img/icons/" + icon+ ".svg");
            objectName = icon + "-icon"
        }
    }
}
