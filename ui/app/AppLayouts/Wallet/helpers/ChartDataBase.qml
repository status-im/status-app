import QtQml

import utils

QtObject {
    id: root

    // @see src/app_service/service/token/async_tasks.nim BalanceHistoryTimeInterval
    enum TimeRange {
        Weekly = 0,
        Monthly,
        HalfYearly,
        Yearly,
        All
    }

    readonly property var timeRangeTabsModel: [
        {text: qsTr("7D"), enabled: true, timeRange: ChartDataBase.TimeRange.Weekly, timeIndex: 0},
        {text: qsTr("1M"), enabled: true, timeRange: ChartDataBase.TimeRange.Monthly, timeIndex: 1},
        {text: qsTr("6M"), enabled: true, timeRange: ChartDataBase.TimeRange.HalfYearly, timeIndex: 2},
        {text: qsTr("1Y"), enabled: true, timeRange: ChartDataBase.TimeRange.Yearly, timeIndex: 3},
        {text: qsTr("ALL"), enabled: true, timeRange: ChartDataBase.TimeRange.All,  timeIndex: 4}]

    property var weeklyData: []
    property var monthlyData: []
    property var halfYearlyData: []
    property var yearlyData: []
    property var allData: []

    property var weeklyTimeRange: []
    property var monthlyTimeRange: []
    property var halfYearlyTimeRange: []
    property var yearlyTimeRange: []
    property var allTimeRange: []

    property int monthlyMaxTicks: monthlyTimeRange.length/d.hoursInADay
    property int weeklyMaxTicks: weeklyTimeRange.length/d.hoursInADay
    property int halfYearlyMaxTicks: halfYearlyTimeRange.length/d.avgLengthOfMonth
    property int yearlyMaxTicks: yearlyTimeRange.length/d.avgLengthOfMonth
    property int allTimeRangeTicks: 0

    // BEWARE that timeRange, dataRange and maxTicks properties are coupled with the timeRangeTabsModel order through
    // indexing. See StatusChartPanel.timeRangeTabBarIndex
    readonly property var timeRange: [
        {'7D': weeklyTimeRange},
        {'1M': monthlyTimeRange},
        {'6M': halfYearlyTimeRange},
        {'1Y': yearlyTimeRange},
        {'ALL': allTimeRange}
    ]

    readonly property var dataRange: [
        {'7D': weeklyData},
        {'1M': monthlyData},
        {'6M': halfYearlyData},
        {'1Y': yearlyData},
        {'ALL': allData}
    ]

    readonly property var maxTicks: [
        {'7D': weeklyMaxTicks},
        {'1M': monthlyMaxTicks},
        {'6M': halfYearlyMaxTicks},
        {'1Y': yearlyMaxTicks},
        {'ALL': allTimeRangeTicks}
    ]

    /// \timeRange is the time range of the data that was updated
    signal newDataReady(string address, string tokenSymbol, string currencySymbol, int timeRange)

    function clear() {
        weeklyData = []
        weeklyTimeRange = []
        monthlyData = []
        monthlyTimeRange = []
        halfYearlyData = []
        halfYearlyTimeRange = []
        yearlyData = []
        yearlyTimeRange = []
        allData = []
        allTimeRange = []
        allTimeRangeTicks = 0
    }

    function timeRangeEnumToStr(enumVal) {
        return d.timeRangeEnumToPropertiesMap.get(enumVal).text
    }
    function timeRangeEnumToTimeIndex(enumVal) {
        return d.timeRangeEnumToPropertiesMap.get(enumVal).timeIndex
    }
    function timeRangeStrToEnum(str) {
        return d.timeRangeStrToEnumMap.get(str)
    }

    readonly property QtObject _d: QtObject {
        id: d

        readonly property int hoursInADay: 24
        readonly property int avgLengthOfMonth: 30
        property var timeRangeEnumToPropertiesMap: null
        property var timeRangeStrToEnumMap: null
    }

    Component.onCompleted: {
        if(d.timeRangeEnumToPropertiesMap === null) {
            d.timeRangeEnumToPropertiesMap = new Map()
            for (const x of timeRangeTabsModel) {
                d.timeRangeEnumToPropertiesMap.set(x.timeRange, x)
            }
            d.timeRangeStrToEnumMap = new Map()
            for (const x of d.timeRangeEnumToPropertiesMap.entries()) {
                let key = x[0]
                let val = x[1]
                d.timeRangeStrToEnumMap.set(val.text, key)
            }
        }
    }
}
