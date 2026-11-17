#include "StatusQ/audioutils.h"

#include <QAudio>
#include <QDebug>

#ifdef Q_OS_ANDROID
#include <QCoreApplication>
#include <QJniEnvironment>
#include <QJniObject>
#include <QtCore/qnativeinterface.h>
#include <atomic>
#include <iterator>

namespace {
std::atomic<AudioUtils *> s_audioUtils = nullptr;

void nativeSilentModeChanged(JNIEnv *, jclass, jboolean silent)
{
    QMetaObject::invokeMethod(qApp, [silent] {
        if (auto self = s_audioUtils.load())
            self->updateSilentMode(silent);
    }, Qt::QueuedConnection);
}
}
#endif

#ifdef Q_OS_IOS
#import <AVFoundation/AVAudioSession.h>
#endif

AudioUtils::AudioUtils(QObject *parent)
    : QObject(parent)
{
#ifdef Q_OS_ANDROID
    s_audioUtils = this;
    static const bool silentModeRegistered = [] {
        QJniEnvironment env;
        const JNINativeMethod methods[] = {
            { const_cast<char*>("nativeOnSilentModeChanged"),
              const_cast<char*>("(Z)V"),
              reinterpret_cast<void*>(nativeSilentModeChanged) },
        };
        return env.registerNativeMethods("app/status/mobile/SilentModeListener",
                                         methods, int(std::size(methods)));
    }();
    if (silentModeRegistered) {
        const auto context = QNativeInterface::QAndroidApplication::context();
        const QJniObject listener("app/status/mobile/SilentModeListener",
                                  "(Landroid/content/Context;)V", context.object<jobject>());
        if (listener.isValid()) {
            const auto mode = listener.callMethod<jint>("start", "()I");
            if (mode >= 0)
                updateSilentMode(mode != 2); // AudioManager.RINGER_MODE_NORMAL
            else
                qWarning() << "[Android Silent Mode] Could not start ringer tracking";
            connect(this, &QObject::destroyed, [listener] {
                listener.callMethod<void>("stop", "()V");
            });
        } else {
            qWarning() << "[Android Silent Mode] Could not create ringer listener";
        }
    } else {
        qWarning() << "[Android Silent Mode] RegisterNatives failed";
    }
#endif

#ifdef Q_OS_IOS
    // Ambient honors Ring/Silent and mixes with other audio; Qt activates the session on playback.
    NSError *error = nil;
    if (![[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&error])
        qWarning() << "AudioUtils: Cannot configure iOS Ambient audio:"
                   << QString::fromNSString(error.localizedDescription);
#endif
}

AudioUtils::~AudioUtils()
{
#ifdef Q_OS_ANDROID
    auto self = this;
    s_audioUtils.compare_exchange_strong(self, nullptr);
#endif
}

qreal AudioUtils::convertLogarithmicToLinearVolumeScale(qreal volume) const
{
    return QAudio::convertVolume(volume, QAudio::LogarithmicVolumeScale, QAudio::LinearVolumeScale);
}

bool AudioUtils::isSilent() const
{
    return m_isSilent;
}

void AudioUtils::updateSilentMode(bool silent)
{
    if (m_isSilent == silent)
        return;
    m_isSilent = silent;
    emit isSilentChanged();
}
