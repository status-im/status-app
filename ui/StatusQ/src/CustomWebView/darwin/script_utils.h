#pragma once

#include <QString>
#include <QStringList>
#include <QVariant>
#include <QList>

struct UserScriptInfo;

// Parse user scripts from QVariantList to QList<UserScriptInfo>
// Supports QString (path only) or QVariantMap with "path" and "runOnSubFrames" keys
QList<UserScriptInfo> parseUserScripts(const QVariantList &scripts);

// Escape JSON string for embedding in JavaScript single-quoted string (escapes: backslash, single quote, newline, carriage return)
QString escapeJsonForJs(const QString &json);
