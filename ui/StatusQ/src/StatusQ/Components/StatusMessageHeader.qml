import QtQuick

import StatusQ

/*!
   \qmltype StatusMessageHeader
   \inherits MessageHeaderItem
   \inqmlmodule StatusQ.Components
   \brief A message header: sender name, verification, details, timestamp and delivery status.

   One native item renders the whole header. Give it the view's shared
   StatusMessageHeaderServices (which also carries the view's appearance) and
   one complete \c messageHeaderData snapshot per message:

   \qml
       StatusMessageHeader {
           width: parent.width
           services: headerServices
           headerData: ({ senderId: sender.id, displayName: sender.displayName,
                          timestamp: message.timestamp, isContact: sender.isContact })
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
