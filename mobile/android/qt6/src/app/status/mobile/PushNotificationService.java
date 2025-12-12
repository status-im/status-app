package app.status.mobile;

import android.util.Log;
import androidx.annotation.NonNull;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

/**
 * FCM Service for receiving push notifications and device tokens
 * 
 * This service handles:
 * - New FCM token generation (onNewToken)
 * - Incoming push notifications (onMessageReceived)
 * 
 * The token is passed to C++/Qt layer via JNI for status-go registration
 */
public class PushNotificationService extends FirebaseMessagingService {
    private static final String TAG = "PushNotificationService";

    /**
     * Called when the service is created by an FCM event
     * Note: This is NOT called on app startup, only when FCM events occur
     */
    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "PushNotificationService created by FCM event");
        // Initialize helper if not already done
        PushNotificationHelper.initialize(this);
    }

    /**
     * Called when FCM generates a new token for this device
     * This happens:
     * - On first app install
     * - When user reinstalls app
     * - When user clears app data
     * - When Firebase decides to rotate the token
     */
    @Override
    public void onNewToken(@NonNull String token) {
        super.onNewToken(token);
        // Pass token to C++ layer which will forward to status-go
        PushNotificationHelper.onFCMTokenReceived(token);
    }

    /**
     * Called when a push notification is received
     * 
     * For Status, this will contain encrypted message data:
     * - encryptedMessage: The encrypted message payload
     * - chatId: The chat identifier
     * - publicKey: Sender's public key
     * 
     * status-go will decrypt and process the message, then emit
     * a localNotifications signal that our Nim layer handles
     */
    @Override
    public void onMessageReceived(@NonNull RemoteMessage remoteMessage) {
        super.onMessageReceived(remoteMessage);
        
        Log.d(TAG, "Push notification received from: " + remoteMessage.getFrom());
        
        // Check if message contains data payload
        if (remoteMessage.getData().size() > 0) {
            Log.d(TAG, "Message data payload: " + remoteMessage.getData());
            
            // Extract push notification data
            String encryptedMessage = remoteMessage.getData().get("encryptedMessage");
            String chatId = remoteMessage.getData().get("chatId");
            String publicKey = remoteMessage.getData().get("publicKey");
            
            if (encryptedMessage != null && chatId != null && publicKey != null) {
                // Pass to C++ layer to forward to status-go
                PushNotificationHelper.onPushNotificationReceived(
                    encryptedMessage,
                    chatId,
                    publicKey
                );
            } else {
                Log.w(TAG, "Push notification missing required fields");
            }
        }
        
        // Check if message contains a notification payload
        if (remoteMessage.getNotification() != null) {
            String title = remoteMessage.getNotification().getTitle();
            String body = remoteMessage.getNotification().getBody();
            Log.d(TAG, "Message Notification - Title: " + title + ", Body: " + body);
            
            // For Status, we typically don't use the notification payload
            // as status-go generates local notifications after decrypting
            // But we log it for debugging
        }
    }

    /**
     * Called when a message is deleted on the server
     * This can happen if the message couldn't be delivered within the TTL
     */
    @Override
    public void onDeletedMessages() {
        super.onDeletedMessages();
        Log.d(TAG, "Messages were deleted on the server");
        // For Status, we don't need to handle this as messages are on Waku
    }
}

