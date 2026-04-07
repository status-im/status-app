pragma ComponentBehavior: Bound

import QtQml

QtObject {
    property var modelA: null
    property var modelB: null

    property var roles: []
    property int mode: ModelsComparator.CompareMode.Strict

    readonly property alias equal: d.equal

    enum CompareMode {
        Strict, Set
    }

    readonly property QtObject _d: QtObject {
        id: d

        readonly property ModelChangeTracker trackerA: ModelChangeTracker {
            model: modelA
        }

        readonly property ModelChangeTracker trackerB: ModelChangeTracker {
            model: modelB
        }

        readonly property int revision: trackerA.revision + trackerB.revision

        readonly property bool equal: checkEquality(modelA, modelB, roles, mode,
                                                    revision)

        function checkEquality(modelA: var, modelB: var, roles: var, mode: int, dummy: int): bool {
            if (mode === ModelsComparator.CompareMode.Strict)
                return ModelUtils.checkEqualityStrict(modelA, modelB, roles)

            return ModelUtils.checkEqualitySet(modelA, modelB, roles)
        }
    }
}
