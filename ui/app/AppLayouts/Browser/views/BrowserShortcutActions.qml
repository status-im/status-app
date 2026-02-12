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

import StatusQ.Core.Utils  // for QObject

import AppLayouts.Browser.adapters

QObject {
    id: root

    property var currentWebView

    function triggerWebAction(action) {
        if (!currentWebView)
            return
        currentWebView.triggerWebAction(action)
    }

    signal activateAddressBar()
    signal hideFindBar()
    signal findNextRequested()
    signal findPreviousRequested()

    Shortcut {
        sequences: ["Ctrl+L", "F6"]
        onActivated: {
            root.activateAddressBar()
        }
    }
    Shortcut {
        sequences: [StandardKey.Refresh]
        onActivated: {
            triggerWebAction(AbstractWebView.WebAction.Reload)
        }
    }
    Shortcut {
        sequences: [StandardKey.Close]
        onActivated: {
            triggerWebAction(AbstractWebView.WebAction.RequestClose)
        }
    }
    Shortcut {
        sequence: "Escape"
        onActivated: {
            root.hideFindBar()
            triggerWebAction(AbstractWebView.WebAction.Stop)
        }
    }
    Shortcut {
        sequences: [StandardKey.Copy]
        onActivated: triggerWebAction(AbstractWebView.WebAction.Copy)
    }
    Shortcut {
        sequences: [StandardKey.Cut]
        onActivated: triggerWebAction(AbstractWebView.WebAction.Cut)
    }
    Shortcut {
        sequences: [StandardKey.Paste]
        onActivated: triggerWebAction(AbstractWebView.WebAction.Paste)
    }
    Shortcut {
        sequence: "Shift+"+StandardKey.Paste
        onActivated: triggerWebAction(AbstractWebView.WebAction.PasteAndMatchStyle)
    }
    Shortcut {
        sequences: [StandardKey.SelectAll]
        onActivated: triggerWebAction(AbstractWebView.WebAction.SelectAll)
    }
    Shortcut {
        sequences: [StandardKey.Undo]
        onActivated: triggerWebAction(AbstractWebView.WebAction.Undo)
    }
    Shortcut {
        sequences: [StandardKey.Redo]
        onActivated: triggerWebAction(AbstractWebView.WebAction.Redo)
    }
    Shortcut {
        sequences: [StandardKey.Back]
        onActivated: triggerWebAction(AbstractWebView.WebAction.Back)
    }
    Shortcut {
        sequences: [StandardKey.Forward]
        onActivated: triggerWebAction(AbstractWebView.WebAction.Forward)
    }
    Shortcut {
        sequences: [StandardKey.FindNext]
        onActivated: root.findNextRequested()
    }
    Shortcut {
        sequences: [StandardKey.FindPrevious]
        onActivated: root.findPreviousRequested()
    }
}
