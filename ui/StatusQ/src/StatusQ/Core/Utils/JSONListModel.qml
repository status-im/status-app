pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models

/**
  Converts JSON string array to ListModel

  JSONListModel {
    id: jsonModel

    json: JSON.stringify([
        {
            "name": "Activism",
            "emoji": "✊",
        },
        {
            "name": "Career",
            "emoji": "💼",
        },
    ])
  }

  TagsRow {
    model: jsonModel.model
  }
 */

Item {
    id: root

    property string json
    readonly property ListModel model: ListModel { id: jsonModel }

    onJsonChanged: {
        jsonModel.clear()

        if (json === "") return

        try {
            const arr = JSON.parse(json)
            for (const i in arr) {
                jsonModel.append(arr[i])
            }
        }
        catch (e) {
            console.warn(e)
        }
    }
}
