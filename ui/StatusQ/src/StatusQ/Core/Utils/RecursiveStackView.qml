pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

/*!
   \qmltype RecursiveStackView
   \inherits StackView
   \inqmlmodule StatusQ.Core.Utils

   \brief A utility wrapper over StackView allowing to compose StackViews in
    a convenient way.
*/
StackView {
    // this stack or nested one if currentItem is RecursiveStackView, recursively
    readonly property var topLevelStack: {
        if (currentItem instanceof RecursiveStackView)
            return currentItem.topLevelStack

        return this
    }

    // busy flag of this stack or nested one if currentItem is
    // RecursiveStackView, recusively
    readonly property bool topLevelStackBusy: topLevelStack.busy

    // currentItem of this stack or the nested stack if currentItem is
    // RecursiveStackView, recursively
    readonly property Item topLevelItem: {
        if (currentItem instanceof RecursiveStackView)
            return currentItem.topLevelItem

        return currentItem
    }

    // total depth, taking into account depth of nested stacks
    readonly property int totalDepth: {
        if (currentItem instanceof RecursiveStackView)
            return depth - 1 + currentItem.depth

        return depth
    }

    // pops from the current stack or nested one
    function popTopLevelItem(operation = StackView.Transition): void {
        if (topLevelStack.depth === 1)
            topLevelStack.StackView.view.pop(operation)
        else
            topLevelStack.pop(operation)
    }
}
