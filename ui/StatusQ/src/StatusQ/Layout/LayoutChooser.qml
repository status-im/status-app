// Copyright (C) 2023 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls

Item {
    property var chosenLayout: undefined
    property list<bool> criteria: []
    property list<var> layoutChoices: []

    implicitWidth: chosenLayout.implicitWidth
    implicitHeight: chosenLayout.implicitHeight

    onCriteriaChanged: {
        showAndHide()
    }

    onLayoutChoicesChanged: {
        showAndHide()
    }

    function showAndHide() {
        const oldLayout = chosenLayout

        let i = 0
        for (; i < criteria.length; i++) {
            if (criteria[i])
                break
        }

        if (i < layoutChoices.length)
            chosenLayout = layoutChoices[i]
        else if (layoutChoices.length > 0)
            chosenLayout = layoutChoices[0]
        else
            return

        for (i = 0; i < layoutChoices.length; i++) {
            layoutChoices[i].visible = false
        }
        chosenLayout.visible = true
        chosenLayout.ensurePolished()
    }
}
