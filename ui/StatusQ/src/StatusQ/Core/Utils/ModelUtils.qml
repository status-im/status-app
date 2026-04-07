pragma ComponentBehavior: Bound

pragma Singleton

import QtQuick

import StatusQ
import QtModelsToolkit as QtMT

QtObject {
    function get(model: var, index: int, role = ""): var {
        if (role)
            return QtMT.ModelQuery.get(model, index, role)
        else
            return QtMT.ModelQuery.get(model, index)
    }

    function getByKey(model: var, keyRole: string, keyValue: var, role = ""): var {
        const idx = indexOf(model, keyRole, keyValue)

        if (idx === -1)
            return null

        return get(model, idx, role)
    }

    function modelToArray(model: var, roles: var): var {
        if (!model)
            return []

        if (roles === undefined)
            roles = roleNames(model)

        const count = model.rowCount()
        const array = []

        for (let i = 0; i < count; i++) {
            const modelItem = QtMT.ModelQuery.get(model, i)
            const arrayItem = {}

            roles.forEach(role => {
                const entry = modelItem[role]
                const isModel = QtMT.ModelQuery.isModel(entry)

                if (isModel)
                    arrayItem[role] = modelToArray(entry)
                else if (entry !== undefined)
                    arrayItem[role] = entry
            })

            array.push(arrayItem)
        }

        return array
    }

    function modelToFlatArray(model: var, role: string): var {
        return modelToArray(model, [role]).map(entry => entry[role])
    }

    function joinModelEntries(model: var, role: string, separator: string): string {
        return modelToFlatArray(model, role).join(separator)
    }

    function indexOf(model: var, role: string, key: var): int {
        return QtMT.ModelQuery.indexOf(model, role, key)
    }

    function persistentIndex(model: var, index: int): var {
        return QtMT.ModelQuery.persistentIndex(model, index)
    }

    function contains(model: var, roleName: string, value: var, mode = Qt.CaseSensitive): bool {
        return QtMT.ModelQuery.contains(model, roleName, value, mode)
    }

    function checkItemsEquality(itemA: var, itemB: var, roles: var): bool {
        return roles.every((role) => itemA[role] === itemB[role])
    }

    function checkEqualityStrict(modelA: var, modelB: var, roles: var): bool {
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

    function checkEqualitySet(modelA: var, modelB: var, roles: var): bool {
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

    function roleNames(model: var): var {
        return QtMT.ModelQuery.roleNames(model)
    }

    /// Returns the first model entry that satisfies the condition function or null if none is found.
    function getFirstModelEntryIf(model: var, conditionFn: var): var {
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

    function forEach(model: var, callback: var): void {
        if (!model)
            return

        const count = model.rowCount()

        for (let i = 0; i < count; i++) {
            const modelItem = QtMT.ModelQuery.get(model, i)
            callback(modelItem)
        }
    }
}
