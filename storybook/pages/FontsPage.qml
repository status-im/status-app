import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ.Core.Theme

import Storybook

Item {
    id: root

    Component.onCompleted: {
        families.text += Qt.fontFamilies().filter(f => f.includes("Inter") || f.includes("Roboto Mono")).join(', ')
    }

    ColumnLayout {
        width: parent.width - 40
        anchors.centerIn: parent

        Label {
            text: "Status fonts"
            font.pixelSize: 30
        }
        CustomLabel {
            type: "baseFont"
            font.family: Fonts.baseFont.family
        }
        CustomLabel {
            type: "monoFont"
            font.family: Fonts.monoFont.family
            font.features: Fonts.monoFont.features
        }
        CustomLabel {
            type: "codeFont"
            font.family: Fonts.codeFont.family
        }

        Label {
            id: families
            Layout.fillWidth: true
            Layout.maximumWidth: parent.width*.66
            wrapMode: Text.Wrap
            font.pixelSize: 16
            text: "Available Status fonts: "
        }

        Label {
            Layout.topMargin: 30
            text: "System font"
            font.pixelSize: 30
        }
        CustomLabel {
            type: Qt.platform.os
        }
    }

    component CustomLabel: Label {
        property string type
        textFormat: Text.RichText
        text: "<big>%1 (%2):</big><br>%3<br>".arg(type).arg(font.family)
          .arg("Lorem Ipsum dolor sit amet. ff fi fff Ill<br>0123456789 (3*9=27) -> 0xdeadbeef &lt;==&gt; &amp; @ $ &pound; # &mdash;<br><b>bold</b>, <i>italic</i>, <b><i>bold + italic</i></b>")
        font.pixelSize: 18
    }
}

// category: Core
// status: good
