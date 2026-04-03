import QtQuick

QtObject {
    id: root

    signal keycardGetMetadataSuccess()
    signal keycardGetMetadataError(string error)

    signal keycardFactoryResetSuccess()
    signal keycardFactoryResetError(string error)

    readonly property bool ready: d.ready
    readonly property string userProfileKeyUid: userProfile.keyUid

    readonly property QtObject d: QtObject {
        property bool ready: false
        readonly property var mainModuleInst: mainModule
    }

    readonly property Connections keycardManagementModuleConnections: Connections {
        target: d.mainModuleInst.keycardManagementModule ?? null

        function onKeycardGetMetadataSuccess() {
            root.keycardGetMetadataSuccess()
        }

        function onKeycardGetMetadataError(error) {
            root.keycardGetMetadataError(error)
        }

        function onKeycardFactoryResetSuccess() {
            root.keycardFactoryResetSuccess()
        }

        function onKeycardFactoryResetError(error) {
            root.keycardFactoryResetError(error)
        }
    }

    readonly property string keycardState: {
        if (!d.mainModuleInst.keycardManagementModule)
            return ""
        return d.mainModuleInst.keycardManagementModule.keycardState
    }

    readonly property int remainingPinAttempts: {
        if (!d.mainModuleInst.keycardManagementModule)
            return -1
        return d.mainModuleInst.keycardManagementModule.remainingPinAttempts
    }

    readonly property int remainingPukAttempts: {
        if (!d.mainModuleInst.keycardManagementModule)
            return -1
        return d.mainModuleInst.keycardManagementModule.remainingPukAttempts
    }

    readonly property int availableSlots: {
        if (!d.mainModuleInst.keycardManagementModule)
            return -1
        return d.mainModuleInst.keycardManagementModule.availableSlots
    }

    readonly property string keycardUid: {
        if (!d.mainModuleInst.keycardManagementModule)
            return ""
        return d.mainModuleInst.keycardManagementModule.keycardUid
    }

    readonly property string keyUid: {
        if (!d.mainModuleInst.keycardManagementModule)
            return ""
        return d.mainModuleInst.keycardManagementModule.keyUid
    }

    readonly property string cardMetadataName: {
        if (!d.mainModuleInst.keycardManagementModule)
            return ""
        return d.mainModuleInst.keycardManagementModule.cardMetadataName
    }

    readonly property string cardMetadataWalletAccountsJson: {
        if (!d.mainModuleInst.keycardManagementModule)
            return "[]"
        return d.mainModuleInst.keycardManagementModule.cardMetadataWalletAccountsJson
    }

    function prepare() {
        d.mainModuleInst.prepareKeycardManagementModule()
        d.ready = true
    }

    function teardown() {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.keycardManagementModule.stopKeycardAction()
        d.mainModuleInst.destroyKeycardManagementModule()
        d.ready = false
    }

    function startGetMetadata(pin) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.keycardManagementModule.startGetMetadata(pin)
    }

    function startFactoryReset(keycardUid) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.keycardManagementModule.startFactoryReset(keycardUid)
    }
}
