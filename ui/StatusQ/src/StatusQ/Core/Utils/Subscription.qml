pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root
    
    readonly property string subscriptionId: Utils.uuid()
    
    property bool isReady: false
    property int notificationInterval: 3000 // 1 notification every 3 seconds
    //The topic to subscribe to
    property string topic: ""
    property var response: {}
}
