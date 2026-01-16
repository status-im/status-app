#pragma once


using IOSShakeCallback = void (*)();

#ifdef Q_OS_IOS

void saveImageToPhotosAlbum(const QByteArray& imageData);
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

#endif // Q_OS_IOS
