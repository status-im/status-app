#import "origin_utils.h"

#import <WebKit/WebKit.h>
#import <Foundation/Foundation.h>

#include <QString>
#include <QStringList>
#include <QUrl>
#include <QRegularExpression>

#pragma mark - Origin Utility Functions

QString extractOrigin(const QUrl &url)
{
    if (!url.isValid() || url.scheme().isEmpty() || url.host().isEmpty()) {
        return QString();
    }
    
    QString origin = url.scheme() + QStringLiteral("://") + url.host();
    int port = url.port();
    if (port != -1 && port != 80 && port != 443) {
        origin += QLatin1Char(':') + QString::number(port);
    }
    return origin;
}

NSString *extractOriginFromFrameInfo(WKFrameInfo *frameInfo)
{
    if (!frameInfo || !frameInfo.securityOrigin) {
        return @"";
    }
    
    WKSecurityOrigin *securityOrigin = frameInfo.securityOrigin;
    
    QUrl url;
    url.setScheme(QString::fromNSString(securityOrigin.protocol));
    url.setHost(QString::fromNSString(securityOrigin.host));
    if (securityOrigin.port > 0) {
        url.setPort(securityOrigin.port);
    }
    
    return extractOrigin(url).toNSString();
}

bool isOriginAllowed(const QString &origin, const QStringList &allowedOrigins)
{
    // If no allowlist is set, reject all
    if (allowedOrigins.isEmpty()) {
        return false;
    }
    
    // Empty origin is never allowed
    if (origin.isEmpty()) {
        return false;
    }
    
    // Check for exact match first (including "*" wildcard)
    if (allowedOrigins.contains(origin) || allowedOrigins.contains(QLatin1String("*"))) {
        return true;
    }
    
    // Check for wildcard patterns (e.g., "*.example.com" or "*://example.com")
    for (const QString &pattern : allowedOrigins) {
        if (pattern.contains(QLatin1Char('*'))) {
            // Convert wildcard pattern to regex
            QString regexPattern = QRegularExpression::escape(pattern);
            regexPattern.replace(QStringLiteral("\\*"), QStringLiteral(".*"));
            regexPattern = QLatin1String("^") + regexPattern + QLatin1String("$");
            
            QRegularExpression regex(regexPattern, QRegularExpression::CaseInsensitiveOption);
            if (regex.match(origin).hasMatch()) {
                return true;
            }
        }
    }
    
    return false;
}
