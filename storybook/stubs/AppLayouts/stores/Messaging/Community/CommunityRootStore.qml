import QtQuick

// Thin shell matching the real CommunityRootStore's public API. The section
// loaders create one per community and destroy it on unload, so the actual
// access/permissions stores are handed in by the page/test fixture and
// outlive this object.
QtObject {
    property var communityId
    property CommunityAccessStore communityAccessStore
    property PermissionsStore communityPermissionsStore
}
