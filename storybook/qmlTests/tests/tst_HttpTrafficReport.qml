import QtQuick
import QtTest

import "../../../ui/app/AppLayouts/Profile/views/HttpTrafficReport.js" as Report

TestCase {
    name: "HttpTrafficReport"

    function source(name, requests, sent, received) {
        return {source: name, requests: requests, bytesSent: sent, bytesReceived: received}
    }

    function endpoint(host, source, requests, bundles, bundledCalls) {
        return {host: host, source: source, requests: requests, bundles: bundles, bundledCalls: bundledCalls}
    }

    function test_hourlyWaitsForAMinute() {
        compare(Report.hourly(1000, 59), -1)
        compare(Report.hourly(1000, 60), 60000)
        compare(Report.hourly(500, 1800), 1000)
    }

    function test_elapsedSecondsTakesGoNanoseconds() {
        compare(Report.elapsedSeconds(null), 0)
        compare(Report.elapsedSeconds({since: "2026-10-02T13:16:28.663257123+04:00",
                                       until: "2026-10-02T14:16:28.663999+04:00"}), 3600)
    }

    function test_hostSharesPoolTheRest() {
        const hosts = [{host: "a", bytesSent: 50, bytesReceived: 10},
                       {host: "b", bytesSent: 20, bytesReceived: 0},
                       {host: "c", bytesSent: 5, bytesReceived: 5},
                       {host: "d", bytesSent: 5, bytesReceived: 5}]
        const shares = Report.hostShares(hosts, 2)
        compare(shares.length, 3)
        compare(shares[0].host, "a")
        compare(shares[0].share, 0.6)
        compare(shares[2].host, "")
        compare(shares[2].others, 2)
        compare(shares[2].bytes, 20)
        compare(shares.reduce((sum, s) => sum + s.share, 0), 1)
    }

    function test_hostSharesWithoutTrafficDoNotDivideByZero() {
        compare(Report.hostShares([], 3), [])
        compare(Report.hostShares([{host: "a", bytesSent: 0, bytesReceived: 0}], 3)[0].share, 0)
    }

    function test_endpointsOfASourceOrHost() {
        const all = [endpoint("h1", "S", 1, 0, 0), endpoint("h2", "S", 1, 0, 0), endpoint("h1", "T", 1, 0, 0)]
        compare(Report.endpointsOf(all, "source", "S").length, 2)
        compare(Report.endpointsOf(all, "host", "h1").length, 2)
    }

    function test_detailsOfTheTopSourceUseTheHeadlineFacts() {
        const report = {
            sources: [source("Balances", 20, 49900000, 1000000)],
            hosts: [],
            insights: {topSource: "Balances", bytesPerRequest: 900000, callsPerBundle: 2500}
        }
        const d = Report.details(report, "source", "Balances",
                                 [endpoint("rpc", "Balances", 10, 10, 1000), endpoint("rpc", "Balances", 10, 10, 3000)])
        compare(d.upload, true)
        compare(d.requests, 20, "the source row's requests")
        compare(d.perRequest, 900000, "not 49.9 MB / 20")
        compare(d.callsPerBundle, 2500, "not the average over both endpoints")
    }

    function test_detailsOfAnotherSourceWorkThemOut() {
        const report = {
            sources: [source("Balances", 1, 100, 0), source("Market", 4, 100, 4000)],
            hosts: [],
            insights: {topSource: "Balances", bytesPerRequest: 100, callsPerBundle: 0}
        }
        const d = Report.details(report, "source", "Market", [endpoint("m", "Market", 4, 0, 0)])
        compare(d.upload, false)
        compare(d.perRequest, 1000)
        compare(d.callsPerBundle, 0)
    }

    function test_detailsOfAHostCountItsEndpoints() {
        const report = {sources: [], hosts: [{host: "rpc", bytesSent: 300, bytesReceived: 100}]}
        const d = Report.details(report, "host", "rpc",
                                 [endpoint("rpc", "A", 2, 1, 10), endpoint("rpc", "B", 1, 1, 30)])
        compare(d.bytesSent, 300, "the host row's bytes")
        compare(d.requests, 3, "hosts carry no requests, the endpoints do")
        compare(d.perRequest, 100)
        compare(d.callsPerBundle, 20)
    }

    function test_shareIsOfItsOwnTable() {
        const report = {
            sources: [source("A", 1, 300, 0), source("B", 1, 100, 0)],
            hosts: [{host: "h", bytesSent: 1000, bytesReceived: 0}, {host: "g", bytesSent: 1000, bytesReceived: 0}]
        }
        compare(Report.details(report, "source", "A", []).share, 0.75, "of the sources, not the connections")
        compare(Report.details(report, "host", "h", []).share, 0.5)
        compare(Report.details({sources: [], hosts: []}, "source", "A", []).share, 0)
    }

    function test_detailsOfAnUnknownKeyAreEmpty() {
        const d = Report.details(null, "source", "gone", [])
        compare(d.bytesSent, 0)
        compare(d.requests, 0)
        compare(d.perRequest, 0)
    }
}
