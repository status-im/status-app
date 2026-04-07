pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme

/*!
   \qmltype StatusDatePicker
   \inherits StatusQ.Controls.StatusComboBox
   \inqmlmodule StatusQ.Components
   \since StatusQ.Components 0.1
   \brief Displays a date picker based on a combobox with a calendar popup

   The \c StatusDatePicker displays a date picker based on a combobox with a calendar popup.
   The property \p selectedDate reflects the currently chosen date (defaults to today).

   For a list of components available see StatusQ.
*/
StatusComboBox {
    id: root

    /*!
       \qmlproperty int StatusDatePicker::dateFormat

       This property specifies how the selected date will be displayed to the user.
       Either Locale.ShortFormat (default) or Locale.LongFormat
    */
    property int dateFormat: Locale.ShortFormat

    /*!
       \qmlproperty date StatusDatePicker::selectedDate

       This property holds the currently selected date; can be used for selecting an initial date too; defaults to "today"
       \sa QtQml.Date
    */
    property alias selectedDate: d.selectedDate

    /*!
       \qmlproperty bool StatusDatePicker::weekNumbersVisible

       This property holds whether the week number column should be visible. Defaults to true
    */
    property bool weekNumbersVisible: true

    /*!
       \qmlproperty string StatusDatePicker::customTodayText

       This property holds a special value which to display in case the current day is selected; defaults to qsTr("Today").
       Set to empty string if "today" shouldn't display anything special
    */
    property string customTodayText: qsTr("Today")

    readonly property alias isTodaySelected: d.isTodaySelected

    QtObject {
        id: d
        property date selectedDate: new Date()

        property int month: d.selectedDate.getMonth()
        property int year: d.selectedDate.getFullYear()

        readonly property bool selectingMonth: stackView.depth > 1

        readonly property date today: new Date()
        readonly property bool isTodaySelected: {
            return today.getDate() === d.selectedDate.getDate() &&
                    today.getMonth() === d.selectedDate.getMonth() &&
                    today.getFullYear() === d.selectedDate.getFullYear()
        }
    }

    indicatorIcon: "calendar"
    control.delegate: null
    control.displayText: d.isTodaySelected && root.customTodayText ? root.customTodayText
                                                                   : LocaleUtils.formatDate(d.selectedDate, root.dateFormat)
    control.implicitHeight: 44
    control.padding: 12
    control.leftPadding: 16
    control.popup.horizontalPadding: 16
    control.popup.verticalPadding: 16
    control.popup.width: 340

    control.popup.onAboutToShow: {
        // always open the popup showing the last (currently) selected date
        d.year = d.selectedDate.getFullYear()
        d.month = d.selectedDate.getMonth()
    }

    control.popup.contentItem: Item {
        LayoutMirroring.enabled: control.locale.textDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        WheelHandler {
            orientation: Qt.Vertical
            onWheel: {
                const delta = event.angleDelta.y/-120
                d.selectingMonth ? d.year += delta : d.month += delta
            }
        }
        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                spacing: 0
                StatusFlatButton {
                    Layout.fillHeight: true
                    Layout.preferredWidth: height
                    icon.name: LayoutMirroring.enabled ? "next" : "previous"
                    icon.color: Theme.palette.directColor1
                    hoverColor: Theme.palette.statusMenu.hoverBackgroundColor
                    onClicked: {
                        // switch to previous month/year (and optionally prev year in January)
                        const date = new Date(d.year, d.month)
                        if (d.selectingMonth)
                            date.setFullYear(date.getFullYear() - 1)
                        else
                            date.setMonth(date.getMonth() - 1)
                        d.month = date.getMonth()
                        d.year = date.getFullYear()
                    }
                    StatusToolTip {
                        text: d.selectingMonth ? qsTr("Previous year") : qsTr("Previous month")
                        visible: parent.hovered
                    }
                }
                Item { Layout.fillWidth: true }
                StatusFlatButton {
                    Layout.fillHeight: true
                    text: d.selectingMonth ? d.year : "%1 %2".arg(control.locale.standaloneMonthName(d.month)).arg(d.year)
                    font.weight: Font.Medium
                    textColor: Theme.palette.directColor1
                    hoverColor: Theme.palette.statusMenu.hoverBackgroundColor
                    borderColor: hoverColor
                    onClicked: {
                        if (d.selectingMonth) {
                            const thisYear = d.today.getFullYear()
                            if (d.year !== thisYear)
                                d.year = thisYear // switch to current year
                            else
                                stackView.pop(null, StackView.Immediate) // switch back to regular calendar
                        } else {
                            stackView.push(yearMonthsComponent, StackView.Immediate) // switch to year/month selection
                        }
                    }
                    StatusToolTip {
                        text: qsTr("Select year/month")
                        visible: parent.hovered
                    }
                }
                Item { Layout.fillWidth: true }
                StatusFlatButton {
                    Layout.fillHeight: true
                    Layout.preferredWidth: height
                    icon.name: LayoutMirroring.enabled ? "previous" : "next"
                    icon.color: Theme.palette.directColor1
                    hoverColor: Theme.palette.statusMenu.hoverBackgroundColor
                    onClicked: {
                        // switch to next month/year (and optionally next year in December)
                        const date = new Date(d.year, d.month)
                        if (d.selectingMonth)
                            date.setFullYear(date.getFullYear() + 1)
                        else
                            date.setMonth(date.getMonth() + 1)
                        d.month = date.getMonth()
                        d.year = date.getFullYear()
                    }
                    StatusToolTip {
                        text: d.selectingMonth ? qsTr("Next year") : qsTr("Next month")
                        visible: parent.hovered
                    }
                }
            }

            StackView {
                id: stackView
                Layout.fillWidth: true
                Layout.preferredHeight: currentItem.implicitHeight
                initialItem: singleMonthGridComponent
            }
        }
    }

    Component {
        id: singleMonthGridComponent

        GridLayout {
            columns: 2

            DayOfWeekRow {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                Layout.column: root.weekNumbersVisible ? 1 : 0
                Layout.columnSpan: root.weekNumbersVisible ? 1 : 2
                spacing: 2
                background: Rectangle {
                    color: Theme.palette.baseColor4
                    radius: 8
                }
                delegate: StatusBaseText {
                    text: model.shortName
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                locale: control.locale
            }

            WeekNumberColumn {
                Layout.fillHeight: true
                month: d.month
                year: d.year
                visible: root.weekNumbersVisible
                spacing: 2
                background: Rectangle {
                    color: Theme.palette.baseColor4
                    radius: 8
                }
                delegate: StatusBaseText {
                    color: Theme.palette.directColor3
                    text: model.weekNumber
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                locale: control.locale
            }

            MonthGrid {
                Layout.fillWidth: true
                month: d.month
                year: d.year
                spacing: 2
                delegate: StatusFlatButton {
                    readonly property bool selected: d.selectedDate.getFullYear() === model.year &&
                                                     d.selectedDate.getMonth() === model.month &&
                                                     d.selectedDate.getDate() === model.day
                    radius: width/2
                    width: 40
                    height: 40
                    horizontalPadding: 0
                    verticalPadding: 0
                    text: model.day
                    normalColor: selected ? Theme.palette.primaryColor1 : "transparent"
                    textColor: selected && !hovered ? "white" : model.month === d.month ? Theme.palette.directColor1
                                                                                        : Theme.palette.baseColor1
                    borderColor: model.today && !selected ? Theme.palette.directColor9 : "transparent"
                    onClicked: {
                        d.selectedDate = model.today ? new Date() : model.date
                        root.control.popup.close()
                    }
                }
                locale: control.locale
            }
        }
    }


    Component {
        id: yearMonthsComponent

        Item {
            implicitHeight: childrenRect.height
            Grid {
                anchors.centerIn: parent
                columns: 3
                rowSpacing: 28
                columnSpacing: 17
                Repeater {
                    model: 12
                    delegate: StatusFlatButton {
                        readonly property bool selected: d.selectedDate.getMonth() === index && d.selectedDate.getFullYear() === d.year
                        readonly property bool currentMonth: d.today.getMonth() === index && d.today.getFullYear() === d.year
                        radius: height/2
                        normalColor: selected ? Theme.palette.primaryColor1 : "transparent"
                        textColor: selected && !hovered ? "white" : Theme.palette.directColor1
                        borderColor: currentMonth && !selected ? Theme.palette.directColor9 : "transparent"
                        text: control.locale.standaloneMonthName(index, Locale.ShortFormat)
                        onClicked: {
                            d.month = index
                            stackView.pop(null, StackView.Immediate)
                        }
                    }
                }
            }
        }
    }
}
