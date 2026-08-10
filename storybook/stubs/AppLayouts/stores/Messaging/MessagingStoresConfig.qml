pragma Singleton
import QtQuick

// Storybook-only configuration hook: pages/tests install a factory before
// creating components that internally request a CommunityRootStore from the
// stub MessagingRootStore (the community section loader creates one per
// section and destroys it on unload, so a long-lived instance can't be
// handed out directly).
QtObject {
    // function(parent, communityId) -> stub CommunityRootStore instance
    property var communityRootStoreFactory: null
}
