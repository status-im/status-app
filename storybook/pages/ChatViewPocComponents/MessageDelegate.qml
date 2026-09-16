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

    // Simulated device load ///////////////////////////////////////////////////
    //
    // Two knobs rather than one, because a chat view feels slow for two
    // different reasons and they surface in different places:
    //
    //   buildComplexity -- objects constructed per delegate. Paid once, on the
    //     GUI thread, in the frame that realises the delegate. This is what a
    //     windowing shift costs, where 40 delegates are built in one go, and
    //     what makes moreUpRequested/moreDownRequested visible as a stall.
    //
    //   paintComplexity -- wrapped rich text laid out on every width change and
    //     drawn through an offscreen buffer every frame. This is what scrolling
    //     costs, frame after frame, and it is the half a weak GPU loses on.
    //
    // Both default to zero, so the delegate is exactly what it was unless a
    // page asks for weight.
    property int buildComplexity: 0
    property int paintComplexity: 0

    // Objects per group in the build ballast. Total is roughly
    // buildComplexity * (1 + objectsPerGroup) plus Repeater bookkeeping.
    readonly property int objectsPerGroup: 7

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

    // What the delegate costs to build ////////////////////////////////////////

    Item {
        id: buildBallast

        // Never drawn. Repeater instantiates regardless of visibility, so these
        // are built in full and then cost nothing per frame - the point is to
        // move instantiation cost only, leaving paintComplexity to own the
        // per-frame side.
        visible: false
        width: 0
        height: 0

        Repeater {
            model: root.buildComplexity

            Item {
                id: group

                required property int index

                Repeater {
                    model: root.objectsPerGroup

                    Item {
                        id: node

                        required property int index

                        readonly property int serial: group.index * root.objectsPerGroup + node.index
                        readonly property string label: "m" + root.index + "n" + node.serial
                        readonly property bool flagged: node.serial % 3 === 0
                        readonly property real weight: (node.serial % 17) / 17
                        readonly property string summary: node.label + (node.flagged ? "!" : "")
                                                          + node.weight.toFixed(3)
                    }
                }
            }
        }
    }

    // What the delegate costs to draw /////////////////////////////////////////

    Item {
        id: paintBallast

        // Fills the delegate and clips, so the copies below are laid out in full
        // and then cropped: the cost is real while the delegate's height stays
        // whatever the message content made it. Anchoring here cannot feed back
        // into implicitHeight, which is driven by `column` alone.
        anchors.fill: parent
        clip: true

        visible: root.paintComplexity > 0

        // Faint, but genuinely drawn - an invisible subtree builds no scene
        // graph nodes and rasterises no glyphs, which would make this knob a
        // second, slower copy of buildComplexity instead of its counterpart.
        opacity: 0.18

        // Pushes the whole delegate-sized subtree through an offscreen buffer,
        // which is the other thing a low end GPU struggles with.
        layer.enabled: root.paintComplexity > 0

        Column {
            width: paintBallast.width

            Repeater {
                model: root.paintComplexity

                // MarkdownText on purpose: parsing plus shaping plus line
                // breaking is what actually dominates a real message delegate,
                // so the knob scales the cost that matters rather than adding
                // cheap rectangles.
                Text {
                    width: paintBallast.width

                    color: "#ff6b6b"
                    wrapMode: Text.Wrap
                    textFormat: Text.MarkdownText
                    text: root.delegateModel.text
                }
            }
        }
    }
}
