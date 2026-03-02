package app.status.mobile.ipc.notifications;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Rect;
import android.util.Base64;
import android.util.Log;

/**
 * Stateless utility for notification icon processing.
 * Handles base64 data-URI decoding, scaling, and circular cropping for
 * notification large icons and sender avatars.
 */
public final class NotificationIconHelper {
    private static final String TAG = "NotificationIconHelper";
    private static final int MAX_ICON_SIZE = 256;

    private NotificationIconHelper() {}

    /**
     * Decodes a data URI ({@code data:image/...;base64,...}) into a circular {@link Bitmap}
     * suitable for use as a notification large icon or {@code Person} avatar.
     *
     * @return circular bitmap, or {@code null} if the URI is empty/invalid.
     */
    public static Bitmap parseToBitmap(String dataUri) {
        if (dataUri == null || dataUri.isEmpty()) return null;
        try {
            if (dataUri.startsWith("data:")) {
                int comma = dataUri.indexOf(',');
                if (comma < 0) return null;
                byte[] bytes = Base64.decode(dataUri.substring(comma + 1), Base64.DEFAULT);
                Bitmap bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
                if (bitmap == null) return null;
                if (bitmap.getWidth() > MAX_ICON_SIZE || bitmap.getHeight() > MAX_ICON_SIZE) {
                    float scale = Math.min((float) MAX_ICON_SIZE / bitmap.getWidth(),
                            (float) MAX_ICON_SIZE / bitmap.getHeight());
                    int w = Math.round(bitmap.getWidth() * scale);
                    int h = Math.round(bitmap.getHeight() * scale);
                    Bitmap scaled = Bitmap.createScaledBitmap(bitmap, w, h, true);
                    if (bitmap != scaled) bitmap.recycle();
                    bitmap = scaled;
                }
                return makeCircular(bitmap);
            }
        } catch (Throwable t) {
            Log.w(TAG, "parseToBitmap failed", t);
        }
        return null;
    }

    /**
     * Crops a bitmap to a circle so opaque sources (e.g. JPEG) render as
     * true circles with transparent corners.
     */
    public static Bitmap makeCircular(Bitmap source) {
        if (source == null) return null;
        int size = Math.min(source.getWidth(), source.getHeight());
        if (size <= 0) return source;
        Bitmap output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        output.eraseColor(Color.TRANSPARENT);
        Canvas canvas = new Canvas(output);
        Path circle = new Path();
        circle.addCircle(size / 2f, size / 2f, size / 2f, Path.Direction.CW);
        canvas.clipPath(circle);
        int srcX = (source.getWidth() - size) / 2;
        int srcY = (source.getHeight() - size) / 2;
        Rect src = new Rect(srcX, srcY, srcX + size, srcY + size);
        Rect dst = new Rect(0, 0, size, size);
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
        canvas.drawBitmap(source, src, dst, paint);
        if (source != output) source.recycle();
        return output;
    }

    /**
     * Picks the most appropriate large-icon URI based on notification category.
     * <ul>
     *   <li>Community notifications: community icon preferred, fallback to sender.</li>
     *   <li>Group chat/invite: group/chat icon preferred, fallback to sender.</li>
     *   <li>1-1 and contact request: sender icon.</li>
     * </ul>
     */
    public static String pickLargeIconUri(String category, String communityIcon,
            String chatIcon, String senderIcon) {
        switch (category) {
            case "contactRequest":
                return !senderIcon.isEmpty() ? senderIcon : null;
            case "communityRequestToJoin":
            case "communityJoined":
                return !communityIcon.isEmpty() ? communityIcon
                        : (!senderIcon.isEmpty() ? senderIcon : null);
            case "groupInvite":
                return !chatIcon.isEmpty() ? chatIcon
                        : (!senderIcon.isEmpty() ? senderIcon : null);
            case "newMessage":
                if (!communityIcon.isEmpty()) return communityIcon;
                if (!chatIcon.isEmpty()) return chatIcon;
                return !senderIcon.isEmpty() ? senderIcon : null;
            default:
                return !senderIcon.isEmpty() ? senderIcon : null;
        }
    }
}
