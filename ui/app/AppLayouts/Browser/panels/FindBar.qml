/****************************************************************************
**
** Copyright (C) 2019 The Qt Company Ltd.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the QtWebEngine module of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:BSD$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** BSD License Usage
** Alternatively, you may use this file under the terms of the BSD license
** as follows:
**
** "Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are
** met:
**   * Redistributions of source code must retain the above copyright
**     notice, this list of conditions and the following disclaimer.
**   * Redistributions in binary form must reproduce the above copyright
**     notice, this list of conditions and the following disclaimer in
**     the documentation and/or other materials provided with the
**     distribution.
**   * Neither the name of The Qt Company Ltd nor the names of its
**     contributors may be used to endorse or promote products derived
**     from this software without specific prior written permission.
**
**
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
** "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
** LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
** A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
** OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
** SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
** LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
** DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
** THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
** OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
**
** $QT_END_LICENSE$
**
****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ.Core.Theme
import StatusQ.Controls

import shared.controls

import utils

Rectangle {
    id: root

    property int numberOfMatches: 0
    property int activeMatch: 0
    property alias text: findTextField.text

    function reset() {
        numberOfMatches = 0;
        activeMatch = 0;
        visible = false;
    }

    signal findNext()
    signal findPrevious()

    radius: Theme.radius

    border.width: 0
    color: Theme.palette.background

    layer.enabled: true
    layer.effect: DropShadow {
        width: root.width
        height: root.height
        x: root.x
        y: root.y + 10
        visible: root.visible
        source: root
        horizontalOffset: 0
        verticalOffset: 2
        radius: 10
        samples: 15
        color: Theme.palette.dropShadow
    }

    function forceActiveFocus() {
        findTextField.forceActiveFocus();
    }

    onVisibleChanged: {
        if (visible)
            forceActiveFocus()
    }


    RowLayout {
        anchors.fill: parent
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        anchors.leftMargin: 10
        anchors.rightMargin: 10

        spacing: 5

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StatusTextField {
                id: findTextField
                anchors.fill: parent

                onAccepted: root.findNext()
                onTextChanged: root.findNext()
                onActiveFocusChanged: activeFocus ? selectAll() : deselect()
            }
        }

        Label {
            text: activeMatch + "/" + numberOfMatches
            visible: findTextField.text !== ""
        }

        Rectangle {
            border.width: 1
            border.color: Theme.palette.border
            width: 2
            height: parent.height
            anchors.topMargin: 5
            anchors.bottomMargin: 5
        }

        StatusFlatRoundButton {
            id: prevBtn
            implicitWidth: 32
            implicitHeight: 32
            icon.name: "previous"
            enabled: numberOfMatches > 0
            type: StatusFlatRoundButton.Type.Tertiary
            onClicked: root.findPrevious()
        }

        StatusFlatRoundButton {
            id: nextBtn
            implicitWidth: 32
            implicitHeight: 32
            icon.name: "next"
            enabled: numberOfMatches > 0
            type: StatusFlatRoundButton.Type.Tertiary
            onClicked: root.findNext()
        }

        StatusFlatRoundButton {
            id: closeBtn
            implicitWidth: 32
            implicitHeight: 32
            icon.name: "close-circle"
            type: StatusFlatRoundButton.Type.Tertiary
            onClicked:  root.visible = false
        }
    }
}
