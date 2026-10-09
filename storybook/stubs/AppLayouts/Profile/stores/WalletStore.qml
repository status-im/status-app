import QtQuick

QtObject {
    property var walletModule: QtObject {
        property bool hasPairedDevices: false
    }

    property var accountsModule: null
    property var selectedAccount
    property var accounts: null

    //! The report fetchHttpTrafficReport() answers with, as the JSON-RPC
    //! envelope status-go returns, before the query narrows its endpoints.
    property string httpTrafficStatsJson: JSON.stringify({result: null, error: {message: "not mocked"}})

    signal loggedInUserAuthenticated(string requestedBy, string password, string pin, string keyUid, string keycardUid)
    signal httpTrafficStatsReset()
    signal httpTrafficReportFetched(string report, string error, string endpoints, string key)

    //! How many reports were asked for, to see when a screen polls.
    property int httpTrafficStatsReads: 0
    //! The query of the latest request.
    property var httpTrafficQuery: ({endpoints: "", key: ""})

    //! Holds answers back until releaseHttpTrafficReport(), to see requests overlap.
    property bool holdHttpTrafficReports: false
    readonly property bool httpTrafficReadPending: _heldQuery !== null
    property var _heldQuery: null

    function fetchHttpTrafficReport(endpoints, key) {
        httpTrafficStatsReads++
        httpTrafficQuery = {endpoints: endpoints, key: key}
        _heldQuery = {endpoints: endpoints, key: key}
        if (!holdHttpTrafficReports)
            Qt.callLater(releaseHttpTrafficReport)
    }

    //! Answers the request on its way, with the report as it is now.
    function releaseHttpTrafficReport() {
        const query = _heldQuery
        if (!query)
            return
        _heldQuery = null
        holdHttpTrafficReports = false
        const response = JSON.parse(httpTrafficStatsJson)
        if (response.result) {
            const all = response.result.endpoints || []
            response.result.endpoints = query.endpoints === "all" ? all
                : query.endpoints === "source" ? all.filter(e => e.source === query.key)
                : query.endpoints === "host" ? all.filter(e => e.host === query.key)
                : []
        }
        httpTrafficReportFetched(JSON.stringify(response), "", query.endpoints, query.key)
    }
    function resetHttpTrafficStats() { httpTrafficStatsReset() }

    signal httpTrafficStatsEnabledSet(bool enabled)
    function setHttpTrafficStatsEnabled(enabled) {
        const response = JSON.parse(httpTrafficStatsJson)
        if (response.result) {
            response.result.enabled = enabled
            httpTrafficStatsJson = JSON.stringify(response)
        }
        httpTrafficStatsEnabledSet(enabled)
    }

    function authenticateLoggedInUser(_requestedBy) {}
    function deleteAccount(_address, _password) { return "" }
    function updateAccount(_address, _accountName, _colorId, _emoji) { return "" }
    function updateWatchAccountHiddenFromTotalBalance(_address, _hideFromTotalBalance) {}
}
