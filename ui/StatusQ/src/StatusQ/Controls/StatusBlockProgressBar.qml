pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme

/*!
   \qmltype StatusBlockProgressBar
   \inherits Control
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief The StatusBlockProgressBar provides a progress bar with steps as blocks

   Example of how to use it:

   \qml
        StatusBlockProgressBar {
            width: 500
            height: 12
            steps: 64
            completedSteps: transaction.confirmations
            blockSet: 4
            error: false
        }
   \endqml

   For a list of components available see StatusQ.
*/

Control {
    id: root

    /*!
       \qmlproperty color StatusBlockProgressBar::blockColor
       This property holds the color for the progress bar blocks
    */
    property color blockColor: Theme.palette.blockProgressBarColor
    /*!
       \qmlproperty color StatusBlockProgressBar::blockSetColor
       This property holds the color for the blockSet
    */
    property color blockSetColor: Theme.palette.successColor1
    /*!
       \qmlproperty color StatusBlockProgressBar::completedColor
       This property holds the color for the finalisation blocks
    */
    property color completedColor: Theme.palette.primaryColor1
    /*!
       \qmlproperty color StatusBlockProgressBar::backgroundColor
       This property holds the background color for the bar
    */
    property color backgroundColor: "transparent"
    /*!
       \qmlproperty int StatusBlockProgressBar::steps
       This property holds the number of blocks
    */
    property int steps: 0
    /*!
       \qmlproperty int StatusBlockProgressBar::completedSteps
       This property holds the number of completed steps
    */
    property int completedSteps: 0
    /*!
       \qmlproperty int StatusBlockProgressBar::blockSet
       This property holds the number of blocks for different coloring
    */
    property int blockSet: 0
    /*!
       \qmlproperty bool StatusBlockProgressBar::error
       This property holds if there was an error in the progress bar
    */
    property bool error: false

    background: Rectangle {
        color: root.backgroundColor
    }

    contentItem: Row {
        id: row
        height: parent.height
        spacing: 2

        Repeater {
            id: repeater
            model: steps
            delegate: Rectangle {
                width: (root.width - (row.spacing*steps))/steps
                height: parent.height
                color: {
                    if(error) {
                        if(index === 0) {
                            return Theme.palette.dangerColor1
                        }
                        return blockColor
                    }
                    else {
                        if(index < completedSteps) {
                            if(index < blockSet) {
                                return completedColor
                            }
                            return blockSetColor
                        }
                        return blockColor
                    }
                }
                radius: 1
            }
        }
    }
}
