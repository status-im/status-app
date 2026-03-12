package app.status.mobile.ipc.notifications;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
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
     * Creates a circular identicon avatar with the first 2 letters of the name
     * as initials. Background color is derived from the name hash for consistency.
     *
     * @param name display name (uses first 2 chars, or 1 if shorter)
     * @param size width/height of the output bitmap
     * @return circular bitmap with initials, or null if name is empty
     */
    public static Bitmap createInitialsAvatar(String name, int size) {
        if (name == null || name.isEmpty()) return null;
        String initials = name.trim();
        if (initials.isEmpty()) return null;
        initials = initials.length() >= 2
                ? initials.substring(0, 2).toUpperCase()
                : initials.substring(0, 1).toUpperCase();

        int hash = Math.abs(name.hashCode());
        float hue = (hash % 360) / 360f;
        float[] hsv = {hue * 360f, 0.5f, 0.85f};
        int bgColor = Color.HSVToColor(hsv);

        Bitmap bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        Paint bgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        bgPaint.setColor(bgColor);
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, bgPaint);

        Paint textPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        textPaint.setColor(Color.WHITE);
        textPaint.setTextAlign(Paint.Align.CENTER);
        textPaint.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
        textPaint.setTextSize(size * 0.45f);

        Rect bounds = new Rect();
        textPaint.getTextBounds(initials, 0, initials.length(), bounds);
        float x = size / 2f;
        float y = size / 2f - (bounds.top + bounds.bottom) / 2f;
        canvas.drawText(initials, x, y, textPaint);

        return bitmap;
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
     * Returns the app's launcher icon as a {@code sizePx × sizePx} {@link Bitmap} — the same
     * icon the user sees in the app list. Used as the large-icon when no sender/community/chat
     * icon is available so the notification has a recognisable image.
     *
     * @return app launcher icon bitmap, or {@code null} on failure.
     */
    public static Bitmap appIconBitmap(Context context, int sizePx) {
        try {
            Drawable d = context.getPackageManager().getApplicationIcon(context.getPackageName());
            Bitmap bmp = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888);
            Canvas canvas = new Canvas(bmp);
            d.setBounds(0, 0, sizePx, sizePx);
            d.draw(canvas);
            return bmp;
        } catch (Throwable t) {
            Log.w(TAG, "appIconBitmap failed", t);
            return null;
        }
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
