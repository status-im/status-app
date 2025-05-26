import QtQuick 2.15
import QtQuick.Layouts 1.15

MouseArea {
    id: root

    hoverEnabled: true

    // readonly property bool inViewport: delegateRoot.y - delegateRoot.container.contentY + delegateRoot.height > 0 &&
    //                                    delegateRoot.container.contentY + delegateRoot.container.height - delegateRoot.y > 0

    //property Flickable container

    readonly property var delegateModel: model
    readonly property int index: model.index
    // readonly property int imagesSeed: model.imagesSeed

    Rectangle {
        visible: root.containsMouse
        anchors.fill: parent
        color: "#262629"
    }

    implicitHeight: column.height + column.y + 16

    AvatarImage {
        id: avatarImage

        source: model.avatar

        x: 16
        y: 16

        width: 40
        height: 40
    }

    ColumnLayout {
        id: column

        anchors.top: avatarImage.top
        anchors.left: avatarImage.right
        anchors.right: parent.right

        anchors.leftMargin: 16
        anchors.rightMargin: 16

        RowLayout {
            Text {
                id: usernameText

                color: "white"
                text: "michalc"// + ()
                font.bold: true
                wrapMode: Text.Wrap
            }

            Text {
                id: dateText

                Layout.fillWidth: true

                color: "#888991"
                font.pixelSize: 12
                text: model.date.toLocaleDateString(null, Locale.ShortFormat)
                      + ", " + model.date.toLocaleTimeString(null, Locale.ShortFormat)
                wrapMode: Text.Wrap
            }
        }

        TextEdit {
            color: "white"
            text: model.text// + " 🙂 🥰 🥸"
            wrapMode: Text.Wrap

            textFormat: Text.MarkdownText

            Layout.fillWidth: true

            selectByMouse: true
            readOnly: true
        }

        ImageGrid {
            model: root.delegateModel.images
        }
    }
}
