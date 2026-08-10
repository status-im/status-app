import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

/**
 * What the browser opens and plays on this platform (BrowserFormatSupportContext).
 * A read-only report: every format is either opened in a Tab or handed to the OS.
 */
StatusDialog {
    id: root

    /// [{title, formats: [{name, detail, supported}]}]
    required property var sections
    /// True once the Backend's media engine answered; otherwise the list is the
    /// Backend's own answer, unverified.
    property bool engineChecked: false

    title: qsTr("Supported formats")
    width: 480
    footer: null

    contentItem: StatusScrollView {
        id: scrollView

        contentWidth: availableWidth
        padding: 0

        ColumnLayout {
            width: scrollView.availableWidth
            spacing: Theme.padding

            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Files in these formats open in a browser tab. Everything else opens in another app.")
                wrapMode: Text.WordWrap
                color: Theme.palette.baseColor1
                font.pixelSize: Theme.tertiaryTextFontSize
            }

            Repeater {
                model: root.sections

                delegate: ColumnLayout {
                    id: section

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Theme.halfPadding

                    StatusBaseText {
                        Layout.fillWidth: true
                        text: section.modelData.title
                        font.pixelSize: Theme.additionalTextSize
                        font.weight: Font.Medium
                    }

                    Repeater {
                        model: section.modelData.formats

                        delegate: RowLayout {
                            id: formatRow

                            required property var modelData

                            objectName: "supportedFormatRow_" + formatRow.modelData.name
                            Layout.fillWidth: true
                            spacing: Theme.halfPadding

                            StatusIcon {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                icon: formatRow.modelData.supported ? "checkmark" : "close"
                                color: formatRow.modelData.supported ? Theme.palette.successColor1
                                                                     : Theme.palette.baseColor1
                            }
                            StatusBaseText {
                                text: formatRow.modelData.name
                                font.pixelSize: Theme.additionalTextSize
                            }
                            StatusBaseText {
                                Layout.fillWidth: true
                                text: formatRow.modelData.detail
                                elide: Text.ElideRight
                                color: Theme.palette.baseColor1
                                font.pixelSize: Theme.tertiaryTextFontSize
                            }
                            StatusBaseText {
                                objectName: "supportedFormatStatus"
                                text: formatRow.modelData.supported ? qsTr("Opens here")
                                                                    : qsTr("Opens in another app")
                                color: formatRow.modelData.supported ? Theme.palette.successColor1
                                                                     : Theme.palette.baseColor1
                                font.pixelSize: Theme.tertiaryTextFontSize
                            }
                        }
                    }
                }
            }

            StatusBaseText {
                Layout.fillWidth: true
                text: root.engineChecked ? qsTr("Checked against this platform's media engine.")
                                         : qsTr("Reported by this platform's browser engine.")
                wrapMode: Text.WordWrap
                color: Theme.palette.baseColor1
                font.pixelSize: Theme.tertiaryTextFontSize
            }
        }
    }
}
