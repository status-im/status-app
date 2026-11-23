import shared.popups
import shared.stores

TestnetModePopup {
    id: root

    required property NetworksStore networksStore

    areTestNetworksEnabled: root.networksStore.areTestNetworksEnabled
    onToggleTestnetRequested: root.networksStore.toggleTestNetworksEnabled()
}
