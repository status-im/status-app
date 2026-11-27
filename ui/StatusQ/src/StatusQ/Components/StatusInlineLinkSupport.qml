pragma ComponentBehavior: Bound

import QtQuick

import StatusQ
import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme

// Adapts resolved links into text segments and decorates the supplied renderer.
// The caller owns the renderer and binds its segments to this component's output.
Item {
    id: root

    required property ChatTextItem textItem
    property list<chatTextSegment> sourceSegments
    // URL -> { title, image?, emoji?, path?: [{ text, icon? }], trailingIcons?: [iconName | {image}] }
    // Avatar + title are followed by optional breadcrumb entries and end icons.
    property var links: ({})

    readonly property list<chatTextSegment> segments: {
        if (!Object.keys(d.definitions).length)
            return root.sourceSegments
        return root.sourceSegments.map(segment => {
            const definition = d.definitions[segment.href]
            if (!definition || segment.explicitLink || segment.code || segment.codeBlock || segment.text !== segment.href)
                return segment
            return Object.assign({}, segment, {
                text: definition.text,
                copyText: segment.href,
                inlineIconOffsets: definition.offsets,
                mention: true,
                bold: true,
                underline: false
            })
        })
    }

    QtObject {
        id: d

        function singleLine(text: string): string {
            return text.replace(/[\r\n\u2028\u2029]+/g, " ")
        }

        readonly property var definitions: {
            const result = {}
            for (const url of Object.keys(root.links)) {
                const link = root.links[url]
                if (!link?.title)
                    continue
                let text = d.singleLine(link.title)
                const offsets = [0]
                const icons = [link.emoji ? {emoji: link.emoji}
                                         : {avatar: true, name: text, image: link.image || ""}]
                for (const part of link.path || []) {
                    text += " › "
                    if (part.icon) {
                        offsets.push(text.length)
                        icons.push({icon: part.icon})
                    }
                    text += d.singleLine(part.text)
                }
                const trailing = link.trailingIcons || []
                for (let i = 0; i < trailing.length; ++i) {
                    text += i === 0 ? " › " : " "
                    offsets.push(text.length)
                    icons.push(typeof trailing[i] === "string" ? {icon: trailing[i], filled: true} : trailing[i])
                }
                result[url] = {text, offsets, icons}
            }
            return result
        }
    }

    // One delegate per icon, kept across relayouts: the model is the icon
    // count, and positions update through bindings.
    Repeater {
        parent: root.textItem
        model: root.textItem.inlineIconCount
        delegate: Loader {
            required property int index
            readonly property var placement: root.textItem.inlineIconRects[index] ?? null
            readonly property var icon: placement ? d.definitions[placement.href]?.icons[placement.iconIndex] ?? null : null
            readonly property color linkColor: root.textItem.appearance ? root.textItem.appearance.linkColor
                                                                        : Theme.palette.primaryColor1
            x: placement?.rect.x ?? 0
            y: placement?.rect.y ?? 0
            width: placement?.rect.width ?? 0
            height: placement?.rect.height ?? 0
            active: !!icon
            sourceComponent: icon?.emoji ? emojiComponent
                           : icon?.avatar ? avatarComponent
                           : icon?.image ? imageComponent : glyphComponent
        }
    }

    // Shared by every instance. The loaded item reads its icon from the
    // Loader it is loaded into, its parent.
    Component {
        id: emojiComponent
        StatusEmoji {
            objectName: "inlineLinkEmoji"
            emoji: parent?.icon?.emoji ?? ""
        }
    }

    Component {
        id: imageComponent
        StatusImage {
            objectName: "inlineLinkImage"
            source: parent?.icon?.image ?? ""
            fillMode: Image.PreserveAspectFit
        }
    }

    Component {
        id: avatarComponent
        StatusSmartIdenticon {
            objectName: "inlineLinkAvatar"
            name: parent?.icon?.name ?? ""
            asset.name: parent?.icon?.image ?? ""
            asset.isImage: true
            asset.isLetterIdenticon: !asset.name
            asset.width: Math.max(0, width - 2)
            asset.height: Math.max(0, height - 2)
            asset.color: Theme.palette.miscColor5
            asset.letterSize: Math.max(7, height / 2)
        }
    }

    Component {
        id: glyphComponent
        StatusRoundIcon {
            objectName: "inlineLinkIcon"
            readonly property bool filled: !!parent?.icon?.filled
            readonly property color linkColor: parent?.linkColor ?? Theme.palette.primaryColor1
            asset.name: parent?.icon?.icon ?? ""
            asset.width: filled ? Math.max(0, width - 4) : width
            asset.height: filled ? Math.max(0, height - 4) : height
            asset.bgWidth: width
            asset.bgHeight: height
            asset.bgRadius: 4
            asset.bgColor: filled ? linkColor : "transparent"
            asset.color: filled ? "white" : linkColor
        }
    }
}
