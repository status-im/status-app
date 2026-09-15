import QtQuick

// common contract for StatusSectionLayout loaders
Loader {
    id: root

    required property string userUID
    required property string sectionName

    property int leftPanelWidthOverride: 0
}
