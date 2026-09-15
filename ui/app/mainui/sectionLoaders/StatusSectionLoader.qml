import QtQuick

// common contract for StatusSectionLayout loaders
Loader {
    id: root

    required property string userUID
    required property string sectionName

    property int leftPanelWidthOverride: 0

    Binding {
        target: item ?? null
        when: active
        property: "userUID"
        value: root.userUID
    }

    Binding {
        target: item ?? null
        when: active
        property: "sectionName"
        value: root.sectionName
    }
}
