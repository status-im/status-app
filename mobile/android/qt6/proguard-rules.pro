# R8 keep rules. Every rule names the reflective or JNI use that needs it.
# Default AGP rules (proguard-android-optimize.txt) already keep: native method
# names, Parcelable CREATOR, enum values(), @JavascriptInterface methods,
# manifest components (via aapt rules).

-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Qt: libQt6Core, the qtforandroid platform plugin, Qt6Quick/Network/Nfc/
# Multimedia plugins and the openssl TLS backend resolve 57 classes by name
# (FindClass) and their members by name (GetMethodID/GetFieldID), e.g.
# QtNative, QtLoader, QtActivityBase, QtWindow, QtInputDelegate,
# QtAndroidBinder, QtNfc, QtAudioDeviceManager, QtCamera2. The package is
# 170KB of dex, so it is kept whole instead of per member.
-keep class org.qtproject.qt.android.** { *; }

# ui/StatusQ/src/systemutilsinternal.cpp: callStaticMethod on
# StatusQtActivity (mainWindowReady, openDownloadsUi,
# openAccessibilitySettings, restartApplication), KeyboardUtil
# (requestKeyboardShow, start), StatusBarUtil (setStatusBarIconColor),
# ShareUtils (sharePaths), MediaStoreHelper (insertImageFromPath);
# RegisterNatives on DensityListener, ShakeDetector and KeyboardUtil
# (nativeOnKeyboardHeightChanged).
-keep class app.status.mobile.StatusQtActivity { *; }
-keep class app.status.mobile.KeyboardUtil { *; }
-keep class app.status.mobile.StatusBarUtil { *; }
-keep class app.status.mobile.ShareUtils { *; }
-keep class app.status.mobile.MediaStoreHelper { *; }
-keep class app.status.mobile.DensityListener { *; }
-keep class app.status.mobile.ShakeDetector { *; }

# ui/StatusQ/src/safutils_android.cpp: callStaticMethod on SafHelper
# (takePersistablePermission, getReadableTreePath, copyFromPathToTree).
-keep class app.status.mobile.SafHelper { *; }

# ui/StatusQ/src/keychain_android.cpp: SecureAndroidAuthentication.getInstance
# by name, instance methods by name, RegisterNatives for the nativeCredential*
# callbacks.
-keep class app.status.mobile.SecureAndroidAuthentication { *; }
-keep class app.status.mobile.SecureStorageHelper { *; }

# ui/StatusQ/src/StatusQ/Controls/NativeSwipeHandlerItem_android.cpp and
# NativeIndicatorItem_android.cpp: constructed by name with a (J, Activity)
# signature, methods called by name, RegisterNatives on the helper.
-keep class app.status.mobile.NativeSwipeHandlerHelper { *; }
-keep class app.status.mobile.NativeIndicatorHelper { *; }

# ui/StatusQ/src/lifecycleutils_android.cpp + systemutilsinternal.cpp:
# StatusGoStub.setUiVisible / stopService by name;
# mobile/statusgo_stub/statusgo_stub.cpp: GetStaticMethodID "call".
-keep class app.status.mobile.StatusGoStub { *; }

# mobile/statusgo_service/statusgo_service_jni.cpp: GetMethodID
# "onNativeSignal" on the service instance passed to nativeInit.
-keepclassmembers class app.status.mobile.ipc.StatusGoService {
    void onNativeSignal(java.nio.ByteBuffer);
}

# mobile/statusgo_stub/statusgo_stub.cpp: FindClass + GetMethodID on the
# status-go call result.
-keep class app.status.mobile.ipc.IpcPayload {
    java.lang.Object nativeView();
    int length();
    void close();
}

# MobileWebView (StatusQ FetchContent): libMobileWebView.so constructs
# MobileWebView by name and calls its methods by name; DataClearManager
# static methods are called by name.
-keep class org.mobilewebview.MobileWebView { *; }
-keep class org.mobilewebview.DataClearManager { *; }

# MobileWebView reaches androidx.webkit through Class.forName + getMethod
# (WebViewProfileManager, MobileWebView, DataClearManager, BridgeScriptInjector:
# WebViewCompat, WebViewFeature, ProfileStore, WebStorageCompat, and remove()
# on the ScriptHandler implementation). The package is 67KB of dex, so it is
# kept whole instead of per member.
-keep class androidx.webkit.** { *; }

# Qt qtforandroid plugin, qandroidplatformiconengine.cpp: FontRequest,
# FontsContractCompat.fetchFonts, FontFamilyResult and FontInfo by name.
-keep class androidx.core.provider.FontRequest { *; }
-keep class androidx.core.provider.FontsContractCompat { *; }
-keep class androidx.core.provider.FontsContractCompat$FontFamilyResult { *; }
-keep class androidx.core.provider.FontsContractCompat$FontInfo { *; }

# Qt qtforandroid plugin, qandroidplatformservices.cpp: QDesktopServices::openUrl
# turns a file:// URL into a content:// one with FileProvider.getUriForFile by
# name. Without it Qt.openUrlExternally fails for every local file.
-keepclassmembers class androidx.core.content.FileProvider {
    public static android.net.Uri getUriForFile(android.content.Context, java.lang.String, java.io.File);
}

# MobileUI (im.status:mobileui-android): pushnotification_android.cpp calls
# PushNotificationHelper static methods by name (initialize,
# hasNotificationPermission, isNotificationPermissionRequestable,
# areNotificationsEnabled, requestNotificationPermission,
# openNotificationSettings, showNotification, clearNotifications). The
# PermissionFragment is re-instantiated by the FragmentManager on restore.
-keep class im.status.mobileui.PushNotificationHelper { *; }
-keep class im.status.mobileui.PushNotificationHelper$PermissionFragment { *; }
