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

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

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

    color: Theme.palette.background

    function forceActiveFocus() {
        findTextField.forceActiveFocus();
    }

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus()
            findNext()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        anchors.leftMargin: 10
        anchors.rightMargin: 10

        StatusTextField {
            id: findTextField
            background: Rectangle {
                color: Theme.palette.baseColor2
                radius: Theme.radius
            }
            font.pixelSize: Theme.fontSize(14)
            Layout.fillWidth: true
            Layout.fillHeight: true
            onAccepted: root.findNext()
            onTextEdited: root.findNext()
            onActiveFocusChanged: activeFocus ? selectAll() : deselect()
        }

        StatusBaseText {
            text: root.activeMatch + "/" + root.numberOfMatches
            visible: findTextField.text !== ""
            font.pixelSize: Theme.fontSize(14)
        }

        StatusFlatRoundButton {
            implicitWidth: 32
            implicitHeight: 32
            icon.name: "chevron-up"
            enabled: root.numberOfMatches > 0
            type: StatusFlatRoundButton.Type.Tertiary
            onClicked: root.findPrevious()
        }

        StatusFlatRoundButton {
            implicitWidth: 32
            implicitHeight: 32
            icon.name: "chevron-down"
            enabled: root.numberOfMatches > 0
            type: StatusFlatRoundButton.Type.Tertiary
            onClicked: root.findNext()
        }

        StatusFlatRoundButton {
            implicitWidth: 32
            implicitHeight: 32
            icon.name: "close-circle"
            type: StatusFlatRoundButton.Type.Tertiary
            onClicked: root.visible = false
        }
    }
}
