#include "StatusQ/shareutils.h"

#include <QGuiApplication>
#include <QClipboard>

void ShareUtils::shareText(const QString &text) {
    QGuiApplication::clipboard()->clear();
    QGuiApplication::clipboard()->setText(text);
}
