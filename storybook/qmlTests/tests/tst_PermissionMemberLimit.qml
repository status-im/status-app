import QtQuick
import QtTest

import AppLayouts.Communities.controls
import AppLayouts.Communities.panels

/*
    Become-member permissions are capped at five. The cap and the warning
    copy live in PermissionTypes; PermissionsSettingsPanel counts the model
    and EditPermissionView shows the warning.
*/
Item {
    id: root

    width: 800
    height: 900

    function findByTypePrefix(item, prefix) {
        if (!item)
            return null
        if (item.toString().indexOf(prefix) === 0)
            return item
        const list = item.children
        for (let i = 0; i < list.length; ++i) {
            const found = findByTypePrefix(list[i], prefix)
            if (found)
                return found
        }
        return null
    }

    readonly property QtObject communityDetails: QtObject {
        readonly property string id: "test-community"
        readonly property string name: "Test Community"
        readonly property string image: ""
        readonly property string color: "red"
        readonly property bool owner: true
    }

    ListModel { id: memberPermissionsModel }

    Component {
        id: emptyModelComponent
        ListModel {}
    }

    Component {
        id: panelComponent

        PermissionsSettingsPanel {
            width: root.width
            height: root.height

            permissionsModel: memberPermissionsModel
            assetsModel: ListModel {}
            collectiblesModel: ListModel {}
            channelsModel: ListModel {}
            communityDetails: root.communityDetails
        }
    }

    TestCase {
        name: "PermissionMemberLimit"
        when: windowShown

        function cleanup() {
            memberPermissionsModel.clear()
        }

        function appendMemberPermissions(count) {
            memberPermissionsModel.clear()
            for (let i = 0; i < count; ++i) {
                memberPermissionsModel.append({
                    key: "perm-" + i,
                    permissionType: PermissionTypes.Type.Member,
                    isPrivate: false,
                    holdingsListModel: emptyModelComponent.createObject(memberPermissionsModel),
                    channelsListModel: emptyModelComponent.createObject(memberPermissionsModel)
                })
            }
        }

        function openCreateForm(permissionType) {
            const panel = createTemporaryObject(panelComponent, root)
            verify(!!panel)
            panel.pushEditView({})
            const editView = root.findByTypePrefix(panel, "EditPermissionView")
            verify(!!editView, "the create-permission form must be open")
            editView.permissionType = permissionType
            tryCompare(editView.dirtyValues, "permissionType", permissionType)
            // An empty "who holds" form is treated as a duplicate of every
            // holdings-less permission. Require holdings so the warning under
            // test is the member cap, not that duplicate check.
            editView.dirtyValues.holdingsRequired = true
            return editView
        }

        function test_sixthBecomeMemberPermissionShowsWarning() {
            appendMemberPermissions(5)
            const editView = openCreateForm(PermissionTypes.Type.Member)

            const warning = findChild(editView, "duplicationPanel")
            verify(!!warning)
            tryCompare(warning, "visible", true)
            compare(warning.text,
                    PermissionTypes.getPermissionsLimitWarning(PermissionTypes.Type.Member))

            const createButton = findChild(editView, "createPermissionButton")
            verify(!!createButton)
            compare(createButton.enabled, false)
        }

        function test_fourBecomeMemberPermissionsHaveNoWarning() {
            appendMemberPermissions(4)
            const editView = openCreateForm(PermissionTypes.Type.Member)

            const warning = findChild(editView, "duplicationPanel")
            verify(!!warning)
            tryCompare(warning, "visible", false)
        }

        function test_nonMemberTypeIgnoresTheMemberCap() {
            appendMemberPermissions(5)
            const editView = openCreateForm(PermissionTypes.Type.Admin)

            const warning = findChild(editView, "duplicationPanel")
            verify(!!warning)
            tryCompare(warning, "visible", false)
        }
    }
}
