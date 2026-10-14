import QtQuick

QtObject {
    id: root

    // External properties:
    required property var chatCommunitySectionModule
    required property var usersModule

    // Public API:
    // Members of a 1:1 or group chat; community channels leave it empty
    readonly property var usersModel: root.usersModule ? root.usersModule.model : null

    // The community's member roster; empty until a RosterHolder loads it.
    // ChannelMembersAdaptor narrows it to one channel.
    readonly property var rosterModel: root.chatCommunitySectionModule
                                       ? root.chatCommunitySectionModule.rosterModel : null

    // Used for editing:
    function groupMembersUpdateRequested(membersPubKeysList) {
        root.usersModule.groupMembersUpdateRequested(membersPubKeysList)
    }
}
