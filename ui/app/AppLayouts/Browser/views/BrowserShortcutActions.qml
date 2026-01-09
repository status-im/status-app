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
import QtWebEngine

import StatusQ.Core.Utils  // for QObject

QObject {
    property var currentWebView
    property var findBarComponent
    property var browserHeaderComponent

    Shortcut {
        sequences: ["Ctrl+L", "F6"]
        onActivated: {
            browserHeaderComponent.activateAddressBar()
        }
    }
    Shortcut {
        sequences: [StandardKey.Refresh]
        onActivated: {
            if (currentWebView)
                currentWebView.triggerWebAction(WebEngineView.Reload)
        }
    }
    Shortcut {
        sequences: [StandardKey.Close]
        onActivated: currentWebView.triggerWebAction(WebEngineView.RequestClose)
    }
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (findBarComponent.visible)
                findBarComponent.visible = false;
            if (currentWebView)
                currentWebView.triggerWebAction(WebEngineView.Stop)
        }
    }
    Shortcut {
        sequences: [StandardKey.Copy]
        onActivated: currentWebView.triggerWebAction(WebEngineView.Copy)
    }
    Shortcut {
        sequences: [StandardKey.Cut]
        onActivated: currentWebView.triggerWebAction(WebEngineView.Cut)
    }
    Shortcut {
        sequences: [StandardKey.Paste]
        onActivated: currentWebView.triggerWebAction(WebEngineView.Paste)
    }
    Shortcut {
        sequence: "Shift+"+StandardKey.Paste
        onActivated: currentWebView.triggerWebAction(WebEngineView.PasteAndMatchStyle)
    }
    Shortcut {
        sequences: [StandardKey.SelectAll]
        onActivated: currentWebView.triggerWebAction(WebEngineView.SelectAll)
    }
    Shortcut {
        sequences: [StandardKey.Undo]
        onActivated: currentWebView.triggerWebAction(WebEngineView.Undo)
    }
    Shortcut {
        sequences: [StandardKey.Redo]
        onActivated: currentWebView.triggerWebAction(WebEngineView.Redo)
    }
    Shortcut {
        sequences: [StandardKey.Back]
        onActivated: currentWebView.triggerWebAction(WebEngineView.Back)
    }
    Shortcut {
        sequences: [StandardKey.Forward]
        onActivated: currentWebView.triggerWebAction(WebEngineView.Forward)
    }
    Shortcut {
        sequences: [StandardKey.FindNext]
        onActivated: findBarComponent.findNext()
    }
    Shortcut {
        sequences: [StandardKey.FindPrevious]
        onActivated: findBarComponent.findPrevious()
    }
}
