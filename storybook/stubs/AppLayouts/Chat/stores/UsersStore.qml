import QtQuick

QtObject {
    property var usersModel: ChatStoresConfig.usersModel

    function groupMembersUpdateRequested(membersPubKeysList) {}
}
