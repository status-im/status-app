import QtQuick

import StatusQ.Core

import utils

ChartDataBase {
    id: root

    function setTimeAndValueData(data, range) {
        var marketValues = []
        var timeRanges = []
        var skipped = 0
        for (var i = 0; i < data.length; ++i) {
            var closeValue = Number(data[i].close)
            if (isNaN(closeValue) || typeof data[i].close === "undefined" || closeValue === 0) {
                skipped++
                continue
            }

            var label = range === ChartDataBase.TimeRange.Weekly || range === ChartDataBase.TimeRange.Monthly ?
                        LocaleUtils.getDayMonth(data[i].time * 1000):
                        LocaleUtils.getMonthYear(data[i].time * 1000)
            marketValues.push(closeValue)
            timeRanges.push(label)
        }

        switch(range) {
        case ChartDataBase.TimeRange.Weekly: {
            weeklyData = marketValues
            weeklyTimeRange = timeRanges
            break
        }
        case ChartDataBase.TimeRange.Monthly: {
            monthlyData = marketValues
            monthlyTimeRange = timeRanges
            break
        }
        case ChartDataBase.TimeRange.HalfYearly: {
            halfYearlyData = marketValues
            halfYearlyTimeRange = timeRanges
            break
        }
        case ChartDataBase.TimeRange.Yearly: {
            yearlyData = marketValues
            yearlyTimeRange = timeRanges
            break
        }
        case ChartDataBase.TimeRange.All: {
            allData = marketValues
            allTimeRange = timeRanges
            if(data.length > 0)
                allTimeRangeTicks = Math.abs(Qt.formatDate(new Date(data[0].time*1000), 'yyyy') - Qt.formatDate(new Date(data[data.length-1].time*1000), 'yyyy'))
            break
        }
        }
    }
}
