package app.status.mobile.ipc;

import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import androidx.core.app.RemoteInput;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Handles inline replies from message notifications.
 * Runs in the statusgo process so it can call status-go RPC directly.
 * Uses CallPrivateRPC with a JSON-RPC request for wakuext_sendChatMessage.
 * Uses goAsync() and a background thread so onReceive returns quickly, clearing the
 * notification loading state, and to avoid blocking the main thread / ANR.
 */
public final class NotificationReplyReceiver extends BroadcastReceiver {
    private static final String TAG = "NotificationReplyReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || !StatusGoService.ACTION_REPLY.equals(intent.getAction())) return;

        android.os.Bundle remoteInput = RemoteInput.getResultsFromIntent(intent);
        CharSequence replyText = remoteInput != null
                ? remoteInput.getCharSequence(StatusGoService.REPLY_REMOTE_INPUT_KEY)
                : null;
        if (replyText == null || replyText.toString().trim().isEmpty()) return;

        String conversationId = intent.getStringExtra("conversationId");
        if (conversationId == null || conversationId.isEmpty()) return;

        final String replyTextStr = replyText.toString().trim();
        final int androidNotificationId = intent.getIntExtra("androidNotificationId", 0);

        final PendingResult pendingResult = goAsync();
        final Context appContext = context.getApplicationContext();

        new Thread(() -> {
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
                if (result != null && result.contains("\"error\"")) {
                    Log.w(TAG, "sendChatMessage failed: " + result);
                }

                if (androidNotificationId != 0) {
                    NotificationManager.from(appContext).cancel(androidNotificationId);
                }
            } catch (Exception e) {
                Log.w(TAG, "failed to send reply", e);
            } finally {
                pendingResult.finish();
            }
        }).start();
    }
}
