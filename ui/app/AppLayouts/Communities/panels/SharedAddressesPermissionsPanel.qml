import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import SortFilterProxyModel

import AppLayouts.Communities.controls
import AppLayouts.Communities.views
import AppLayouts.Communities.helpers

import utils

Rectangle {
    id: root

    required property int /*PermissionTypes.Type*/ eligibleToJoinAs

    property bool isEditMode
    property bool isDirty

    property string communityName
    property string communityIcon

    property var permissionsModel
    property var assetsModel
    property var collectiblesModel
    property var getTokenByKeyOrGroupKeyFromAllTokens: function(key){ return {}}

    property bool requirementsCheckPending
    property bool checkingPermissionToJoinInProgress
    property bool joinPermissionsCheckCompletedWithoutErrors

    readonly property bool lostPermissionToJoin: d.lostPermissionToJoin
    readonly property bool lostChannelPermissions: d.lostChannelPermissions

    implicitHeight: permissionsScrollView.contentHeight - permissionsScrollView.anchors.topMargin
    color: Theme.palette.baseColor4

    readonly property bool hasAnyVisiblePermission: root.permissionsModel && root.permissionsModel.count &&
                                                    (d.tokenMasterPermissionsModel.count > 0 || d.adminPermissionsModel.count > 0 ||
                                                     d.joinPermissionsModel.count > 0 || d.channelsPermissionsModel.count > 0)

    QtObject {
        id: d

        // UI
        readonly property int absLeftMargin: 12
        readonly property color tableBorderColor: Theme.palette.directColor7

        // internal logic
        readonly property bool lostPermissionToJoin: root.isEditMode && joinPermissionsModel.count && !joinPermissionPanel.tokenCriteriaMet

        readonly property var uniquePermissionChannels:
            d.channelsPermissionsModel.count ?
                PermissionsHelpers.getUniquePermissionChannels(root.permissionsModel, [PermissionTypes.Type.Read, PermissionTypes.Type.ViewAndPost])
              : []

        property var initialChannelPermissions

        function getChannelPermissions() {
            var result = {}
            for (let i = 0; i < channelPermissionsPanel.count; i++) {
                const channel = channelPermissionsPanel.itemAt(i)
                const ckey = channel.channelKey
                result[ckey] = [channel.readPermissionMet, channel.viewAndPostPermissionMet]
            }
            return result
        }
        readonly property bool lostChannelPermissions: root.isEditMode && d.uniquePermissionChannels.length > 0 && channelPermissionsPanel.anyPermissionLost

        // models
        readonly property var tokenMasterPermissionsModel: SortFilterProxyModel {
            id: tokenMasterPermissionsModel
            sourceModel: root.permissionsModel
            filters: [
                ValueFilter {
                    roleName: "permissionType"
                    value: Constants.permissionType.becomeTokenMaster
                },
                ValueFilter {
                    roleName: "tokenCriteriaMet"
                    value: true
                }
            ]
        }
        readonly property var adminPermissionsModel: SortFilterProxyModel {
            id: adminPermissionsModel
            sourceModel: root.permissionsModel
            filters: [
                ValueFilter {
                    roleName: "permissionType"
                    value: Constants.permissionType.admin
                },
                AnyOf {
                    ValueFilter {
                        roleName: "isPrivate"
                        value: false
                    }
                    AllOf {
                        ValueFilter {
                            roleName: "tokenCriteriaMet"
                            value: true
                        }
                        ValueFilter {
                            roleName: "isPrivate"
                            value: true
                        }
                    }
                }
            ]
        }
        readonly property var joinPermissionsModel: SortFilterProxyModel {
            id: joinPermissionsModel
            sourceModel: root.permissionsModel
            filters: [
                ValueFilter {
                    roleName: "permissionType"
                    value: Constants.permissionType.member
                },
                AnyOf {
                    ValueFilter {
                        roleName: "isPrivate"
                        value: false
                    }
                    AllOf {
                        ValueFilter {
                            roleName: "tokenCriteriaMet"
                            value: true
                        }
                        ValueFilter {
                            roleName: "isPrivate"
                            value: true
                        }
                    }
                }
            ]
        }

        // used to check if there are any visible channel permissions
        readonly property var channelsPermissionsModel: SortFilterProxyModel {
            id: channelsPermissionsModel
            sourceModel: root.permissionsModel
            filters: [
                AnyOf {
                    ValueFilter {
                        roleName: "permissionType"
                        value: Constants.permissionType.read
                    }
                    ValueFilter {
                        roleName: "permissionType"
                        value: Constants.permissionType.viewAndPost
                    }
                },
                AnyOf {
                    ValueFilter {
                        roleName: "isPrivate"
                        value: false
                    }
                    AllOf {
                        ValueFilter {
                            roleName: "tokenCriteriaMet"
                            value: true
                        }
                        ValueFilter {
                            roleName: "isPrivate"
                            value: true
                        }
                    }
                }
            ]
        }
    }

    Component.onCompleted: {
        d.initialChannelPermissions = d.getChannelPermissions()
    }

    StatusScrollView {
        id: permissionsScrollView
        anchors.fill: parent
        anchors.topMargin: -Theme.padding
        bottomPadding: eligibilityHintBubble.visible ? eligibilityHintBubble.height + eligibilityHintBubble.anchors.bottomMargin*2
                                                     : 16
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: Theme.halfPadding

            // header
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                spacing: Theme.padding
                StatusRoundedImage {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.leftMargin: d.absLeftMargin
                    image.source: root.communityIcon
                }
                StatusBaseText {
                    font.weight: Font.Medium
                    text: qsTr("Permissions")
                }
                Item { Layout.fillWidth: true }
                RowLayout {
                    Layout.rightMargin: Theme.halfPadding
                    spacing: 4
                    visible: root.requirementsCheckPending
                    StatusBaseText {
                        text: qsTr("Updating eligibility")
                        font.pixelSize: Theme.tertiaryTextFontSize
                        color: Theme.palette.baseColor1
                    }
                    StatusLoadingIndicator {
                        Layout.preferredWidth: 12
                        Layout.preferredHeight: 12
                    }
                }
            }

            // permission types
            PermissionPanel {
                id: joinPermissionPanel
                permissionType: PermissionTypes.Type.Member
                permissionsModel: d.joinPermissionsModel
            }
            PermissionPanel {
                permissionType: PermissionTypes.Type.Admin
                permissionsModel: d.adminPermissionsModel
            }
            PermissionPanel {
                id: tokenMasterPermissionPanel
                permissionType: PermissionTypes.Type.TokenMaster
                permissionsModel: d.tokenMasterPermissionsModel
            }

            Repeater { // channel repeater
                id: channelPermissionsPanel
                model: d.uniquePermissionChannels
                delegate: ChannelPermissionPanel {}
                readonly property bool anyPermissionLost: {
                    for (let i = 0; i < channelPermissionsPanel.count; i++) {
                        const channel = channelPermissionsPanel.itemAt(i)
                        if (channel && channel.anyPermissionLost)
                            return true
                    }
                    return false
                }
            }
        }
    }

    CommunityEligibilityTag {
        id: eligibilityHintBubble
        visible: !root.checkingPermissionToJoinInProgress && root.joinPermissionsCheckCompletedWithoutErrors
        eligibleToJoinAs: root.eligibleToJoinAs
        isEditMode: root.isEditMode
        isDirty: root.isDirty
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
    }

    component PanelBg: Rectangle {
        color: Theme.palette.statusListItem.backgroundColor
        border.width: 1
        border.color: Theme.palette.baseColor2
        radius: Theme.radius
    }

    component PanelIcon: StatusRoundIcon {
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        Layout.alignment: Qt.AlignTop
        asset.name: {
            switch (permissionType) {
            case PermissionTypes.Type.TokenMaster:
                return "arbitrator"
            case PermissionTypes.Type.Admin:
                return "admin"
            case PermissionTypes.Type.Member:
                return "communities"
            default:
                return "channel"
            }
        }
        radius: height/2
    }

    component PanelHeading: StatusBaseText {
        Layout.fillWidth: true
        elide: Text.ElideRight
        font.weight: Font.Medium
        text: {
            switch (permissionType) {
            case PermissionTypes.Type.Admin:
                return qsTr("Become an admin")
            case PermissionTypes.Type.Member:
                return qsTr("Join %1").arg(root.communityName)
            case PermissionTypes.Type.TokenMaster:
                return qsTr("Become a TokenMaster")
            default:
                return d.uniquePermissionChannels[index][1]
            }
        }
    }

    component SinglePermissionFlow: Flow {
        Layout.fillWidth: true
        spacing: Theme.halfPadding
        Repeater {
            model: HoldingsSelectionModel {
                sourceModel: model.holdingsListModel
                assetsModel: root.assetsModel
                collectiblesModel: root.collectiblesModel
                getTokenByKeyOrGroupKeyFromAllTokens: root.getTokenByKeyOrGroupKeyFromAllTokens
            }
            delegate: Row {
                spacing: 4
                StatusRoundedImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    image.source: model.imageSource
                    visible: !isError
                }
                StatusBaseText {
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Theme.tertiaryTextFontSize
                    text: !!model.text ? model.text : ""
                    color: model.available ? Theme.palette.successColor1 : Theme.palette.baseColor1
                }
            }
        }
    }

    component PermissionPanel: Control {
        id: permissionPanel
        property int permissionType: PermissionTypes.Type.None
        property var permissionsModel

        readonly property bool tokenCriteriaMet: overallPermissionRow.tokenCriteriaMet

        visible: permissionsModel.count
        Layout.fillWidth: true
        padding: d.absLeftMargin
        background: PanelBg {}
        contentItem: RowLayout {
            spacing: Theme.padding
            PanelIcon {}
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                PanelHeading {}
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: grid.implicitHeight + grid.anchors.margins*2
                    border.width: 1
                    border.color: d.tableBorderColor
                    radius: Theme.radius
                    color: "transparent"

                    GridLayout {
                        id: grid
                        anchors.fill: parent
                        anchors.margins: Theme.halfPadding
                        rowSpacing: Theme.halfPadding
                        columnSpacing: Theme.halfPadding
                        columns: 2

                        Repeater {
                            id: permissionsRepeater

                            property int revision
                            onItemAdded: revision++
                            onItemRemoved: revision++

                            model: permissionPanel.permissionsModel
                            delegate: ColumnLayout {
                                Layout.column: 0
                                Layout.row: index
                                Layout.fillWidth: true
                                spacing: Theme.halfPadding

                                readonly property bool tokenCriteriaMet: model.tokenCriteriaMet ?? false
                                onTokenCriteriaMetChanged: permissionsRepeater.revision++

                                SinglePermissionFlow {}

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: -grid.anchors.leftMargin
                                    Layout.rightMargin: -grid.anchors.rightMargin
                                    Layout.preferredHeight: 1
                                    color: d.tableBorderColor
                                    visible: index < permissionsRepeater.count - 1
                                }
                            }
                        }
                        RowLayout {
                            id: overallPermissionRow
                            Layout.column: 1
                            Layout.rowSpan: permissionsRepeater.count || 1
                            Layout.preferredWidth: 110
                            Layout.fillHeight: true

                            readonly property bool tokenCriteriaMet: {
                                permissionsRepeater.revision
                                for (var i = 0; i < permissionsRepeater.count; i++) { // NB no let/const here b/c of https://bugreports.qt.io/browse/QTBUG-91917
                                    var permissionItem = permissionsRepeater.itemAt(i);
                                    if (permissionItem && permissionItem.tokenCriteriaMet)
                                        return true
                                }
                                return false
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true
                                Layout.topMargin: -Theme.halfPadding
                                Layout.bottomMargin: -Theme.halfPadding
                                color: d.tableBorderColor
                            }
                            Row {
                                Layout.alignment: Qt.AlignCenter
                                spacing: 4
                                StatusIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    height: 16
                                    icon: overallPermissionRow.tokenCriteriaMet ? "tiny/checkmark" : "tiny/secure"
                                    color: {
                                        if (d.lostPermissionToJoin)
                                            return Theme.palette.dangerColor1
                                        if (overallPermissionRow.tokenCriteriaMet)
                                            return Theme.palette.successColor1
                                        return Theme.palette.baseColor1
                                    }
                                }
                                StatusBaseText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: Theme.tertiaryTextFontSize
                                    text: {
                                        switch (permissionPanel.permissionType) {
                                        case PermissionTypes.Type.Admin:
                                            return qsTr("Admin")
                                        case PermissionTypes.Type.Member:
                                            return qsTr("Join")
                                        case PermissionTypes.Type.Read:
                                            return qsTr("View only")
                                        case PermissionTypes.Type.ViewAndPost:
                                            return qsTr("View & post")
                                        case PermissionTypes.Type.TokenMaster:
                                            return qsTr("TokenMaster")
                                        default:
                                            return "???"
                                        }
                                    }

                                    color: {
                                        if (d.lostPermissionToJoin)
                                            return Theme.palette.dangerColor1
                                        if (overallPermissionRow.tokenCriteriaMet)
                                            return Theme.palette.directColor1
                                        return Theme.palette.baseColor1
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component ChannelPermissionPanel: Control {
        id: channelPermsPanel
        Layout.fillWidth: true
        spacing: 10
        padding: d.absLeftMargin
        background: PanelBg {}

        visible: {
            for (var i = 0; i < channelPermsRepeater.count; i++) {
                var chanPermissionItem = channelPermsRepeater.itemAt(i);
                if (chanPermissionItem.channelPermissionsModel.count > 0)
                    return true
            }
            return false
        }

        readonly property string channelKey: modelData[0]
        readonly property bool readPermissionMet: channelPermsRepeater.count > 0 ? channelPermsRepeater.itemAt(0).tokenCriteriaMet : false
        readonly property bool viewAndPostPermissionMet: channelPermsRepeater.count > 1 ? channelPermsRepeater.itemAt(1).tokenCriteriaMet : false
        readonly property bool anyPermissionLost: channelPermsRepeater.count > 0 ? channelPermsRepeater.itemAt(0).permissionLost || channelPermsRepeater.itemAt(1).permissionLost : false

        contentItem: RowLayout {
            spacing: Theme.padding
            PanelIcon {}
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.smallPadding
                PanelHeading {}
                Repeater { // permissions repeater
                    id: channelPermsRepeater
                    model: [PermissionTypes.Type.Read, PermissionTypes.Type.ViewAndPost]

                    delegate: Rectangle {
                        id: channelPermsSubPanel

                        readonly property int permissionType: modelData
                        readonly property bool tokenCriteriaMet: overallPermissionRow2.tokenCriteriaMet
                        readonly property bool permissionLost: d.initialChannelPermissions[channelPermsPanel.channelKey][index] && !tokenCriteriaMet
                        readonly property var channelPermissionsModel: permissionsRepeater2.model

                        Layout.fillWidth: true
                        Layout.preferredHeight: grid2.implicitHeight + grid2.anchors.margins*2
                        border.width: 1
                        border.color: d.tableBorderColor
                        radius: Theme.radius
                        color: "transparent"
                        visible: permissionsRepeater2.model.count > 0

                        GridLayout {
                            id: grid2
                            anchors.fill: parent
                            anchors.margins: Theme.halfPadding
                            rowSpacing: Theme.halfPadding
                            columnSpacing: Theme.halfPadding
                            columns: 2

                            Repeater {
                                id: permissionsRepeater2

                                property int revision
                                onItemAdded: revision++
                                onItemRemoved: revision++

                                model: SortFilterProxyModel {
                                    id: channelPermissionsModel
                                    sourceModel: d.channelsPermissionsModel

                                    function filterPredicate(channelsListModel) {
                                        return ModelUtils.contains(channelsListModel, "key", channelPermsPanel.channelKey)
                                    }

                                    filters: [
                                        ValueFilter {
                                            roleName: "permissionType"
                                            value: channelPermsSubPanel.permissionType
                                        },
                                        FastExpressionFilter {
                                            expression: channelPermissionsModel.filterPredicate(model.channelsListModel) // filter and group by channel "key"
                                            expectedRoles: ["channelsListModel"]
                                        }
                                    ]
                                }
                                delegate: ColumnLayout {
                                    Layout.column: 0
                                    Layout.row: index
                                    Layout.fillWidth: true
                                    spacing: Theme.halfPadding

                                    readonly property bool tokenCriteriaMet: model.tokenCriteriaMet ?? false
                                    onTokenCriteriaMetChanged: permissionsRepeater2.revision++

                                    SinglePermissionFlow {}

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: -grid2.anchors.leftMargin
                                        Layout.rightMargin: -grid2.anchors.rightMargin
                                        Layout.preferredHeight: 1
                                        color: d.tableBorderColor
                                        visible: index < permissionsRepeater2.count - 1
                                    }
                                }
                            }

                            RowLayout {
                                id: overallPermissionRow2
                                Layout.column: 1
                                Layout.rowSpan: channelPermissionsModel.count || 1
                                Layout.preferredWidth: 110
                                Layout.fillHeight: true

                                readonly property bool tokenCriteriaMet: {
                                    permissionsRepeater2.revision
                                    for (var i = 0; i < permissionsRepeater2.count; i++) { // NB no let/const here b/c of https://bugreports.qt.io/browse/QTBUG-91917
                                        const permissionItem = permissionsRepeater2.itemAt(i);
                                        if (permissionItem && permissionItem.tokenCriteriaMet)
                                            return true
                                    }
                                    return false
                                }

                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    Layout.topMargin: -Theme.halfPadding
                                    Layout.bottomMargin: -Theme.halfPadding
                                    color: d.tableBorderColor
                                }
                                Row {
                                    Layout.alignment: Qt.AlignCenter
                                    spacing: 4
                                    StatusIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16
                                        height: 16
                                        icon: overallPermissionRow2.tokenCriteriaMet ? "tiny/checkmark" : "tiny/secure"
                                        color: {
                                            if (channelPermsSubPanel.permissionLost)
                                                return Theme.palette.dangerColor1
                                            if (overallPermissionRow2.tokenCriteriaMet)
                                                return Theme.palette.successColor1
                                            return Theme.palette.baseColor1
                                        }
                                    }
                                    StatusBaseText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.pixelSize: Theme.tertiaryTextFontSize
                                        text: {
                                            switch (channelPermsSubPanel.permissionType) {
                                            case PermissionTypes.Type.Read:
                                                return qsTr("View only")
                                            case PermissionTypes.Type.ViewAndPost:
                                                return qsTr("View & post")
                                            default:
                                                return "???"
                                            }
                                        }

                                        color: {
                                            if (channelPermsSubPanel.permissionLost)
                                                return Theme.palette.dangerColor1
                                            if (overallPermissionRow2.tokenCriteriaMet)
                                                return Theme.palette.directColor1
                                            return Theme.palette.baseColor1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
