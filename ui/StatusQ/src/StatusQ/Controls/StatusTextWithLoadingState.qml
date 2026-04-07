pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

/*!
   \qmltype StatusTextWithLoadingState
   \inherits StatusBaseText
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief A text control with support for loading state

   Example:

   \qml
    StatusTextWithLoadingState {
        title: "Account %1 of %2".arg(completedSteps).arg(totalSteps)
        loading: isLoading
        customColor: Theme.palette.directColor1
    }
   \endqml

   \image statusLoadingText.png

   For a list of components available see StatusQ.
*/

StatusBaseText {
    id: root

    /*!
        \qmlproperty bool StatusTextWithLoadingState::loading
        This property sets if the text is loading.
    */
    property bool loading: false
    /*!
        \qmlproperty color StatusTextWithLoadingState::customColor
        This property sets the user defined color for the text and handles
        transparency in loading state.
    */
    property color customColor: Theme.palette.directColor1

    /*!
        \qmlproperty int StatusTextWithLoadingState::maximumLoadingStateWidth
        This property sets maximum width of loading component.
        The default value is 140.
    */
    property int maximumLoadingStateWidth: 140

    color: loading ? "transparent" : customColor

    Loader {
        anchors.left: parent.left
        anchors.leftMargin: root.leftPadding
        anchors.verticalCenter: parent.verticalCenter
        active: root.loading && root.text
        sourceComponent: LoadingComponent {
            anchors.centerIn: parent
            radius: textMetrics.font.pixelSize <= 15 ? 4 : 8
            height: textMetrics.tightBoundingRect.height
            width: Math.min(root.width, root.maximumLoadingStateWidth)
        }
    }

    TextMetrics {
        id: textMetrics
        font: root.font
        text: root.text
    }
}
