pragma Singleton

import QtCore
import QtQml

QtObject {
    id: root

    readonly property var userInputLocale: {
        const loc = Qt.locale()
        loc.numberOptions |= Locale.OmitGroupSeparator // no thousands separator in number-to-string functions
        return loc
    }

    function integralPartLength(num) {
        num = Math.abs(num)

        // According to the JS Reference:
        //
        // Scientific notation is used if the radix is 10 and the number's
        // magnitude (ignoring sign) is greater than or equal to 10^21 or less
        // than 10^-6. In this case, the returned string always explicitly
        // specifies the sign of the exponent.
        //
        // In order to take it into account, numbers in scientific notation
        // is handled separately.

        if (num < 1) {
            return 1
        }

        if (num >= 10**21) {
            const split = num.toString().split('e')
            if (split.length === 2) {
                const base = parseFloat(split[0])
                const exp = parseInt(split[1], 10)
                return integralPartLength(base) + exp
            }
        }

        return num.toFixed().length
    }

    function fractionalPartLength(num) {
        if (Number.isInteger(num))
            return 0

        // According to the JS Reference:
        //
        // Scientific notation is used if the radix is 10 and the number's
        // magnitude (ignoring sign) is greater than or equal to 10^21 or less
        // than 10^-6. In this case, the returned string always explicitly
        // specifies the sign of the exponent.
        //
        // In order to take it into account, numbers in scientific notation
        // is handled separately.

        if (Math.abs(num) < 10**-6) {
            const split = num.toString().split('e-')
            const base = parseFloat(split[0])
            const exp = parseInt(split[1])
            return fractionalPartLength(base) + exp
        }

        if (num >= 10**21) {
            return 0
        }

        console.assert(typeof num !== "undefined", "passed number should not be undefined")
        return num.toString().split('.')[1].length
    }


    function stripTrailingZeroes(numStr, locale) {
        locale = locale || Qt.locale()
        let regEx = locale.decimalPoint === "." ? /(\.[0-9]*[1-9])0+$|\.0*$/ : /(\,[0-9]*[1-9])0+$|\,0*$/
        return numStr.replace(regEx, '$1')
    }

    function numberToLocaleString(num, precision = -128 /* QLocale::FloatingPointShortest */, locale = null) {
        locale = locale || Qt.locale()

        return num.toLocaleString(locale, 'f', precision)
    }

    function formattedDataSize(bytes, precision = 2, locale = null) {
        locale = locale || Qt.locale()

        return locale.formattedDataSize(bytes || 0, precision, Locale.DataSizeTraditionalFormat)
    }

    function currencyNumberToLocaleString(num, symbol = "", locale = null) {
        locale = locale || Qt.locale()

        if (typeof num === "string")
            num = Number(num)

        return num.toLocaleCurrencyString(locale, symbol)
    }

    function numberToLocaleStringInCompactForm(num, locale = null) {
        locale = locale || Qt.locale()
        const numberOfDigits = integralPartLength(num)
        let oneArgStrFormat = "%1"
        let multiplier = 1
        if(numberOfDigits >=4 && numberOfDigits < 7) { // 1K - 999K
            multiplier = 1 / 1000
            oneArgStrFormat = qsTr("%1K", "Thousand")
        } else if(numberOfDigits >= 7 && numberOfDigits < 10) { // 1M - 999M
            multiplier = 1 / 1000000
            oneArgStrFormat = qsTr("%1M", "Million")
        } else if(numberOfDigits >= 10 && numberOfDigits < 13) { // 1B - 999B
            multiplier = 1 / 1000000000
            oneArgStrFormat = qsTr("%1B", "Billion")
        } else if(numberOfDigits >= 13 && numberOfDigits < 16) { // 1T - 999T
            multiplier = 1 / 1000000000000
            oneArgStrFormat = qsTr("%1T", "Trillion")
        }

        const stringNumber = numberToLocaleString(num * multiplier, 2, locale)
        return oneArgStrFormat.arg(stripTrailingZeroes(stringNumber, locale))
    }

    function numberFromLocaleString(num, locale = null) {
        locale = locale || Qt.locale()
        try {
            return Number.fromLocaleString(locale, num)
        } catch (_) {
            return NaN
        }
    }

    function getLocalizedDigitsCount(str, locale = null) {
        if (!str)
            return 0

        locale = locale || Qt.locale()

        if (d.nonDigitCharacterRegExpLocale !== locale)
            d.nonDigitCharacterRegExpLocale = locale

        return str.replace(d.nonDigitCharacterRegExp, "").length
    }

    enum RoundingMode {
        Default,
        Up,
        Down
    }

    function currencyAmountToLocaleString(currencyAmount, options = null, locale = null) {
        if (!currencyAmount) {
            return qsTr("N/A")
        }
        if (typeof(currencyAmount) !== "object") {
            console.warn("Wrong type for currencyAmount: " + JSON.stringify(currencyAmount))
            console.trace()
            return qsTr("N/A")
        }
        if (typeof currencyAmount.amount === "undefined")
            return qsTr("N/A")

        let currencyValue = currencyAmount.amount

        if (currencyAmount.symbol === "Gwei") {
            // Special case when currency amount must be converted to float to properly display it
            currencyValue = currencyAmount.amount / Math.pow(10, currencyAmount.displayDecimals)
        }

        locale = locale || Qt.locale()

        // Parse options
        var optNoSymbol = false
        var optRawAmount = false
        var optDisplayDecimals = currencyAmount.displayDecimals
        var optStripTrailingZeroes = currencyAmount.stripTrailingZeroes
        var optRoundingMode = LocaleUtils.RoundingMode.Default
        if (options) {
            if (options.noSymbol !== undefined && options.noSymbol === true) {
                optNoSymbol = true
            }
            if (options.rawAmount !== undefined && options.rawAmount === true) {
                optRawAmount = true
            }
            if (options.minDecimals !== undefined && options.minDecimals > optDisplayDecimals) {
                optDisplayDecimals = options.minDecimals
            }
            if (options.stripTrailingZeroes !== undefined) {
                optStripTrailingZeroes = options.stripTrailingZeroes
            }
            if (options.roundingMode !== undefined) {
                optRoundingMode = options.roundingMode
            }
        }

        var amountStr = ""
        var amountSuffix = ""

        let minAmount = 10**-optDisplayDecimals
        if (currencyValue > 0 && currencyValue < minAmount && !optRawAmount) {
            // Handle amounts smaller than resolution
            amountStr = "<%1".arg(numberToLocaleString(minAmount, optDisplayDecimals, locale))
        } else {
            var amount
            var displayDecimals
            const numIntegerDigits = integralPartLength(currencyValue)
            const maxDigits = 11 // We add "B" suffix only after 999 Billion
            const maxDigitsToShowDecimal = 6 // We do not display decimal places after 1 million
            // For large numbers, we use the short scale system (https://en.wikipedia.org/wiki/Long_and_short_scales)
            // and 2 decimal digits.
            if (numIntegerDigits > maxDigits && !optRawAmount) {
                amount = currencyValue/10**9 // Billion => 9 zeroes
                displayDecimals = 2
                amountSuffix = qsTr("B", "Billion")
            } else {
                // For normal numbers, we show the whole integral part and as many decimal places not
                // not to exceed the maximum
                amount = currencyValue
                // For numbers over 1M , dont show decimal places
                if(numIntegerDigits > maxDigitsToShowDecimal) {
                    displayDecimals = 0
                } else {
                    displayDecimals = Math.min(optDisplayDecimals, Math.max(0, maxDigits - numIntegerDigits))
                }
            }
            if (optRoundingMode !== LocaleUtils.RoundingMode.Default) {
                let intAmount = amount * 10**displayDecimals
                if (optRoundingMode === LocaleUtils.RoundingMode.Up) {
                    intAmount = Math.ceil(intAmount)
                } else if (optRoundingMode === LocaleUtils.RoundingMode.Down) {
                    intAmount = Math.floor(intAmount)
                }
                amount = intAmount / 10**displayDecimals
            }

            amountStr = numberToLocaleString(amount, displayDecimals, locale)
            if (optStripTrailingZeroes) {
                amountStr = stripTrailingZeroes(amountStr, locale)
            }
        }

        // Add symbol
        if (currencyAmount.symbol && !optNoSymbol) {
            amountStr = "%1%2 %3".arg(amountStr).arg(amountSuffix).arg(currencyAmount.symbol)
        } else {
            amountStr = "%1%2".arg(amountStr).arg(amountSuffix)
        }

        return amountStr
    }

    // DATE/TIME
    readonly property var d: QtObject {
        id: d

        readonly property var amPmFormatChars: ["AP", "A", "ap", "a"]

        readonly property int msInADay: 86400000

        // try to parse date from a number or ISO string timestamp
        function readDate(value) {
            if (typeof value === "undefined") // default to "now" if omitted
                return new Date()
            if (typeof value === "string" || typeof value === "number")  // support reading ISO string or numeric timestamps
                return new Date(value)
            return value
        }

        // enforce correct 12/24 time format when not using defaults
        function fixupTimeFormatString(formatString) {
            if (settings.timeFormatUsesDefaults) // OS defaults, nothing to change
                return formatString
            if (settings.timeFormatUses24Hours) { // enforce 24h time format
                // remove any amPmFormatChars from the format string and use 0-23 hours (h->H, hh->HH)
                return formatString.replace(/\ba\b|\bap\b/ig, "").replace(/h/g, "H")
            } else { // enforce 12hr time format
                // use 0-12 hours (H->h, HH->h) and append any of amPmFormatChars to the format string
                var result = formatString.replace(/H/g, "h")
                if (!d.amPmFormatChars.some(ampm => result.includes(ampm)))
                    result = result.concat(" ap")
                return result
            }
        }

        property var nonDigitCharacterRegExpLocale

        readonly property var nonDigitCharacterRegExp: {
            const localizedNumbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map(
                    n => LocaleUtils.numberToLocaleString(n, 0, nonDigitCharacterRegExpLocale))

            return new RegExp(`[^${localizedNumbers.join("")}]`, "g")
        }
    }

    /* https://bugreports.qt.io/browse/QTBUG-135039 */
    readonly property var settings: Settings {
        category: "Locale"
        property bool timeFormatUsesDefaults: true
        property bool timeFormatUses24Hours: is24hTimeFormatDefault()
    }

    function is24hTimeFormatDefault() {
        const timeFormatString = Qt.locale().timeFormat(Locale.LongFormat)
        return !d.amPmFormatChars.some(ampm => timeFormatString.includes(ampm))
    }

    // return full days between 2 dates
    function daysBetween(firstDate, secondDate) {
        return Math.abs(daysTo(firstDate, secondDate))
    }

    // return full days from first to second date
    function daysTo(firstDate, secondDate) {
        const d1 = new Date(firstDate)
        const d2 = new Date(secondDate)
        d1.setHours(0, 0, 0) // discard time
        d2.setHours(0, 0, 0)
        return Math.round((d1 - d2) / d.msInADay) // Math.round: not all days are 24 hours long!
    }

    /**
        *  Returns the timestamp of the last minute
        *  - `before``: number of minutes before the reference minute
        *  - `time``: timestamp to use as reference
        *  - `rounding``: if true, rounds to the last minute
    **/
    function minutes(before = 0, time = Date.now(), rounding = true) {
        let timestamp = rounding ? Math.floor(time / minutesToMs(5)) * minutesToMs(5)
                                    : time
        return timestamp - minutesToMs(before)
    }

    /**
        *  Returns the timestamp of the last hour
        *  - `before``: number of hours before the reference hour
        *  - `time``: timestamp to use as reference
        *  - `rounding``: if true, rounds to the last hour
    **/
    function hours(before = 0, time = Date.now(), rounding = true) {
        let timestamp = rounding ? Math.floor(time / minutesToMs(30)) * minutesToMs(30)
                                    : time
        return timestamp - hoursToMs(before)
    }

    /**
        *  Returns the timestamp of the last day
        *  - `before``: number of days before the reference day
        *  - `time``: timestamp to use as reference
        *  - `rounding``: if true, rounds to the last day
    **/
    function days(before = 0, time = Date.now(), rounding = true) {
        let date = new Date(time)
        if(rounding) {
            date = new Date(date.getFullYear(), date.getMonth(), date.getDate())
        }

        date.setDate(date.getDate() - before)
        return date.getTime()
    }

    /**
        *  Returns the timestamp of the last week
        *  - `before``: number of weeks before the reference week
        *  - `time``: timestamp to use as reference
        *  - `rounding``: if true, rounds to the last week
    **/
    function months(before = 0, time = Date.now(), rounding = true) {
        let date = new Date(time)
        if(rounding) {
            date = new Date(date.getFullYear(), date.getMonth(), 1)
        }
        date.setMonth(date.getMonth() - before)

        return date.getTime()
    }

    /**
        *  Returns the timestamp of the last year
        *  - `before``: number of years before the reference year
        *  - `time``: timestamp to use as reference
        *  - `rounding``: if true, rounds to the last year
    **/
    function years(before = 0, time = Date.now(), rounding = true) {
        let date = new Date(time)
        if(rounding) {
            date = new Date(date.getFullYear(), 0, 1)
        }
        date.setFullYear(date.getFullYear() - before)
        return date.getTime()
    }

    /**
        *  Retuns the number of milliseconds in the given amount of minutes
        *  - `count``: number of minutes
    **/
    function minutesToMs(count = 1) {
        return count * 60 * 1000
    }

    /**
        *  Retuns the number of milliseconds in the given amount of hours
        *  - `count``: number of hours
    **/
    function hoursToMs(count = 1) {
        return count * minutesToMs(60)
    }

    /**
        *  Retuns the number of milliseconds in the given amount of days
        *  - `count``: number of days
    **/
    function daysToMs(count = 1) {
        return count * hoursToMs(24)
    }

    /**
      Converts the Date to a string containing the date suitable for the specified locale in the specified format.

      - 'value' can be either a Date object, or a string containing a number or ISO string timestamp, or empty for "now"
      - 'format' can be one of Locale.LongFormat (default), Locale.ShortFormat
    */
    function formatDate(value, format = Locale.LongFormat) {
        value = d.readDate(value)
        const loc = Qt.locale()
        if (format === Locale.ShortFormat) { // replace 2-digit year with 4-digits (yy -> yyyy) in short format
            const dateFormatStr = loc.dateFormat(Locale.ShortFormat)
            if (!dateFormatStr.includes("yyyy")) {
                format = dateFormatStr.replace("yy", "yyyy")
            }
        }
        return value.toLocaleDateString(loc, format)
    }

    /**
      Converts the Date to a string containing the time suitable for the specified locale in the specified format.

      - 'value' can be either a Date object, or a string containing a number or ISO string timestamp, or empty for "now"
      - 'format' can be one of Locale.LongFormat (default), Locale.ShortFormat
    */
    function formatTime(value, format = Locale.LongFormat) {
        value = d.readDate(value)
        const loc = Qt.locale()
        const formatString = d.fixupTimeFormatString(loc.timeFormat(format))
        return value.toLocaleTimeString(loc, formatString)
    }

    /**
      Converts the Date to a string containing both the date and time suitable for the specified locale in the specified format.

      - 'value' can be either a Date object, or a string containing a number or ISO string timestamp, or empty for "now"
      - 'format' can be one of Locale.LongFormat (default), Locale.ShortFormat
    */
    function formatDateTime(value, format = Locale.LongFormat) {
        value = d.readDate(value)
        const loc = Qt.locale()
        var formatString = d.fixupTimeFormatString(loc.dateTimeFormat(format))
        if (format === Locale.ShortFormat && !formatString.includes("yyyy"))  // replace 2-digit year with 4-digits (yy -> yyyy) in short format
            formatString = formatString.replace("yy", "yyyy")

        return value.toLocaleString(loc, formatString)
    }

    /**
      Returns the Date of the first day of the current week.
    */
    function getFirstDayOfTheCurrentWeek() {
        const loc = Qt.locale()
        let firstDayOfWeek = new Date()
        // NOTE returned value is always Sunday, so day must be adjusted by locale first day of week
        let result = new Date(firstDayOfWeek.setDate(firstDayOfWeek.getDate() - firstDayOfWeek.getDay() + loc.firstDayOfWeek))
        if (result > new Date()) {
            result.setDate(firstDayOfWeek.getDate() - 7)
        }
        return result
    }

    // TODO use JS Intl.RelativeTimeFormat in Qt 6?
    function formatRelativeTimestamp(timestamp, weekFromBeginning=false) {
        const now = new Date()
        const value = d.readDate(timestamp)
        const loc = Qt.locale()
        const formatString = d.fixupTimeFormatString(loc.timeFormat(Locale.ShortFormat)) // format string for the time part
        const dayDifference = daysBetween(value, now)

        // within last day, 2 or 7 days
        if (dayDifference < 1) // today -> "Today 14:23"
            return qsTr("Today %1").arg(value.toLocaleTimeString(loc, formatString))

        if (dayDifference < 2) // yesterday -> "Yesterday 14:23"
            return qsTr("Yesterday %1").arg(value.toLocaleTimeString(loc, formatString))

        let isLastWeek = false
        if (weekFromBeginning) { // Use only for date from beggining of the week
            const daysToBeginingOfThisWeek = daysTo(value, getFirstDayOfTheCurrentWeek())
            isLastWeek = daysToBeginingOfThisWeek >= 0
        } else {
            isLastWeek = dayDifference < 7
        }

        if (isLastWeek) { // last 7 days -> "Mon 14:23"
            return qsTr("%1 %2").arg(loc.standaloneDayName(value.getDay(), Locale.ShortFormat)).arg(value.toLocaleTimeString(loc, formatString))
        }

        // within this year
        if (now.getFullYear() === value.getFullYear()) {
            // strip year part, if current year -> "31 Dec 09:41"
            return getDayMonth(value) + " " + formatTime(value, Locale.ShortFormat)
        }

        // otherwise
        return formatDateTime(value, Locale.ShortFormat)
    }

    function getTimeDifference(d1, d2) {
        const day1Year = d1.getFullYear()
        const day1Month = d1.getMonth()
        const day1Time = d1.getTime()

        const day2Year = d2.getFullYear()
        const day2Month = d2.getMonth()
        const day2Time = d2.getTime()

        const inYears = day2Year-day1Year
        if (inYears > 0) {
            return qsTr("%n year(s) ago", "", inYears)
        }

        const inMonths = (day2Month+12*day2Year)-(day1Month+12*day1Year)
        if (inMonths > 0) {
            return qsTr("%n month(s) ago", "", inMonths)
        }

        const inWeeks = parseInt((day2Time-day2Time)/(24*3600*1000*7))
        if (inWeeks > 0) {
            return qsTr("%n week(s) ago", "", inWeeks)
        }

        const inDays = parseInt((day2Time-day1Time)/(24*3600*1000))
        if (inDays > 0) {
            return qsTr("%n day(s) ago", "", inDays)
        }

        const inHours = parseInt((day2Time-day1Time)/(3600*1000));
        if (inHours > 0) {
            return qsTr("%n hour(s) ago", "", inHours)
        }

        const inMins = parseInt((day2Time-day1Time)/(60*1000))
        if (inMins > 0) {
            return qsTr("%n min(s) ago", "x minute(s) ago", inMins)
        }

        const inSecs = parseInt((day2Time-day1Time)/1000);
        if (inSecs > 0) {
            return qsTr("%n sec(s) ago", "x second(s) ago", inSecs)
        }

        return qsTr("now")
    }

    // FIXME Qt6 use IntlFormat (partial string)
    function getDayMonth(value) {
        const currentFormat = is24hTimeFormatDefault() ? "d MMM" : "MMM d"
        return formatDate(value, currentFormat)
    }

    // FIXME Qt6 use IntlFormat (partial string)
    function getMonthYear(value) {
        return formatDate(value, "MMM yyyy")
    }

    function getDayName(value) {
        return Qt.locale().standaloneDayName(value.getDay())
    }
}
