#pragma once

#include <QDate>
#include <QDateTime>
#include <QLocale>
#include <QString>

class MessageHeaderAppearance;

// Everything the header's timestamp formatting reads from the locale and the
// preferences, resolved once per environment instead of once per header: on
// macOS each QLocale format or name lookup of the system locale is a system
// query.
struct MessageHeaderTimeFormats
{
    // Identifies the inputs these were built from.
    const MessageHeaderAppearance* appearance = nullptr;
    quint64 timeFormatRevision = 0;
    quint64 clockRevision = 0;

    QDate today;
    // Formats with names and AM/PM resolved from data, not system queries.
    QLocale locale;
    QString shortTime;      // fixed up for the 12/24h preference
    QString shortDateTime;  // fixed up, 4-digit year
    QString longDateTime;   // fixed up
    QString dayMonth;       // "d MMM" or "MMM d"
    QString todayTemplate;
    QString yesterdayTemplate;
    QString weekdayTemplate;
    QString dayNames[8];    // standalone short names, 1 = Monday

    void build(const MessageHeaderAppearance* appearance, quint64 clockRevision, QDate today);

    // LocaleUtils.formatRelativeTimestamp(timestamp)
    QString relative(qint64 timestamp) const;
    // LocaleUtils.formatDateTime(timestamp)
    QString full(qint64 timestamp) const;
};
