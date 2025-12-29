import QtQuick
import utils

import StatusQ.Core.Utils 0.1 as StatusQUtils
import StatusQ.Core.Backpressure

QtObject {
    id: root

    property var devicesModule
    property var syncModule
    property bool localBackupEnabled: false

    property var devicesModel: devicesModule ?  devicesModule.model : null

    // Module Properties
    property bool isDeviceSetup: devicesModule ? devicesModule.isDeviceSetup : false

    readonly property int localPairingState: devicesModule ? devicesModule.localPairingState : -1
    readonly property string localPairingError: devicesModule ? devicesModule.localPairingError : ""
    readonly property string localPairingInstallationId: devicesModule ? devicesModule.localPairingInstallationId : ""
    readonly property string localPairingInstallationName: devicesModule ? devicesModule.localPairingInstallationName : ""
    readonly property string localPairingInstallationDeviceType: devicesModule ? devicesModule.localPairingInstallationDeviceType : ""
    
    // Backup import properties
    readonly property int backupImportState: syncModule ? syncModule.backupImportState : 0
    readonly property int backupDataState: syncModule ? syncModule.backupDataState : 0
    readonly property string backupImportError: syncModule ? syncModule.backupImportError : ""
    readonly property string backupDataError: syncModule ? syncModule.backupDataError : ""
    readonly property url backupPath: {
        if (!d.localAccountSensitiveSettingsInst.localBackupChosenPath) {
            return ""
        }
        return toFileUri(d.localAccountSensitiveSettingsInst.localBackupChosenPath)
    }
    readonly property bool messagesBackupEnabled: d.appSettingsInst.messagesBackupEnabled

    readonly property QtObject _d: StatusQUtils.QObject {
        id: d
        readonly property var appSettingsInst: appSettings
        readonly property var localAccountSensitiveSettingsInst: localAccountSensitiveSettings
        readonly property var globalUtilsInst: globalUtils
    }

    signal localBackupExportCompleted(bool success)
    signal localBackupImportCompleted(bool success)

    readonly property Connections syncModuleConnections: Connections {
        target: root.syncModule

        function onLocalBackupExportCompleted(success: bool) {
            root.localBackupExportCompleted(success)
        }
        function onLocalBackupImportCompleted(success: bool) {
            root.localBackupImportCompleted(success)
        }
    }

    function setBackupPath(path) {
        d.appSettingsInst.setBackupPath(path)
    }

    function setMessagesBackupEnabled(enabled) {
        d.appSettingsInst.setMessagesBackupEnabled(enabled)
    }

    function toFileUri(path) {
        return d.globalUtilsInst.toFileUri(path)
    }

    function loadDevices() {
        return root.devicesModule.loadDevices()
    }

    function setInstallationName(installationId, name) {
        return root.devicesModule.setInstallationName(installationId, name)
    }

    function syncAll() {
        root.devicesModule.syncAll()
    }

    function advertise() {
        root.devicesModule.advertise()
    }

    function generateConnectionStringAndRunSetupSyncingPopup(messageSyncingEnabled) {
        root.devicesModule.generateConnectionStringAndRunSetupSyncingPopup(messageSyncingEnabled)
    }

    function validateConnectionString(connectionString) {
        return root.devicesModule.validateConnectionString(connectionString)
    }

    function inputConnectionStringForBootstrapping(connectionString) {
        root.devicesModule.inputConnectionStringForBootstrapping(connectionString)
    }

    function pairDevice(installationId) {
        return root.devicesModule.pairDevice(installationId)
    }

    function unpairDevice(installationId) {
        return root.devicesModule.unpairDevice(installationId)
    }

    function importLocalBackupFile(filePath: string) {
        root.syncModule.importLocalBackupFile(filePath)
    }

    function performLocalBackup() {
        root.syncModule.performLocalBackup()
        Backpressure.debounce(this, 5000, () => {
            resetBackupDataState()
        })()
    }

    function resetBackupDataState() {
        root.syncModule.resetBackupDataState()
    }
}
