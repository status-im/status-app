#pragma once

#include <QString>
#include <QStringList>
#include <QByteArray>
#include <QUrl>
#include <functional>


using IOSShakeCallback = void (*)();
using IOSFilePickerAcceptedCallback = void (*)(const QStringList&);
using IOSFilePickerRejectedCallback = void (*)();

#ifdef Q_OS_IOS

void saveImageToPhotosAlbumAsync(const QByteArray& imageData, const std::function<void(bool)>& completion);
QString resolveIOSPhotoAsset(const QUrl &assetUrl);

// Keyboard utilities
void setupIOSKeyboardTracking();
int getIOSKeyboardHeight();
bool isIOSKeyboardVisible();

// Shake detection utilities
void setupIOSShakeDetection();
void setIOSShakeCallback(IOSShakeCallback callback);
void setIOSShakeToEditEnabled(bool enabled);

// Share sheet utilities
void presentIOSShareSheetForFilePath(const QString& filePath);
void presentIOSShareSheetForFilePaths(const QStringList& filePaths);

// Document picker utilities
void presentIOSDocumentPicker(bool selectMultiple, const QStringList& nameFilters);
void presentIOSPhotoLibraryPicker(bool selectMultiple);
void setIOSFilePickerCallbacks(IOSFilePickerAcceptedCallback acceptedCallback,
                               IOSFilePickerRejectedCallback rejectedCallback);

#endif // Q_OS_IOS
