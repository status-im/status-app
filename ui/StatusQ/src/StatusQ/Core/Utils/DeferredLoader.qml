import QtQuick

/*!
   \qmltype DeferredLoader
   \inqmlmodule StatusQ.Core.Utils
   \brief A Loader for a type named by URL, with initial properties set once.

   The type stays out of the declaring document's type closure until the loader is
   first activated. Properties are given once, at creation, and survive \c active
   toggles; toggle only \c active, never set \c source or \c sourceComponent.

   \qml
   DeferredLoader {
       active: root.opened
       url: Qt.resolvedUrl("CreateChatViewInstance.qml")
       properties: ({ contactsStore: Qt.binding(() => root.contactsStore) })
   }
   \endqml
*/
Loader {
    id: root

    property url url
    property var properties: ({})

    Component.onCompleted: root.setSource(root.url, root.properties)
}
