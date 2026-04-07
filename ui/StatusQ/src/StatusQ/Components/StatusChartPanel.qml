pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import StatusQ.Controls

import "private/chart"

/*!
     \qmltype StatusChartPanel
     \inherits Page
     \inqmlmodule StatusQ.Components
     \since StatusQ.Components 0.1
     \brief Displays a chart component together with an optional header in order to add a list of options.
     Inherits \l{https://doc.qt.io/qt-5/qml-qtquick-controls2-page.html}{Page}.

     The \c StatusChartPanel displays a customizable chart component. Additionally, options
     can be added in the header in both right and left sides given graphTabsModel and timeRangeTabsModel
     property are set respectively.

     For example:

     \qml
     StatusChartPanel {
        id: graphDetail
        width: parent.width
        height: 290
        anchors.verticalCenter: parent.verticalCenter
        graphsModel: d.graphTabsModel
        timeRangeModel: d.timeRangeTabsModel
        chart.chartType: 'line'
        chart.chartData: {
            return {
                datasets: [{
                    data: d.data
                }],
                ...
            }
        }
        chart.chartOptions: {
            return {
                legend: {
                    display: false
                },
                ...
            }
        }
    }
    \endqml

    \image status_chart_panel.png

    For a list of components available see StatusQ.
*/

Page {
    id: root

    /*!
        \qmlproperty var StatusChartPanel::graphsModel
        This property holds the graphs model options to be set on the left side tab bar of the header.
        The JS array entries are expected to be objects with the following properties:
        - text (string): The text to be displayed on the tab
        - enabled (bool): Whether the tab is enabled or not
        - isTimeRange (bool): Whether the tab is a time range tab or graph type tab
        - privateIdentifier (string): An optional unique identifier for the tab that will be received \c headerTabClicked signal. Otherwise, the text will be used.
    */
    property var graphsModel
    /*!
        \qmlproperty var StatusChartPanel::timeRangeModel
        This property holds the time range options to be set on the right side tab bar of the header.
    */
    property var timeRangeModel

    /*!
        \qmlproperty alias StatusChartPanel::graphComponent
        This property holds holds a reference to the graph component.
    */
    property alias chart: graphComponent

    /*!
        \qmlproperty alias StatusChartPanel::timeRangeTabBarIndex
        This property holds holds a reference to the time range tab bar current index.
    */
    property alias timeRangeTabBarIndex: timeRangeTabBar.currentIndex

    /*!
        \qmlproperty string StatusChartPanel::selectedTimeRange
        This property holds holds the text of the current time range tab bar selected tab.

        \todo no need for undefined state, make tab models declaratively
    */
    property string selectedTimeRange: timeRangeTabBar.currentItem ? timeRangeTabBar.currentItem.text : ""

    /*!
        \qmlproperty string StatusChartPanel::defaultTimeRangeIndexShown
        This property holds the index of the time range tabbar to be shown by default
    */
    property int defaultTimeRangeIndexShown: 0

    /*!
        \qmlproperty int StatusChartPanel::headerLeftPadding
        This property holds the left padding of the header.
    */
    property int headerLeftPadding: 46

    /*!
        \qmlproperty int StatusChartPanel::headerBottomPadding
        This property holds the bottom padding of the header.
    */
    property int headerBottomPadding: 0

    /*!
        \qmlsignal
        This signal is emitted when a header tab bar is clicked.
    */
    signal headerTabClicked(var privateIdentifier, bool isTimeRange)

    Component {
        id: tabButton
        StatusTabButton {
            property var privateIdentifier: null
            property bool isTimeRange: false

            leftPadding: 0
            width: visible ? implicitWidth: 0
            onClicked: {
                root.headerTabClicked(privateIdentifier, isTimeRange);
            }
        }
    }

    Component.onCompleted: {
        if (!!timeRangeModel) {
            for (var i = 0; i < timeRangeModel.length; i++) {
                var timeTab = tabButton.createObject(root, { text: timeRangeModel[i].text,
                                                             enabled: timeRangeModel[i].enabled,
                                                             isTimeRange: true,
                                                             privateIdentifier: timeRangeModel[i].text });
                timeRangeTabBar.addItem(timeTab);
            }
            timeRangeTabBar.currentIndex = defaultTimeRangeIndexShown
        }
        if (!!graphsModel) {
            for (var j = 0; j < graphsModel.length; j++) {
                var graphTab = tabButton.createObject(root, { text: graphsModel[j].text,
                                                              enabled: graphsModel[j].enabled,
                                                              visible: graphsModel[j].visible,
                                                              isTimeRange: false,
                                                              privateIdentifier: typeof graphsModel[j].id !== "undefined" ? graphsModel[j].id : null});
                graphsTabBar.addItem(graphTab);
            }
        }
    }

    background: null
    header: Item {
        height: childrenRect.height + root.headerBottomPadding
        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: root.headerLeftPadding
            anchors.right: parent.right
            StatusTabBar {
                id: graphsTabBar
            }
            StatusTabBar {
                id: timeRangeTabBar
                Layout.alignment: Qt.AlignRight
            }
        }
    }

    contentItem: Item {
        ChartCanvas {
            id: graphComponent
            anchors.fill: parent
        }
    }
}
