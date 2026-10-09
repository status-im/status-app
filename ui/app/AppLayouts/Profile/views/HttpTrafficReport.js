.pragma library

// Figures the HTTP statistics screen derives from a wallet_getHTTPTrafficReport
// report. Numbers only: wording and colours stay with the views.

function bytesOf(row) {
    return row.bytesSent + row.bytesReceived
}

//! Go writes nanoseconds, which Date.parse does not take.
function parseTime(rfc3339) {
    return Date.parse(rfc3339.replace(/(\.\d{3})\d+/, "$1"))
}

function elapsedSeconds(report) {
    return report ? Math.max(0, (parseTime(report.until) - parseTime(report.since)) / 1000) : 0
}

//! A rate is noise over a short window, so it waits for a minute of data; -1 until then.
function hourly(amount, seconds) {
    return seconds >= 60 ? amount * 3600 / seconds : -1
}

//! The first `shown` hosts on their own, then the rest pooled as one entry
//! with an empty host and `others` counting them. Shares add up to 1.
function hostShares(hosts, shown) {
    const shares = hosts.slice(0, shown).map(h => ({host: h.host, others: 0, bytes: bytesOf(h)}))
    const rest = hosts.slice(shown)
    if (rest.length > 0)
        shares.push({host: "", others: rest.length, bytes: rest.reduce((sum, h) => sum + bytesOf(h), 0)})
    const total = Math.max(shares.reduce((sum, h) => sum + h.bytes, 0), 1)
    shares.forEach(h => h.share = h.bytes / total)
    return shares
}

function endpointsOf(endpoints, kind, key) {
    return endpoints.filter(e => kind === "host" ? e.host === key : e.source === key)
}

//! What the details page of a source or host shows. Bytes come from the
//! overview's row so both pages agree; the endpoints add what the source and
//! host tables do not carry. For the source the headline names, the headline's
//! facts win so both say the same.
function details(report, kind, key, endpoints) {
    const sources = report ? report.sources || [] : []
    const hosts = report ? report.hosts || [] : []
    const whole = (kind === "host" ? hosts.find(h => h.host === key)
                                   : sources.find(s => s.source === key)) || {}
    const d = {bytesSent: whole.bytesSent || 0, bytesReceived: whole.bytesReceived || 0,
               background: whole.background, requests: 0, bundles: 0, bundledCalls: 0}
    for (const e of endpoints) {
        d.requests += e.requests
        d.bundles += e.bundles
        d.bundledCalls += e.bundledCalls
    }
    if (kind !== "host" && whole.requests !== undefined)
        d.requests = whole.requests
    d.upload = d.bytesSent >= d.bytesReceived
    // Sources and hosts count bytes differently (estimated per request against
    // per connection), so each is a share of its own table, as in the overview.
    const all = (kind === "host" ? hosts : sources).reduce((sum, row) => sum + bytesOf(row), 0)
    d.share = all > 0 ? (d.bytesSent + d.bytesReceived) / all : 0

    const facts = report && report.insights
    if (kind === "source" && facts && facts.topSource === key) {
        d.perRequest = facts.bytesPerRequest
        d.callsPerBundle = facts.callsPerBundle
    } else {
        d.perRequest = (d.upload ? d.bytesSent : d.bytesReceived) / Math.max(d.requests, 1)
        d.callsPerBundle = d.bundles > 0 ? Math.round(d.bundledCalls / d.bundles) : 0
    }
    return d
}
