import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core.Theme
import StatusQ.Popups.Dialog
import StatusQ.Controls
import StatusQ.Controls.Validators

import utils
import shared.controls

StatusDialog {
    id: popup

    property var accountSettings

    title: qsTr("Search engine")
    width: 480
    footer: null
    horizontalPadding: Theme.halfPadding
    verticalPadding: Theme.halfPadding

    onClosed: {
        destroy()
    }

    contentItem: ScrollView {
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 0

            ButtonGroup {
                id: searchEnginGroup
            }

            Repeater {
                model: SearchEnginesConfig.engines

                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    
                    RadioButtonSelector {
                        Layout.fillWidth: true
                        implicitHeight: model.description ? 80 : 52
                        title: model.name
                        subTitle: model.description
                        asset.name: Assets.svg(model.iconUrl)
                        asset.isImage: true
                        buttonGroup: searchEnginGroup
                        checked: accountSettings.selectedBrowserSearchEngineId === model.engineId
                        onCheckedChanged: {
                            if (checked && model.engineId !== SearchEnginesConfig.browserSearchEngineCustom) {
                                accountSettings.selectedBrowserSearchEngineId = model.engineId
                                popup.close()
                            } else if (checked) {
                                accountSettings.selectedBrowserSearchEngineId = model.engineId
                            }
                        }
                    }
                    
                    // Custom URL input field (shown only for Custom engine row)
                    StatusInput {
                        id: customUrlInput
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.xlPadding
                        Layout.rightMargin: Theme.xlPadding
                        Layout.topMargin: Theme.halfPadding
                        Layout.bottomMargin: Theme.padding
                        visible: accountSettings.selectedBrowserSearchEngineId === SearchEnginesConfig.browserSearchEngineCustom &&
                                 model.engineId === SearchEnginesConfig.browserSearchEngineCustom
                        placeholderText: "https://example.com/search?q="
                        label: qsTr("Custom search engine URL prefix")
                        text: accountSettings.customSearchEngineUrl
                        input.clearable: true
                        validationMode: StatusInput.ValidationMode.Always
                        validators: [
                            StatusRegularExpressionValidator {
                                regularExpression: /^$|^https?:\/\/.+/
                                errorMessage: qsTr("URL must start with http:// or https://")
                            }
                        ]
                        onTextChanged: {
                            accountSettings.customSearchEngineUrl = text
                        }
                        Keys.onReturnPressed: {
                            if (valid && text.length > 0) {
                                popup.close()
                            }
                        }
                        Keys.onEnterPressed: {
                            if (valid && text.length > 0) {
                                popup.close()
                            }
                        }
                    }
                }
            }
        }
    }
}

