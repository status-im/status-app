#pragma once


#ifdef Q_OS_IOS

void saveImageToPhotosAlbum(const QByteArray& imageData);
QString resolveIOSPhotoAsset(const QUrl &assetUrl);

// Keyboard utilities
void setupIOSKeyboardTracking();
int getIOSKeyboardHeight();
bool isIOSKeyboardVisible();

// Shake detection utilities
void setupIOSShakeDetection();
int getIOSShakeCount();

// Share sheet utilities
void presentIOSShareSheetForFilePath(const QString& filePath);
void presentIOSShareSheetForFilePaths(const QStringList& filePaths);

#endif // Q_OS_IOS
