.pragma library

var appearanceProperties = ["font", "color", "linkColor", "codeBackground", "codeFontFamily", "codeBorderColor", "codeBlockPadding", "codeBlockRadius", "lineHeight", "selectionColor", "selectionTextColor", "hoverHighlightColor", "quoteBarColor", "quoteBarWidth", "quoteSpacing", "emojiOnlyPixelSize", "editedMarkerFontSize", "editedMarkerColor", "mentionColor", "mentionBackground", "quoteColor"]

function create(testCase, component, parent, properties) {
    const values = Object.assign({}, properties || {})
    const style = {}
    for (const key of appearanceProperties) {
        if (key in values) { style[key] = values[key]; delete values[key] }
    }
    if ("segments" in values) {
        // Initial properties need typed values; ordinary QML assignments can
        // construct structured values directly from object literals.
        testCase.initialSegments = values.segments
        values.segments = testCase.initialSegments
    }
    const item = testCase.createTemporaryObject(component, parent, values)
    if (item) for (const key in style) item.appearance[key] = style[key]
    return item
}
