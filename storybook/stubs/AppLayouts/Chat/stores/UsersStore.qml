import QtQuick

QtObject {
    property var usersModel: ChatStoresConfig.usersModel
    property var rosterModel: ChatStoresConfig.chatSectionModule?.rosterModel ?? null

    function groupMembersUpdateRequested(membersPubKeysList) {}
}
