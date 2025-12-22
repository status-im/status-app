import QtQml

QtObject {
    required property string publicKey
    property string compressedPubKey
    property string displayName
    property string ensName
    property bool ensVerified
    property string localNickname
    property string alias
    property bool usesDefaultName
    property string icon
    property int colorId
    property int onlineStatus
    property bool isContact
    property bool isCurrentUser
    property bool isVerified
    property bool isUntrustworthy
    property bool isBlocked
    property int contactRequestState
    property string preferredDisplayName
    property int lastUpdated
    property int lastUpdatedLocally
    property string thumbnailImage
    property string largeImage
    property bool isContactRequestReceived
    property bool isContactRequestSent
    property bool removed
    property int trustStatus
    property string bio

    // Backwards compatibility properties - Don't use in new code
    // TODO: #14965 - Try to remove these properties
    property string name//: ensName
}
