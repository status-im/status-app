import QtQuick

import StatusQ.Controls.Validators

import AppLayouts.Communities.stores
import shared.stores
import utils

QtObject {
    id: root

    property UtilsStore utilsStore

    /**
      * communitiesStore and myDisplayName are optional. When provided
      */
    property CommunitiesStore communitiesStore
    property string myDisplayName

    readonly property list<StatusValidator> validators: [
        StatusValidator {
            name: "startsWithSpaceValidator"
            validate: t => !(t.startsWith(" ") || t.endsWith(" "))
            errorMessage: qsTr("Display Names can’t start or end with a space")
        },
        StatusRegularExpressionValidator {
            regularExpression: /^$|^[a-zA-Z0-9\-_\u0020]+$/
            errorMessage: qsTr("Invalid characters (use A-Z and 0-9, hyphens, underscores and spaces only)")
        },
        StatusMinLengthValidator {
            minLength: Constants.keypair.nameLengthMin
            errorMessage: qsTr("Display Names must be at least %n character(s) long",
                               "", Constants.keypair.nameLengthMin)
        },
        // TODO: Create `StatusMaxLengthValidator` in StatusQ
        StatusValidator {
            name: "maxLengthValidator"
            validate: t => t.length <= Constants.keypair.nameLengthMax
            errorMessage: qsTr("Display Names can’t be longer than %n character(s)",
                               "", Constants.keypair.nameLengthMax)
        },
        StatusValidator {
            name: "endsWith-ethValidator"
            validate: t => !(t.endsWith("-eth") || t.endsWith("_eth") || t.endsWith(".eth"))
            errorMessage: qsTr("Display Names can’t end in “.eth”, “_eth” or “-eth”")
        },
        StatusValidator {
            name: "isAliasValidator"
            validate: function (t) { return !root.utilsStore.isAlias(t) }
            errorMessage: qsTr("Adjective-animal Display Name formats are not allowed")
        },
        StatusValidator {
            name: "isDuplicateInComunitiesValidator"
            validate: displayName => {
                if (!root.communitiesStore || displayName === root.myDisplayName)
                    return true

                return !communitiesStore.isDisplayNameDupeOfCommunityMember(displayName)
            }
            errorMessage: qsTr("This Display Name is already in use in one of your joined communities")
        }
    ]
}
