import QtQuick

import StatusQ.Core
import StatusQ.Popups

/*!
   \qmltype StatusSuccessAction
   \inherits StatusMenuItem
   \inqmlmodule StatusQ.Popups
   \since StatusQ.Popups 0.1
   \brief Menu action displaying success state.

   The \c StatusSuccessAction visually indicates a success state after being triggered.
   Success state is showed by changing action type to \c{Success}.

   \qml
        StatusSuccessAction {
            text: qsTr("Copy details")
            successText: qsTr("Details copied")
        }
   \endqml

   By default this action doesn't close the menu. The \l{autoDismissMenu} can be enabled
   to enable this behavior.
*/

StatusMenuItem {
    id: root

    /*!
       \qmlproperty bool StatusSuccessAction::success
       This property holds state of the action.
    */
    property bool success: false
    /*!
       \qmlproperty string StatusSuccessAction::successText
       This property holds success text displayed on success state.

       Default value is bound to \c{text}.
    */
    property string successText: text
    /*!
       \qmlproperty string StatusSuccessAction::successIconName
       This property holds icon name displayed on success state.

       Default value is \c{tiny/checkmark}.
    */
    property string successIconName: "tiny/checkmark"
    /*!
       \qmlproperty bool StatusSuccessAction::autoDismissMenu
       This property enable menu closing on click after the \p timeout
    */
    property bool autoDismissMenu: false
    /*!
       \qmlproperty int StatusSuccessAction::timeout
       This property controls how long success state is showed.
    */
    property int timeout: 2000

    /*! \internal Overriden signal to not close menu on click */
    signal triggered()

    // Hide disabled item when hiding is enabled
    visible: !root.menu.hideDisabledItems || enabled
    height: visible || enabled ? implicitHeight : 0
    onVisibleChanged: {
        if (!visible)
            success = false
    }
    Binding on text {
        when: root.success
        value: root.successText
    }
    action: StatusAction {
        type: root.success ? StatusAction.Type.Success : StatusAction.Type.Normal
        icon.name: root.success ? root.successIconName : root.icon.name
    }
    StatusMouseArea {
        // NOTE Using mouse area to block menu auto closing
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root.triggered()
            root.success = true
        }
    }
    Timer {
        id: debounceTimer
        interval: root.timeout
        running: root.success
        onTriggered: {
            root.success = false
            if (root.autoDismissMenu && root.menu) {
                root.menu.dismiss()
            }
        }
    }
}
