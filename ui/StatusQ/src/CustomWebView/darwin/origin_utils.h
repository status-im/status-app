#pragma once

#import <WebKit/WebKit.h>
#import <Foundation/Foundation.h>

#include <QString>
#include <QStringList>
#include <QUrl>

#pragma mark - Origin Utility Functions

// Extracts the origin string from a QUrl (format: "protocol://host" or "protocol://host:port")
QString extractOrigin(const QUrl &url);

// Extracts the origin string from a WKFrameInfo object (format: "protocol://host" or "protocol://host:port")
NSString *extractOriginFromFrameInfo(WKFrameInfo *frameInfo);

// Checks if an origin is in the allowed origins list (supports exact matches and wildcard patterns like "*.example.com", "*")
bool isOriginAllowed(const QString &origin, const QStringList &allowedOrigins);
