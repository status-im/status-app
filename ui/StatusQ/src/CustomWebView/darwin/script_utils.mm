#include "script_utils.h"
#include "userscripts.h"

#include <QUrl>
#include <QVariantMap>

QList<UserScriptInfo> parseUserScripts(const QVariantList &scripts)
{
    QList<UserScriptInfo> result;
    
    for (const QVariant &scriptEntry : scripts) {
        if (scriptEntry.canConvert<QVariantMap>()) {
            QVariantMap map = scriptEntry.toMap();
            QVariant pathVariant = map.value(QStringLiteral("path"));
            QString path;
            
            if (pathVariant.canConvert<QUrl>()) {
                QUrl url = pathVariant.toUrl();
                if (url.scheme() == QLatin1String("qrc")) {
                    path = QLatin1String(":") + url.path();
                } else {
                    path = url.toString();
                }
            } else {
                path = pathVariant.toString();
            }
            
            bool runOnSubFrames = map.value(QStringLiteral("runOnSubFrames"), false).toBool();
            if (!path.isEmpty()) {
                result.append(UserScriptInfo(path, runOnSubFrames));
            }
        } else if (scriptEntry.canConvert<QString>()) {
            QString path = scriptEntry.toString();
            if (!path.isEmpty()) {
                result.append(UserScriptInfo(path, false));
            }
        }
    }
    
    return result;
}

QString escapeJsonForJs(const QString &json)
{
    QString escaped = json;
    escaped.replace(QStringLiteral("\\"), QStringLiteral("\\\\"));
    escaped.replace(QStringLiteral("'"), QStringLiteral("\\'"));
    escaped.replace(QStringLiteral("\n"), QStringLiteral("\\n"));
    escaped.replace(QStringLiteral("\r"), QStringLiteral("\\r"));
    return escaped;
}
