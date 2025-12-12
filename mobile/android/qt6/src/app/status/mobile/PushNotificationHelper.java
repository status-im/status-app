package app.status.mobile;

import android.Manifest;
import android.app.Activity;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;
import androidx.core.app.ActivityCompat;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;

/**
 * Helper class for managing push notifications
 * 
 * This class provides:
 * - JNI bridge between Java and C++/Qt
 * - Notification display functionality
 * - Notification channel management
 * - Deep link handling
 */
public class PushNotificationHelper {
    private static final String TAG = "PushNotificationHelper";
    private static final String CHANNEL_ID = "status-messages";
    private static final String CHANNEL_NAME = "Status Messages";
    
    // Store application context (set by PushNotificationService)
    private static Context sApplicationContext = null;
    
    /**
     * Initialize with application context
     * Should be called from PushNotificationService.onCreate()
     */
    public static void initialize(Context context) {
        if (context != null) {
            sApplicationContext = context.getApplicationContext();
            Log.d(TAG, "PushNotificationHelper initialized with context");
        }
    }
    
    /**
     * Check if notification permission is granted (Android 13+)
     * Returns true if permission is granted or not required (Android 12-)
     */
    public static boolean hasNotificationPermission(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) { // Android 13+
            int result = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            );
            boolean hasPermission = result == PackageManager.PERMISSION_GRANTED;
            return hasPermission;
        }
        return true;
    }
    
    /**
     * Request notification permission (Android 13+ only)
     * For Android 12 and below, this does nothing as permission is not required
     */
    public static void requestNotificationPermission(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) { // Android 13+
            if (context instanceof Activity) {
                Activity activity = (Activity) context;
                if (!hasNotificationPermission(context)) {
                    Log.d(TAG, "Requesting POST_NOTIFICATIONS permission...");
                    ActivityCompat.requestPermissions(
                        activity,
                        new String[]{Manifest.permission.POST_NOTIFICATIONS},
                        1001 // Request code
                    );
                } else {
                    Log.d(TAG, "Notification permission already granted");
                }
            } else {
                Log.w(TAG, "Cannot request permission: context is not an Activity");
            }
        } else {
            Log.d(TAG, "Android 12- : notification permission not required");
        }
    }
    
    /**
     * Request FCM token at app startup
     * This method can be called from C++ layer to explicitly request the token
     * The token is delivered via onFCMTokenReceived callback
     */
    public static void requestFCMToken(Context context) {
        Log.d(TAG, "Requesting FCM token from Firebase...");
        
        // Store context if not already set
        if (sApplicationContext == null && context != null) {
            sApplicationContext = context.getApplicationContext();
        }
        
        // Check notification permission first
        if (!hasNotificationPermission(context)) {
            Log.w(TAG, "Notification permission not granted. Token request may fail.");
        }
        
        // Request token with completion listener
        // This works whether the token is cached or needs to be fetched
        com.google.firebase.messaging.FirebaseMessaging.getInstance().getToken()
            .addOnCompleteListener(task -> {
                if (task.isSuccessful() && task.getResult() != null) {
                    String token = task.getResult();
                    Log.d(TAG, "FCM token obtained: " + token);
                    // Pass token to native layer
                    onFCMTokenReceived(token);
                } else {
                    Log.e(TAG, "Failed to get FCM token", task.getException());
                }
            });
    }
    
    /**
     * Called from FirebaseMessagingService when new token is received
     * This method calls into C++/Qt layer via JNI
     */
    public static void onFCMTokenReceived(String token) {
        Log.d(TAG, "FCM Token ready to pass to native layer: " + token);

        // Call native C++ method (implemented in C++ via JNI registration).
        // If Qt/native isn't loaded/registered yet, do NOT crash the process.
        try {
            nativeOnFCMTokenReceived(token);
        } catch (UnsatisfiedLinkError e) {
            Log.w(TAG, "Native layer not available for FCM token yet; dropping token (best-effort mode)", e);
        }
    }
    
    /**
     * Called from FirebaseMessagingService when push notification received
     * Passes encrypted data to status-go for processing
     */
    public static void onPushNotificationReceived(String encryptedMessage, 
                                                  String chatId, 
                                                  String publicKey) {
        Log.d(TAG, "Push notification received, passing to native layer");

        // Call native C++ method to forward to status-go.
        // If Qt/native isn't loaded/registered yet, do NOT crash the process.
        try {
            nativeOnPushNotificationReceived(encryptedMessage, chatId, publicKey);
        } catch (UnsatisfiedLinkError e) {
            Log.w(TAG, "Native layer not available for push payload yet; dropping payload (best-effort mode)", e);
        }
    }
    
    /**
     * Called from C++/Qt layer to display a notification
     * This is called after status-go processes and decrypts the message
     * 
     * @param title Notification title (chat name or sender name)
     * @param message Notification message text
     * @param identifier JSON string containing notification metadata for handling clicks
     */
    public static void showNotification(String title, String message, String identifier) {
        Log.d(TAG, "showNotification called - Title: " + title + ", Message: " + message);
        
        try {
            // Get application context from Qt
            Context context = getApplicationContext();
            if (context == null) {
                Log.e(TAG, "Failed to get application context");
                return;
            }
            
            // Create notification channel (required for Android O+)
            createNotificationChannel(context);
            
            // Parse identifier to get deep link
            String deepLink = extractDeepLinkFromIdentifier(identifier);
            
            // Create intent for when notification is tapped
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setData(android.net.Uri.parse(deepLink));
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            
            PendingIntent pendingIntent = PendingIntent.getActivity(
                context,
                identifier.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );
            
            // Build notification
            NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info) // TODO: Use app icon
                .setContentTitle(title)
                .setContentText(message)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent);
            
            // Show notification
            NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
            notificationManager.notify(identifier.hashCode(), builder.build());
            
            Log.d(TAG, "Notification displayed successfully");
            
        } catch (Exception e) {
            Log.e(TAG, "Error showing notification", e);
        }
    }
    
    /**
     * Clear all notifications for a specific chat
     * Called when user opens a chat
     */
    public static void clearNotifications(String chatId) {
        Log.d(TAG, "Clearing notifications for chat: " + chatId);
        
        try {
            Context context = getApplicationContext();
            if (context == null) return;
            
            NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
            // For now, just cancel by chat ID hash
            // In a full implementation, we'd track notification IDs
            notificationManager.cancel(chatId.hashCode());
            
        } catch (Exception e) {
            Log.e(TAG, "Error clearing notifications", e);
        }
    }
    
    /**
     * Create notification channel (required for Android O+)
     */
    private static void createNotificationChannel(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            );
            channel.setDescription("Status chat message notifications");
            channel.enableVibration(true);
            channel.setShowBadge(true);
            
            NotificationManager notificationManager = context.getSystemService(NotificationManager.class);
            if (notificationManager != null) {
                notificationManager.createNotificationChannel(channel);
            }
        }
    }
    
    /**
     * Extract deep link from notification identifier JSON
     * The identifier contains metadata like: {"chatId": "...", "deepLink": "status-app://..."}
     */
    private static String extractDeepLinkFromIdentifier(String identifier) {
        try {
            org.json.JSONObject json = new org.json.JSONObject(identifier);
            if (json.has("chatId")) {
                String chatId = json.getString("chatId");
                return "status-app://chat/" + chatId;
            }
        } catch (Exception e) {
            Log.w(TAG, "Failed to parse identifier, using default deep link", e);
        }
        return "status-app://";
    }
    
    /**
     * Get application context
     * Returns the context stored during initialization
     */
    private static Context getApplicationContext() {
        if (sApplicationContext == null) {
            Log.e(TAG, "PushNotificationHelper not initialized! Call initialize() first.");
        }
        return sApplicationContext;
    }
    
    // ============================================================================
    // Native methods (implemented in C++ and registered via JNI)
    // ============================================================================
    
    /**
     * Called when FCM token is received
     * Implemented in pushnotification_android.cpp
     */
    private static native void nativeOnFCMTokenReceived(String token);
    
    /**
     * Called when push notification is received
     * Implemented in pushnotification_android.cpp
     */
    private static native void nativeOnPushNotificationReceived(
        String encryptedMessage,
        String chatId,
        String publicKey
    );
}

