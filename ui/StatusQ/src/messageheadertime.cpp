#include "messageheadertime.h"
#include "StatusQ/messageheaderappearance.h"

#include <QRegularExpression>

namespace {

// LocaleUtils.fixupTimeFormatString.
QString fixupTimeFormat(QString format, const MessageHeaderAppearance* appearance)
{
    if (appearance->timeFormatUsesDefaults())
        return format;
    if (appearance->timeFormatUses24Hours()) {
        static const QRegularExpression amPm(QStringLiteral("\\ba\\b|\\bap\\b"),
                                             QRegularExpression::CaseInsensitiveOption);
        format.remove(amPm);
        format.replace(QLatin1Char('h'), QLatin1Char('H'));
        return format;
    }
    format.replace(QLatin1Char('H'), QLatin1Char('h'));
    // Any of "AP", "A", "ap", "a".
    if (!format.contains(QLatin1Char('a')) && !format.contains(QLatin1Char('A')))
        format.append(QStringLiteral(" ap"));
    return format;
}

bool hasAmPm(const QString& format)
{
    return format.contains(QLatin1Char('a')) || format.contains(QLatin1Char('A'));
}

} // namespace

void MessageHeaderTimeFormats::build(const MessageHeaderAppearance* a, quint64 clock, QDate day)
{
    appearance = a;
    timeFormatRevision = a->timeFormatRevision();
    clockRevision = clock;
    today = day;

    // Format strings honour the user's system settings, so they come from the
    // system locale. Formatting with them uses a locale built from data for
    // the same language: names and AM/PM without a system query per call.
    const QLocale current;
    locale = current == QLocale::system() ? QLocale(current.bcp47Name()) : current;

    shortTime = fixupTimeFormat(current.timeFormat(QLocale::ShortFormat), a);
    longDateTime = fixupTimeFormat(current.dateTimeFormat(QLocale::LongFormat), a);
    shortDateTime = fixupTimeFormat(current.dateTimeFormat(QLocale::ShortFormat), a);
    if (!shortDateTime.contains(QStringLiteral("yyyy"))) {
        const auto index = shortDateTime.indexOf(QStringLiteral("yy"));
        if (index >= 0)
            shortDateTime.replace(index, 2, QStringLiteral("yyyy"));
    }
    // LocaleUtils.getDayMonth: by the OS default, not the preference.
    dayMonth = hasAmPm(current.timeFormat(QLocale::LongFormat)) ? QStringLiteral("MMM d")
                                                                : QStringLiteral("d MMM");
    todayTemplate = a->todayTemplate();
    yesterdayTemplate = a->yesterdayTemplate();
    weekdayTemplate = a->weekdayTemplate();
    for (int day = 1; day <= 7; ++day)
        dayNames[day] = current.standaloneDayName(day, QLocale::ShortFormat);
}

QString MessageHeaderTimeFormats::relative(qint64 timestamp) const
{
    const QDateTime value = QDateTime::fromMSecsSinceEpoch(timestamp);
    const QDate date = value.date();
    const auto days = qAbs(date.daysTo(today));
    if (days < 1)
        return todayTemplate.arg(locale.toString(value.time(), shortTime));
    if (days < 2)
        return yesterdayTemplate.arg(locale.toString(value.time(), shortTime));
    if (days < 7)
        return weekdayTemplate.arg(dayNames[date.dayOfWeek()], locale.toString(value.time(), shortTime));
    if (today.year() == date.year())
        return locale.toString(date, dayMonth) + QLatin1Char(' ') + locale.toString(value.time(), shortTime);
    return locale.toString(value, shortDateTime);
}

QString MessageHeaderTimeFormats::full(qint64 timestamp) const
{
    return locale.toString(QDateTime::fromMSecsSinceEpoch(timestamp), longDateTime);
}
