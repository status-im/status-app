#include <StatusQ/openedfileintake.h>

#include <QCoreApplication>
#include <QJniObject>

// Android hands files over through StatusQtActivity (passFileToQt), not a receiver.
void Status::OpenedFileIntake::setReceiver(std::function<void(const QString &, bool)>)
{
}

void Status::OpenedFileIntake::release(const QString &openedFile)
{
    forget(openedFile);
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid())
        return;
    QJniObject::callStaticMethod<void>("app/status/mobile/OpenedFileIntake", "release",
                                       "(Landroid/content/Context;Ljava/lang/String;)V",
                                       context.object<jobject>(),
                                       QJniObject::fromString(openedFile).object<jstring>());
}
