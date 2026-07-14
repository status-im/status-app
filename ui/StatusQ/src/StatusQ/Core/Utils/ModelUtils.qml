pragma Singleton

import QtQuick

import StatusQ
import QtModelsToolkit as QtMT

QtObject {
    function get(model, index, role = "") {
        if (role)
            return QtMT.ModelQuery.get(model, index, role)
        else
            return QtMT.ModelQuery.get(model, index)
    }

    function getByKey(model, keyRole, keyValue, role = "") {
        const idx = indexOf(model, keyRole, keyValue)

        if (idx === -1)
            return null

        return get(model, idx, role)
    }

    function modelToArray(model, roles) {
        if (!model)
            return []

        // When the caller asks for a subset of roles, fetch only those roles per
        // row via the single-role ModelQuery.get overload. The all-roles get
        // materializes EVERY role (incl. submodel roles like "balances") into a
        // QVariantMap and marshals it to JS on every row, even when the caller reads
        // just one role (e.g. joinModelEntries(model, "key")) — O(N * allRoles). The
        // per-role path is O(N * requestedRoles). With no roles given we still want
        // every role, and the single all-roles get is the cheaper way to get them.
        const explicitRoles = roles !== undefined
        if (!explicitRoles)
            roles = roleNames(model)

        const count = model.rowCount()
        const array = []

        for (let i = 0; i < count; i++) {
            const arrayItem = {}

            if (explicitRoles) {
                roles.forEach(role => {
                    const entry = QtMT.ModelQuery.get(model, i, role)
                    const isModel = QtMT.ModelQuery.isModel(entry)

                    if (isModel)
                        arrayItem[role] = modelToArray(entry)
                    else if (entry !== undefined)
                        arrayItem[role] = entry
                })
            } else {
                const modelItem = QtMT.ModelQuery.get(model, i)

                roles.forEach(role => {
                    const entry = modelItem[role]
                    const isModel = QtMT.ModelQuery.isModel(entry)

                    if (isModel)
                        arrayItem[role] = modelToArray(entry)
                    else if (entry !== undefined)
                        arrayItem[role] = entry
                })
            }

            array.push(arrayItem)
        }

        return array
    }

    function modelToFlatArray(model, role) {
        return modelToArray(model, [role]).map(entry => entry[role])
    }

    function joinModelEntries(model, role, separator) {
        return modelToFlatArray(model, role).join(separator)
    }

    function indexOf(model, role, key) {
        if (key === null || key === undefined || (typeof key === "number" && isNaN(key)))
            return -1
        return QtMT.ModelQuery.indexOf(model, role, key)
    }

    function persistentIndex(model, index) {
        return QtMT.ModelQuery.persistentIndex(model, index)
    }

    function contains(model, roleName, value, mode = Qt.CaseSensitive) {
        if (value === null || value === undefined || (typeof value === "number" && isNaN(value)))
            return false
        return QtMT.ModelQuery.contains(model, roleName, value, mode)
    }

    function checkItemsEquality(itemA, itemB, roles) {
        return roles.every((role) => itemA[role] === itemB[role])
    }

    function checkEqualityStrict(modelA, modelB, roles) {
        if (modelA === modelB)
            return true

        const countA = !!modelA ? modelA.rowCount() : 0
        const countB = !!modelB ? modelB.rowCount() : 0

        if (countA !== countB)
            return false

        if (countA === 0)
            return true

        for (let i = 0; i < countA; i++) {
            const itemA = QtMT.ModelQuery.get(modelA, i)
            const itemB = QtMT.ModelQuery.get(modelB, i)

            if (!checkItemsEquality(itemA, itemB, roles))
                return false
        }

        return true
    }

    function checkEqualitySet(modelA, modelB, roles) {
        if (modelA === modelB)
            return true

        const countA = !!modelA ? modelA.rowCount() : 0
        const countB = !!modelB ? modelB.rowCount() : 0

        if (countA !== countB)
            return false

        if (countA === 0)
            return true

        for (let i = 0; i < countA; i++) {
            const itemA = QtMT.ModelQuery.get(modelA, i)
            let found = false

            for (let j = 0; j < countB; j++) {
                const itemB = QtMT.ModelQuery.get(modelB, j)

                if (checkItemsEquality(itemA, itemB, roles))
                    found = true
            }

            if (!found)
                return false
        }

        return true
    }

    function roleNames(model) {
        return QtMT.ModelQuery.roleNames(model)
    }

    /// Returns the first model entry that satisfies the condition function or null if none is found.
    function getFirstModelEntryIf(model, conditionFn) {
        if (!model)
            return null

        const count = model.rowCount()

        for (let i = 0; i < count; i++) {
            const modelItem = QtMT.ModelQuery.get(model, i)

            if (conditionFn(modelItem)) {
                return modelItem
            }
        }

        return null
    }

    function forEach(model, callback) {
        if (!model)
            return

        const count = model.rowCount()

        for (let i = 0; i < count; i++) {
            const modelItem = QtMT.ModelQuery.get(model, i)
            callback(modelItem)
        }
    }
}
