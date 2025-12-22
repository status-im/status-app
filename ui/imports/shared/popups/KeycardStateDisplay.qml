import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

import shared

/// Reusable component for displaying a state in the KeycardChannelDrawer
/// Shows an icon, title, and description in a consistent layout
Item {
    id: root
    
    // ============================================================
    // PUBLIC API
    // ============================================================
    
    /// Path to the icon image
    property string iconSource: ""
    
    /// Main title text
    property string title: ""
    
    /// Description text below the title
    property string description: ""
    
    /// Whether this is an error state (affects text color)
    property bool isError: false
    
    /// Whether to show a loading animation
    property bool showLoading: false

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight
    
    // ============================================================
    // INTERNAL LAYOUT
    // ============================================================
    
    ColumnLayout {
        id: layout
        anchors.centerIn: parent
        width: parent.width
        spacing: Theme.padding
        
        // Icon
        StatusImage {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 164
            Layout.preferredHeight: 164
            source: root.iconSource
            visible: root.iconSource !== ""
        }
        
        // Title
        StatusBaseText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.padding
            horizontalAlignment: Text.AlignHCenter
            text: root.title
            font.pixelSize: Theme.fontSize25
            font.bold: true
            color: root.isError ? Theme.palette.dangerColor1 : Theme.palette.directColor1
            wrapMode: Text.WordWrap
            visible: root.title !== ""
        }
        
        // Description
        StatusBaseText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.halfPadding
            horizontalAlignment: Text.AlignHCenter
            text: root.description
            font.pixelSize: Theme.primaryTextFontSize
            color: Theme.palette.baseColor1
            wrapMode: Text.WordWrap
            visible: root.description !== ""
        }
        
        // Loading animation (shown for reading state)
        LoadingAnimation {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.padding
            visible: root.showLoading
        }
    }
}

