.pragma library

function walkItemTree(item, visitFn) {
    if (!item)
        return
    visitFn(item)
    if (item.contentItem)
        walkItemTree(item.contentItem, visitFn)
    if (item.footer)
        walkItemTree(item.footer, visitFn)
    const kids = item.children
    if (!kids)
        return
    for (let i = 0; i < kids.length; ++i)
        walkItemTree(kids[i], visitFn)
}

function walkHeaderButtons(item, out) {
    if (!item)
        return
    if (item.icon !== undefined && item.icon.name !== undefined
            && item.incognitoMode !== undefined)
        out.push(item)
    const kids = item.children
    if (!kids)
        return
    for (let i = 0; i < kids.length; ++i)
        walkHeaderButtons(kids[i], out)
}

function headerButtonByIcon(root, iconName) {
    const buttons = []
    walkHeaderButtons(root.contentItem || root, buttons)
    for (let i = 0; i < buttons.length; ++i) {
        if (buttons[i].icon.name === iconName)
            return buttons[i]
    }
    return null
}

function flatButtonByIcon(root, iconName) {
    let match = null
    walkItemTree(root, function(o) {
        if (match)
            return
        if (o.icon !== undefined && o.icon.name === iconName)
            match = o
    })
    return match
}

function menuEntryByText(menu, text) {
    for (let i = 0; i < menu.count; ++i) {
        const item = menu.itemAt(i)
        if (item && item.text === text)
            return item
    }
    return null
}

function addressFieldInToolbar(toolbar) {
    let field = null
    walkItemTree(toolbar.contentItem || toolbar, function(o) {
        if (field)
            return
        if (o.placeholderText !== undefined
                && String(o.placeholderText).indexOf("Search or enter") >= 0)
            field = o
    })
    return field
}

function itemByText(root, text) {
    let match = null
    walkItemTree(root, function(o) {
        if (match)
            return
        if (o.text === text)
            match = o
    })
    return match
}
