package app.status.mobile.ipc;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import androidx.core.app.NotificationManagerCompat;
import androidx.core.app.RemoteInput;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import app.status.mobile.ipc.notifications.NotificationBuilder;
import app.status.mobile.ipc.notifications.StatusNotificationManager;

/**
 * Handles inline replies from message notifications.
 * Runs in the statusgo process so it can call status-go RPC directly.
 * Uses CallPrivateRPC with a JSON-RPC request for wakuext_sendChatMessage.
 * Uses goAsync() and an executor so onReceive returns quickly, clearing the
 * notification loading state, and to avoid blocking the main thread / ANR.
 */
public final class NotificationReplyReceiver extends BroadcastReceiver {
    private static final String TAG = "NotificationReplyReceiver";

    /** Shared executor for reply work; daemon thread since statusgo process is long-lived. */
    private static final ExecutorService REPLY_EXECUTOR = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "notification-reply");
        t.setDaemon(true);
        return t;
    });

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) return;

        String action = intent.getAction();
        if (NotificationBuilder.ACTION_DISMISS.equals(action)) {
            String conversationId = intent.getStringExtra("conversationId");
            StatusNotificationManager mgr = StatusNotificationManager.getInstance();
            if (mgr != null) mgr.clearConversation(conversationId);
            return;
        }

        if (NotificationBuilder.ACTION_ACCEPT_CONTACT_REQUEST.equals(action)
                || NotificationBuilder.ACTION_REJECT_CONTACT_REQUEST.equals(action)) {
            handleContactRequestAction(context, intent, action);
            return;
        }

        if (!NotificationBuilder.ACTION_REPLY.equals(action)) return;

        android.os.Bundle remoteInput = RemoteInput.getResultsFromIntent(intent);
        CharSequence replyText = remoteInput != null
                ? remoteInput.getCharSequence(NotificationBuilder.REPLY_REMOTE_INPUT_KEY)
                : null;
        if (replyText == null || replyText.toString().trim().isEmpty()) return;

        String conversationId = intent.getStringExtra("conversationId");
        if (conversationId == null || conversationId.isEmpty()) return;

        final String replyTextStr = replyText.toString().trim();
        final int androidNotificationId = intent.getIntExtra("androidNotificationId", 0);

        final PendingResult pendingResult = goAsync();
        final Context appContext = context.getApplicationContext();

        REPLY_EXECUTOR.execute(() -> {
            try {
                // Build sendChatMessage params (same format as Nim backend)
                JSONObject msg = new JSONObject();
                msg.put("chatId", conversationId);
                msg.put("text", replyTextStr);
                msg.put("contentType", 1); // 1 = TEXT_PLAIN (protobuf ChatMessage_ContentType)
                msg.put("responseTo", "");
                msg.put("ensName", "");
                msg.put("sticker", new JSONObject().put("hash", "").put("pack", 0));
                msg.put("communityId", "");
                msg.put("linkPreviews", new JSONArray());
                msg.put("statusLinkPreviews", new JSONArray());
                msg.put("paymentRequests", new JSONArray());

                JSONArray rpcParams = new JSONArray();
                rpcParams.put(msg);

                JSONObject rpcRequest = new JSONObject();
                rpcRequest.put("jsonrpc", "2.0");
                rpcRequest.put("id", 1);
                rpcRequest.put("method", "wakuext_sendChatMessage");
                rpcRequest.put("params", rpcParams);

                JSONArray args = new JSONArray();
                args.put(rpcRequest.toString());
                String argsJson = args.toString();

                String result = StatusGoService.callRpc("CallPrivateRPC", argsJson);
                boolean failed = result != null && result.contains("\"error\"");

                StatusNotificationManager mgr = StatusNotificationManager.getInstance();

                if (failed) {
                    Log.w(TAG, "sendChatMessage failed: " + result);
                    if (mgr != null) mgr.clearConversation(conversationId);
                    StatusNotificationManager.showReplyFailed(appContext);
                    if (androidNotificationId != 0) {
                        NotificationManagerCompat.from(appContext).cancel(androidNotificationId);
                    }
                } else {
                    if (mgr != null) {
                        mgr.appendReplyAndRefresh(
                                appContext, conversationId, replyTextStr, androidNotificationId);
                    }
                }
            } catch (Exception e) {
                Log.w(TAG, "failed to send reply", e);
                StatusNotificationManager mgr = StatusNotificationManager.getInstance();
                if (mgr != null) mgr.clearConversation(conversationId);
                StatusNotificationManager.showReplyFailed(appContext);
                if (androidNotificationId != 0) {
                    NotificationManagerCompat.from(appContext).cancel(androidNotificationId);
                }
            } finally {
                pendingResult.finish();
            }
        });
    }

    private void handleContactRequestAction(Context context, Intent intent, String action) {
        String conversationId = intent.getStringExtra("conversationId");
        int androidNotificationId = intent.getIntExtra("androidNotificationId", 0);

        if (conversationId == null || conversationId.isEmpty()) return;

        final boolean isAccept = NotificationBuilder.ACTION_ACCEPT_CONTACT_REQUEST.equals(action);
        // Use acceptLatestContactRequestForContact / dismissLatestContactRequestForContact - they take
        // only the contact ID and resolve the pending request internally, which properly updates app state.
        final String method = isAccept ? "wakuext_acceptLatestContactRequestForContact"
                : "wakuext_dismissLatestContactRequestForContact";
        final String contactId = conversationId;
        final PendingResult pendingResult = goAsync();
        final Context appContext = context.getApplicationContext();

        REPLY_EXECUTOR.execute(() -> {
            try {
                JSONObject params = new JSONObject();
                params.put("id", contactId);

                JSONArray rpcParams = new JSONArray();
                rpcParams.put(params);

                JSONObject rpcRequest = new JSONObject();
                rpcRequest.put("jsonrpc", "2.0");
                rpcRequest.put("id", 1);
                rpcRequest.put("method", method);
                rpcRequest.put("params", rpcParams);

                JSONArray args = new JSONArray();
                args.put(rpcRequest.toString());
                String argsJson = args.toString();

                String result = StatusGoService.callRpc("CallPrivateRPC", argsJson);
                boolean failed = result != null && result.contains("\"error\"");

                StatusNotificationManager mgr = StatusNotificationManager.getInstance();
                if (mgr != null) mgr.clearConversation(conversationId);
                if (androidNotificationId != 0) {
                    NotificationManagerCompat.from(appContext).cancel(androidNotificationId);
                }
                if (failed) {
                    Log.w(TAG, method + " failed: " + result);
                }
            } catch (Exception e) {
                Log.w(TAG, "failed to " + (isAccept ? "accept" : "reject") + " contact request", e);
                StatusNotificationManager mgr = StatusNotificationManager.getInstance();
                if (mgr != null) mgr.clearConversation(conversationId);
                if (androidNotificationId != 0) {
                    NotificationManagerCompat.from(appContext).cancel(androidNotificationId);
                }
            } finally {
                pendingResult.finish();
            }
        });
    }
}
