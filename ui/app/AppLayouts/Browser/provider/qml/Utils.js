.pragma library

function accountsDidChange(oldAccounts, newAccounts) {
    const a = oldAccounts || []
    const b = newAccounts || []

    if (a.length !== b.length) return true

    const setA = new Set(a.map(addr => addr.toLowerCase()))
    const setB = new Set(b.map(addr => addr.toLowerCase()))

    return setA.size !== setB.size || ![...setA].every(addr => setB.has(addr))
}

function normalizeOrigin(url) {
    if (!url) return ""
    try {
        const urlObj = new URL(url.toString())
        // This ensures https://opensea.io/ and https://opensea.io/path both become https://opensea.io
        return urlObj.origin
    } catch (e) {
        let normalized = url.toString()
        if (normalized.endsWith("/")) {
            normalized = normalized.slice(0, -1)
        }
        return normalized
    }
}

// Convert decimal chainId to hex string (e.g., 1 -> "0x1", 137 -> "0x89")
function chainIdToHex(chainIdDecimal) {
    if (typeof chainIdDecimal !== "number" || chainIdDecimal < 0) {
        console.error("[Utils] Invalid chainId:", chainIdDecimal)
        return "0x1"  // Default to Mainnet
    }
    return "0x" + chainIdDecimal.toString(16)
}

// Parse chainId from any format (hex string or decimal) to decimal number
function parseChainId(chainId) {
    if (typeof chainId === "number") {
        return chainId
    }
    if (typeof chainId === "string") {
        if (chainId.startsWith("0x")) {
            return parseInt(chainId, 16)
        }
        return parseInt(chainId, 10)
    }
    return 1  // Default to Mainnet
}

// Extract domain name from URL string
function extractDomainName(urlString) {
    try {
        const urlObj = new URL(urlString)
        return urlObj.hostname || "Unknown dApp"
    } catch (e) {
        return "Unknown dApp"
    }
}

// Convert image://favicon/URL?query to direct URL
function normalizeFaviconUrl(url) {
    return (url?.toString() ?? "").replace(/^image:\/\/favicon\/([^?]*).*/, "$1")
}

function validateDAppIcon(iconUrl, siteUrl) {
    const iconStr = iconUrl ? iconUrl.toString() : ""
    if (!iconStr || iconStr === "undefined") {
        return {valid: false, iconUrl: "", reason: "empty"}
    }

    if (!iconStr.startsWith("image://favicon/")) {
        return {valid: true, iconUrl: iconStr, reason: "direct"}
    }

    const faviconDomain = extractDomainName(iconStr.replace("image://favicon/", "").split("?")[0])
    const siteDomain = extractDomainName(siteUrl)

    if (faviconDomain.includes(siteDomain) || siteDomain.includes(faviconDomain)) {
        return {valid: true, iconUrl: normalizeFaviconUrl(iconStr), reason: "match"}
    }

    return { valid: false, iconUrl: "", reason: "domain_mismatch" }
}

