.pragma library

function normalizeIcon(iconUrl) {
    return iconUrl ? iconUrl.toString().replace("image://favicon/", "") : ""
}

function snapshotGrabSize(width, height, maxWidth, maxHeight) {
    const w = Number(width) || 0
    const h = Number(height) || 0
    if (w <= 0 || h <= 0)
        return Qt.size(maxWidth, maxHeight)

    const scale = Math.min(maxWidth / w, maxHeight / h, 1)
    return Qt.size(
        Math.max(1, Math.round(w * scale)),
        Math.max(1, Math.round(h * scale))
    )
}

function findSavedTab(savedTabs, uid) {
    if (!savedTabs || !uid)
        return null

    for (let i = 0; i < savedTabs.length; i++) {
        const tab = savedTabs[i]
        if (tab && tab.uuid === uid)
            return tab
    }
    return null
}

function resolveTitle(liveTitle, persistedRecord) {
    return liveTitle || (persistedRecord && persistedRecord.title) || ""
}

function resolveIcon(liveIconUrl, persistedRecord) {
    return normalizeIcon(liveIconUrl) || (persistedRecord && persistedRecord.icon) || ""
}

function displayTitle(webView, persistedRecord, labels) {
    const fallback = labels.emptyLabel || ""
    if (!webView)
        return fallback

    if (webView.isDownloadView)
        return labels.downloadsLabel || fallback

    const resolved = resolveTitle(webView.title || "", persistedRecord)
    if (resolved)
        return resolved

    if (labels.isStartPage)
        return labels.startPageLabel || fallback

    return fallback
}

function buildTabDto(webView, savedTabs, determineRealURL) {
    if (!webView || webView.offTheRecord)
        return null

    const rawUrl = webView.url.toString()
    const normalizedUrl = determineRealURL(rawUrl)
    if (!normalizedUrl)
        return null

    const uid = webView.uid || ""
    const persisted = findSavedTab(savedTabs, uid)

    return {
        uuid: uid,
        url: normalizedUrl,
        title: resolveTitle(webView.title || "", persisted),
        icon: resolveIcon(webView.icon, persisted)
    }
}
