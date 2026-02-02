#include "StatusQ/shareutils.h"

#include <QCoreApplication>
#include <QJniObject>

void ShareUtils::shareText(const QString &text) {
    QJniObject jText = QJniObject::fromString(text);
    QJniObject intent("android/content/Intent");

    intent.callObjectMethod("setAction", "(Ljava/lang/String;)Landroid/content/Intent;",
                            QJniObject::getStaticObjectField("android/content/Intent", "ACTION_SEND", "Ljava/lang/String;").object());
    intent.callObjectMethod("setType", "(Ljava/lang/String;)Landroid/content/Intent;",
                            QJniObject::fromString("text/plain").object());
    intent.callObjectMethod("putExtra", "(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;",
                            QJniObject::getStaticObjectField("android/content/Intent", "EXTRA_TEXT", "Ljava/lang/String;").object(),
                            jText.object());

    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    QJniObject chooser = QJniObject::callStaticObjectMethod("android/content/Intent", "createChooser", 
                                                           "(Landroid/content/Intent;Ljava/lang/CharSequence;)Landroid/content/Intent;",
                                                           intent.object(), QJniObject::fromString(QCoreApplication::translate("ShareUtils", "Share via")).object());
    activity.callMethod<void>("startActivity", "(Landroid/content/Intent;)V", chooser.object());
}
