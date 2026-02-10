#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <QStringList>
#include <QQuickItem>
#include <QMouseEvent>

class SystemUtilsInternal : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int androidKeyboardHeight READ androidKeyboardHeight NOTIFY androidKeyboardHeightChanged)
    Q_PROPERTY(bool androidKeyboardVisible READ androidKeyboardVisible NOTIFY androidKeyboardVisibleChanged)
    Q_PROPERTY(int iosKeyboardHeight READ iosKeyboardHeight NOTIFY iosKeyboardHeightChanged)
    Q_PROPERTY(bool iosKeyboardVisible READ iosKeyboardVisible NOTIFY iosKeyboardVisibleChanged)

public:
    explicit SystemUtilsInternal(QObject *parent = nullptr);

    Q_INVOKABLE QString qtRuntimeVersion() const;
    Q_INVOKABLE void restartApplication() const;
    Q_INVOKABLE void downloadImageByUrl(const QUrl& url, const QString& path) const;
    Q_INVOKABLE void synthetizeRightClick(QQuickItem* item, qreal x, qreal y, Qt::KeyboardModifiers modifiers) const;
    Q_INVOKABLE void androidMinimizeToBackground();
    Q_INVOKABLE Qt::KeyboardModifiers queryKeyboardModifiers();
    Q_INVOKABLE Qt::MouseButtons mouseButtons();

    // Set Android status bar icon color (true = light/white icons, false = dark/black icons)
    Q_INVOKABLE void setAndroidStatusBarIconColor(bool lightIcons);
    // Notify Android splash screen to hide (for custom activity)
    Q_INVOKABLE void setAndroidSplashScreenReady();
    
    // Get Android keyboard state (uses WindowInsets API, works Android 11-16+)
    Q_INVOKABLE int androidKeyboardHeight() const;
    Q_INVOKABLE bool androidKeyboardVisible() const;
    Q_INVOKABLE void requestAndroidKeyboardShow();
    
    // Get iOS keyboard state
    Q_INVOKABLE int iosKeyboardHeight() const;
    Q_INVOKABLE bool iosKeyboardVisible() const;
    Q_INVOKABLE void setupIOSKeyboardTracking();

    // iOS native share sheet
    Q_INVOKABLE void iosShareFile(const QUrl& fileUrl) const;
    Q_INVOKABLE void iosShareFiles(const QVariantList& fileUrls) const;
    Q_INVOKABLE void iosSharePaths(const QStringList& filePaths) const;

    // Android native share sheet
    Q_INVOKABLE void androidSharePaths(const QStringList& filePaths) const;

    // Cross-platform share sheet
    Q_INVOKABLE void sharePaths(const QStringList& filePaths) const;

    // Debug helper (used from QML to verify signal handlers fire on device)
    Q_INVOKABLE void debugLog(const QString& message) const;

signals:
    // Emitted when event of type QEvent::Quit is detected by event filter on
    // QGuiApplication. It's helpful to handle close requests on mac coming from
    // various sources (shortcut, menu bar close icon, tray icon menu).
    void quit(bool spontaneous);
    void androidKeyboardHeightChanged();
    void androidKeyboardVisibleChanged();
    void iosKeyboardHeightChanged();
    void iosKeyboardVisibleChanged();
    void shakeDetected();

private:
    int m_androidKeyboardHeight = 0;
    bool m_androidKeyboardVisible = false;
    int m_iosKeyboardHeight = 0;
    bool m_iosKeyboardVisible = false;
    QTimer* m_iosKeyboardPollTimer = nullptr;
};
