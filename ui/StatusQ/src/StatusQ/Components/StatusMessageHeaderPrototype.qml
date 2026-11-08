import QtQuick

import StatusQ

/*!
   \qmltype StatusMessageHeaderPrototype
   \inherits MessageHeaderItem
   \inqmlmodule StatusQ.Components
   \brief Experimental native message header.

   One item renders the whole header. Give it the view's shared
   StatusMessageHeaderAppearance and StatusMessageHeaderServices, and one
   complete \c messageHeaderData snapshot per message:

   \qml
       StatusMessageHeaderPrototype {
           width: parent.width
           appearance: headerAppearance
           services: headerServices
           headerData: model.headerData
       }
   \endqml

   Signals: \c clicked(sender) for the name, with the header as the anchor,
   and \c resendClicked().
*/
MessageHeaderItem {
    id: root

    // Marks the inherited property as required; it declares nothing new.
    required services

    readonly property alias timestamp: root.headerData.timestamp
    readonly property alias amISender: root.headerData.amISender
}
