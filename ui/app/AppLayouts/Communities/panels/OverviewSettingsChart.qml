import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ.Popups
import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils

StatusChartPanel {
    id: root
    /**
        *  Flat model to use for the chart containing timestamps
        *  type: {Array}
        *  default: []
        *  example:  {"communityId": "", "metricsType": "MessagesCount", "intervals": [{"startTimestamp": 1691047800000, "endTimestamp": 1691062200000, "timestamps": [], "count": 0}]}
    */
    property var model: []

    signal collectCommunityMetricsMessagesCount(var intervals)

    function reset() {
        d.now = Date.now()
        d.requestCommunityMetrics()
    }

    onVisibleChanged: {
        if (visible) {
            chart.rebuild()
            d.resetWithSpamProtection()
        }
    }
    onTimeRangeTabBarIndexChanged: reset()
    onModelChanged: chart.refresh()
    onCollectCommunityMetricsMessagesCount: d.lastRequestModelMetadata = d.selectedTabInfo.modelItems

    QtObject {
        id: d

        //visual properties
        readonly property string baseColor1: Theme.palette.baseColor1
        readonly property string twentyPercentBaseColor1: StatusColors.alphaColor(baseColor1, 0.2)
        readonly property string barColor: Theme.palette.primaryColor2
        readonly property string barBorderColor: Theme.palette.primaryColor1
    
        readonly property string messagesLabel: qsTr("Messages")

        property int hoveredBarIndex: 0
        property int hoveredBarValue: 0
        readonly property var hoveredModelMetadata: modelMetadata[root.timeRangeTabBarIndex].modelItems[hoveredBarIndex]
        readonly property var tooltipConfig: modelMetadata[root.timeRangeTabBarIndex].tooltipConfig
        readonly property var graphTabsModel: [{text: messagesLabel, enabled: true}]
        property double now: Date.now()
        property var lastRequestModelMetadata: null

        readonly property var chartData: selectedTabInfo.modelItems.map(x => d.itemsCountInRange(root.model, x.start, x.end))
        readonly property var labels: selectedTabInfo.modelItems.map(x => x.label)
        readonly property var selectedTabInfo: modelMetadata[root.timeRangeTabBarIndex]
        readonly property var modelMetadata: [
            {
                text: qsTr("1H"),
                modelItems: [
                    { start: LocaleUtils.minutes(60, now), end: LocaleUtils.minutes(50, now), label: minutesStr(55)},
                    { start: LocaleUtils.minutes(50, now), end: LocaleUtils.minutes(40, now), label: minutesStr(45)},
                    { start: LocaleUtils.minutes(40, now), end: LocaleUtils.minutes(30, now), label: minutesStr(35)},
                    { start: LocaleUtils.minutes(30, now), end: LocaleUtils.minutes(20, now), label: minutesStr(25)},
                    { start: LocaleUtils.minutes(20, now), end: LocaleUtils.minutes(10, now), label: minutesStr(15)},
                    { start: LocaleUtils.minutes(10, now), end: LocaleUtils.minutes(0, now, false), label: minutesStr(5)}
                ],
                tooltipConfig: {
                    timeRangeString: qsTr("Time period"),
                    timeRangeFormatter: d.hoursRangeStr
                },
            },
            {
                text: qsTr("1D"),
                modelItems: [
                    { start: LocaleUtils.hours(24, now), end: LocaleUtils.hours(20, now), label: hourStr(22)},
                    { start: LocaleUtils.hours(20, now), end: LocaleUtils.hours(16, now), label: hourStr(18)},
                    { start: LocaleUtils.hours(16, now), end: LocaleUtils.hours(12, now), label: hourStr(14)},
                    { start: LocaleUtils.hours(12, now), end: LocaleUtils.hours(8, now), label: hourStr(10)},
                    { start: LocaleUtils.hours(8, now), end: LocaleUtils.hours(4, now), label: hourStr(6)},
                    { start: LocaleUtils.hours(4, now), end: LocaleUtils.hours(0, now, false), label: hourStr(2)}
                ],
                tooltipConfig: {
                    timeRangeString: qsTr("Time period"),
                    timeRangeFormatter: d.hoursRangeStr
                },
            },
            {
                text: qsTr("7D"),
                modelItems: [
                    { start: LocaleUtils.days(6, now), end: LocaleUtils.days(5, now), label: dayStr(6)},
                    { start: LocaleUtils.days(5, now), end: LocaleUtils.days(4, now), label: dayStr(5)},
                    { start: LocaleUtils.days(4, now), end: LocaleUtils.days(3, now), label: dayStr(4)},
                    { start: LocaleUtils.days(3, now), end: LocaleUtils.days(2, now), label: dayStr(3)},
                    { start: LocaleUtils.days(2, now), end: LocaleUtils.days(1, now), label: dayStr(2)},
                    { start: LocaleUtils.days(1, now), end: LocaleUtils.days(0, now), label: dayStr(1)},
                    { start: LocaleUtils.days(0, now), end: LocaleUtils.days(0, now, false), label: dayStr(0)}
                ],
                tooltipConfig: {
                    timeRangeString: qsTr("Date"),
                    timeRangeFormatter: d.daysRangeStr
                },
            },
            {
                text: qsTr("1M"),
                modelItems: [
                    { start: LocaleUtils.days(30, now), end: LocaleUtils.days(25, now), label: dayStr(30)},
                    { start: LocaleUtils.days(25, now),  end: LocaleUtils.days(20, now), label: dayStr(25)},
                    { start: LocaleUtils.days(20, now),  end: LocaleUtils.days(15, now), label: dayStr(20)},
                    { start: LocaleUtils.days(15, now),  end: LocaleUtils.days(10, now), label: dayStr(15)},
                    { start: LocaleUtils.days(10, now),   end: LocaleUtils.days(5, now), label: dayStr(10)},
                    { start: LocaleUtils.days(5, now),   end: LocaleUtils.days(0, now, false), label: dayStr(5)}
                ],
                tooltipConfig: {
                    timeRangeString: qsTr("Time period"),
                    timeRangeFormatter: d.daysRangeStr
                },
            },
            {
                text: qsTr("6M"),
                modelItems: [
                    { start: LocaleUtils.months(5, now), end: LocaleUtils.months(4, now), label: monthStr(5)},
                    { start: LocaleUtils.months(4, now), end: LocaleUtils.months(3, now), label: monthStr(4)},
                    { start: LocaleUtils.months(3, now), end: LocaleUtils.months(2, now), label: monthStr(3)},
                    { start: LocaleUtils.months(2, now), end: LocaleUtils.months(1, now), label: monthStr(2)},
                    { start: LocaleUtils.months(1, now), end: LocaleUtils.months(0, now), label: monthStr(1)},
                    { start: LocaleUtils.months(0, now), end: LocaleUtils.months(0, now, false), label: monthStr(0)}
                ],
                tooltipConfig: {
                    timeRangeString: qsTr("Month"),
                    timeRangeFormatter: d.monthsRangeStr
                },
            },
            {
                text: qsTr("1Y"),
                modelItems: [
                    { start: LocaleUtils.months(12, now), end: LocaleUtils.months(10, now), label: monthStr(11)},
                    { start: LocaleUtils.months(10, now), end: LocaleUtils.months(8, now),  label: monthStr(9)},
                    { start: LocaleUtils.months(8, now),  end: LocaleUtils.months(6, now),  label: monthStr(7)},
                    { start: LocaleUtils.months(6, now),  end: LocaleUtils.months(4, now),  label: monthStr(5)},
                    { start: LocaleUtils.months(4, now),  end: LocaleUtils.months(2, now),  label: monthStr(3)},
                    { start: LocaleUtils.months(2, now),  end: LocaleUtils.months(0, now, false),  label: monthStr(1)}
                ],
                tooltipConfig: {
                    timeRangeString: qsTr("Time period"),
                    timeRangeFormatter: d.monthsRangeStr
                },
            },
            {
                text: qsTr("ALL"),
                modelItems: [
                    { start: LocaleUtils.years(7, now), end: LocaleUtils.years(6, now), label: yearsStr(7) },
                    { start: LocaleUtils.years(6, now), end: LocaleUtils.years(5, now), label: yearsStr(6) },
                    { start: LocaleUtils.years(5, now), end: LocaleUtils.years(4, now), label: yearsStr(5) },
                    { start: LocaleUtils.years(4, now), end: LocaleUtils.years(3, now), label: yearsStr(4) },
                    { start: LocaleUtils.years(3, now), end: LocaleUtils.years(2, now), label: yearsStr(3) },
                    { start: LocaleUtils.years(2, now), end: LocaleUtils.years(1, now), label: yearsStr(2) },
                    { start: LocaleUtils.years(1, now), end: LocaleUtils.years(0, now), label: yearsStr(1) },
                    { start: LocaleUtils.years(0, now), end: LocaleUtils.years(0, now, false), label: yearsStr(0) }
                ],
                tooltipConfig: {
                    timeRangeString: qsTr("Year"),
                    timeRangeFormatter: d.yearsRangeStr
                },
            }
        ]

        function resetWithSpamProtection() {
            if(Date.now() - d.now > LocaleUtils.minutesToMs(5) || d.lastRequestModelMetadata != selectedTabInfo.modelItems) {
                root.reset()
            }
        }

        function requestCommunityMetrics() {
            let intervals = d.selectedTabInfo.modelItems.map(item => {
                return {
                    startTimestamp: item.start,
                    endTimestamp: item.end
                }
            })
            root.collectCommunityMetricsMessagesCount(JSON.stringify(intervals))
        }

        function itemsCountInRange(model, start, end) {
            if (model == undefined || model.intervals == undefined)
                return 0

            const interval = model.intervals.find(x => x.startTimestamp == start && x.endTimestamp == end)

            if (!interval)
                return 0
            
            if(model.metricsType === "MessagesTimestamps")
                return interval.timestamps.length

            return interval.count
        }

        function minutesStr(before = 0, timeReference = now, roundCurrentTime = true) {
            return LocaleUtils.formatTime(LocaleUtils.minutes(before, timeReference, roundCurrentTime), Locale.ShortFormat)
        }

        function hourStr(before = 0, timeReference = now, roundCurrentTime = true) {
            return LocaleUtils.formatTime(LocaleUtils.hours(before, timeReference, roundCurrentTime), Locale.ShortFormat)
        }

        function dayStr(before = 0, timeReference = now, roundCurrentTime = true) {
            return LocaleUtils.getDayMonth(LocaleUtils.days(before, timeReference, roundCurrentTime), Locale.ShortFormat)
        }

        function monthStr(before = 0, timeReference = now, roundCurrentTime = true, shortFormat = true) {
            const timeStamp = LocaleUtils.months(before, timeReference, roundCurrentTime)
            return Qt.locale().standaloneMonthName(new Date(timeStamp).getMonth(), shortFormat ? Locale.ShortFormat : Locale.LongFormat)
        }

        function yearsStr(before = 0, timeReference = now, roundCurrentTime = true) {
            return LocaleUtils.formatDate(LocaleUtils.years(before, timeReference, roundCurrentTime), "yyyy");
        }

        function hoursRangeStr(start, end) {
            return "%1 - %2".arg(hourStr(0, start, false)).arg(hourStr(0, end, false))
        }

        function daysRangeStr(start, end) {
            return (end - start > LocaleUtils.daysToMs(1)) ?
                        "%1 - %2".arg(dayStr(0, start, false)).arg(dayStr(0, end, false)) :
                        dayStr(0, start, false)
        }

        function monthsRangeStr(start, end) {
            //End date excluded
            //Adjust by one ms to exclude the end date
            //To avoid considering the end date as a new month
            end = end - 1
            const startDate = monthStr(0, start, false)
            const endDate = monthStr(0, end, false)
            return (startDate !== endDate) ?
                        "%1 - %2".arg(startDate).arg(endDate) :
                        monthStr(0, start, false, false)
        }

        function yearsRangeStr(start, end) {
            //End date excluded
            //Adjust by one ms to exclude the end date
            //To avoid considering the end date as a new year
            end = end - 1
            const startYear = yearsStr(0, start, false)
            const endYear = yearsStr(0, end, false)
            return (startYear !== endYear) ?
                        "%1 - %2".arg(startYear).arg(endYear) :
                        startYear
        }

        function getAdjustedTooltipPosition(event) {
            // By default the popup is displayed on the right of the cursor
            // If there is not enough space on the right, display it on the left
            const relativeMousePoint = event.target.mapToItem(toolTip.parent, event.x, event.y) // relative to tooltip parent
            const leftPositon = (toolTip.parent.width - (toolTip.width + toolTip.rightPadding + relativeMousePoint.x + 15)) < 0
            return leftPositon ? Qt.point(relativeMousePoint.x - toolTip.width - 15, relativeMousePoint.y - 5)
                               : Qt.point(relativeMousePoint.x + 15, relativeMousePoint.y - 5)
        }
    }

    headerLeftPadding: 0
    headerBottomPadding: Theme.bigPadding
    graphsModel: d.graphTabsModel
    timeRangeModel: d.modelMetadata
    onHeaderTabClicked: {
        chart.refresh()
    }

    /////////////////////////////
    // Chartjs configuration   //
    /////////////////////////////
    chart.type: 'bar'
    chart.labels: d.labels
    chart.datasets: [{
                xAxisId: 'x-axis-1',
                yAxisId: 'y-axis-1',
                backgroundColor: d.barColor,
                pointRadius: 0,
                hoverBackgroundColor: d.barColor,
                hoverBorderColor: d.barBorderColor,
                hoverBorderWidth: 2,
                data: d.chartData
            }]

    chart.options: {
        return {
            // Popup follows the cursor
            onHover: function(arg1, hoveredItems) {
                if(!arg1 || hoveredItems.length == 0) {
                    toolTip.close()
                    return
                }
                arg1.target = chart
                d.hoveredBarIndex = hoveredItems[0]._index
                d.hoveredBarValue = hoveredItems[0]._chart.config.data.datasets[0].data[hoveredItems[0]._index]
                const position = d.getAdjustedTooltipPosition(arg1)
                toolTip.popup(position.x, position.y)
            },
            tooltips: {
                enabled: false,
            },
            legend: {
                display: false
            },
            scales: {
                xAxes: [{
                    id: 'x-axis-1',
                    position: 'bottom',
                    stacked: false,
                    gridLines: {
                        drawOnChartArea: false,
                        drawBorder: false,
                        drawTicks: false,
                    },
                    ticks: {
                        fontSize: Theme.asideTextFontSize,
                        fontColor: d.baseColor1,
                        padding: Theme.padding,
                    }
                }],
                yAxes: [{
                    position: 'left',
                    id: 'y-axis-1',
                    stacked: false,
                    gridLines: {
                        borderDash: [5, 3],
                        lineWidth: 1,
                        drawBorder: false,
                        drawTicks: false,
                        color: d.twentyPercentBaseColor1,
                    },
                    beforeDataLimits: (axis) => {
                        axis.paddingTop = 25;
                        axis.paddingBottom = 0;
                    },
                    ticks: {
                        fontSize: Theme.asideTextFontSize,
                        fontColor: d.baseColor1,
                        padding: Theme.halfPadding,
                        maxTicksLimit: Theme.asideTextFontSize,
                        beginAtZero: true,
                        stepSize: 1,
                        callback: function(value, index, values) {
                            return LocaleUtils.numberToLocaleString(value)
                        }
                    }
                }]
            }
        }
    }

    StatusMenu {
        id: toolTip
        width: 243 //By design
        topPadding: Theme.padding
        bottomPadding: topPadding
        leftPadding: topPadding
        rightPadding: topPadding
        parent: Overlay.overlay

        ColumnLayout {
            spacing: Theme.padding
            RowLayout {
                Layout.fillWidth: true
                StatusBaseText {
                    elide: Qt.ElideRight
                    color: Theme.palette.baseColor1
                    text: d.tooltipConfig.timeRangeString
                }
                Item {
                    Layout.fillWidth: true
                }
                StatusBaseText {
                    Layout.alignment: Qt.AlignRight
                    elide: Qt.ElideRight
                    text: d.hoveredModelMetadata ? d.tooltipConfig.timeRangeFormatter(d.hoveredModelMetadata.start, d.hoveredModelMetadata.end)
                                                 : ""
                }
            }

            RowLayout {
                Layout.fillWidth: true
                StatusBaseText {
                    elide: Qt.ElideRight
                    font.pixelSize: Theme.primaryTextFontSize
                    color: Theme.palette.baseColor1
                    text: qsTr("No. of Messages")
                }
                Item {  Layout.fillWidth: true }
                StatusBaseText {
                    Layout.alignment: Qt.AlignRight
                    elide: Qt.ElideRight
                    font.pixelSize: Theme.primaryTextFontSize
                    color: Theme.palette.directColor1
                    text: LocaleUtils.numberToLocaleString(d.hoveredBarValue)
                }
            }
        }
    }
}
