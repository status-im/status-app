import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ
import StatusQ.Core

import Models
import Storybook

import utils

import AppLayouts.Chat.controls

Item {
    id: root

    ThreadHeader {
        Tracer {}
        anchors.centerIn: parent
        width: 300
        threadId: "thread-id"
        threadName: "Boring thread name"
        parentChatName: "#general"
        canEdit: true
        pending: false

        onEditNameRequested: beginEditing()
        onRenameRequested: name => {
                               threadName = name
                               editFinished(name === "" ? "Empty name not allowed" : "")
                           }

    }
}

// category: Controls
// status: good
