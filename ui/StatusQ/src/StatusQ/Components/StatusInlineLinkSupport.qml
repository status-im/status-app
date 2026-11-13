pragma ComponentBehavior: Bound

import QtQuick

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme

// Adapts resolved links into text segments and decorates the supplied renderer.
// The caller owns the renderer and binds its segments to this component's output.
Item {
    id: root

    required property ChatTextItem textItem
    property list<chatTextSegment> sourceSegments
    // URL -> { title, image?, path?: [{ text, icon? }], trailingIcons?: [iconName | {image}] }
    // Avatar + title are followed by optional breadcrumb entries and end icons.
    property var links: ({})

    readonly property list<chatTextSegment> segments: {
        if (!Object.keys(d.definitions).length)
            return root.sourceSegments
        return root.sourceSegments.map(segment => {
            const definition = d.definitions[segment.href]
            if (!definition || segment.code || segment.codeBlock || segment.text !== segment.href)
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
        readonly property var definitions: {
            const result = {}
            for (const url of Object.keys(root.links)) {
                const link = root.links[url]
                if (!link?.title)
                    continue
                let text = link.title
                const offsets = [0]
                const icons = [{avatar: true, name: link.title, image: link.image || ""}]
                for (const part of link.path || []) {
                    text += " › "
                    if (part.icon) {
                        offsets.push(text.length)
                        icons.push({icon: part.icon})
                    }
                    text += part.text
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

    Repeater {
        parent: root.textItem
        model: root.textItem.inlineLinkRects
        delegate: Rectangle {
            required property var modelData
            readonly property bool highlighted: !!modelData.href
                                               && (root.textItem.hoveredLink === modelData.href || root.textItem.highlightedLink === modelData.href)
            objectName: "inlineLinkBackground"
            z: -1
            x: modelData.rect.x
            y: modelData.rect.y
            width: modelData.rect.width
            height: modelData.rect.height
            radius: Math.min(Theme.radius, height / 2)
            color: root.textItem.appearance ? (highlighted ? root.textItem.appearance.hoverHighlightColor : root.textItem.appearance.mentionBackground)
                                   : (highlighted ? Theme.palette.primaryColor3 : Theme.palette.baseColor2)
        }
    }

    Repeater {
        parent: root.textItem
        model: root.textItem.inlineIconRects
        delegate: Loader {
            id: decoration
            required property var modelData
            readonly property var segment: root.textItem.segments[modelData.segmentIndex]
            readonly property var definition: segment ? d.definitions[segment.href] : null
            readonly property var icon: definition?.icons[modelData.iconIndex]
            x: modelData.rect.x
            y: modelData.rect.y
            width: modelData.rect.width
            height: modelData.rect.height
            active: !!icon
            sourceComponent: icon?.avatar ? avatarComponent : icon?.image ? imageComponent : glyphComponent

            Component {
                id: imageComponent
                StatusImage {
                    objectName: "inlineLinkImage"
                    source: decoration.icon?.image || ""
                    fillMode: Image.PreserveAspectFit
                }
            }

            Component {
                id: avatarComponent
                StatusSmartIdenticon {
                    objectName: "inlineLinkAvatar"
                    name: decoration.icon?.name || ""
                    asset.name: decoration.icon?.image || ""
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
                    readonly property color linkColor: root.textItem.appearance ? root.textItem.appearance.linkColor : Theme.palette.primaryColor1
                    asset.name: decoration.icon?.icon || ""
                    asset.width: decoration.icon?.filled ? Math.max(0, width - 4) : width
                    asset.height: decoration.icon?.filled ? Math.max(0, height - 4) : height
                    asset.bgWidth: width
                    asset.bgHeight: height
                    asset.bgRadius: 4
                    asset.bgColor: decoration.icon?.filled ? linkColor : "transparent"
                    asset.color: decoration.icon?.filled ? "white" : linkColor
                }
            }
        }
    }
}
