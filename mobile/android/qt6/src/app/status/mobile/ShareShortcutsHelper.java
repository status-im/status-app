package app.status.mobile;

import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.Log;

import androidx.core.app.Person;
import androidx.core.content.pm.ShortcutInfoCompat;
import androidx.core.content.pm.ShortcutManagerCompat;
import androidx.core.graphics.drawable.IconCompat;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Publishes recent Status chats as Android sharing shortcuts, so they appear
 * as one-tap direct-share targets at the top of the OS share sheet (share
 * targets declared in res/xml/share_shortcuts.xml). Decision-free platform
 * layer: the Qt side decides what to publish and when (recency model), and
 * when to clear (logout). A shortcut's id is the destination chat id — the
 * share sheet echoes it back via Intent.EXTRA_SHORTCUT_ID on tap, which
 * StatusQtActivity forwards through the share intake so the app can skip the
 * destination picker.
 */
public class ShareShortcutsHelper {
    private static final String TAG = "ShareShortcutsHelper";

    // Must match the <category> entries in res/xml/share_shortcuts.xml.
    private static final String SHARE_CATEGORY =
            "app.status.mobile.directshare.category.SHARE_TARGET";

    /**
     * Replaces the published set. shortcutsJson: JSON array of
     * {id, name, iconPath?} objects in rank order (most recent first); an
     * empty array clears the set. Called from Qt via JNI.
     */
    public static void publish(Context context, String shortcutsJson) {
        try {
            JSONArray shortcuts = new JSONArray(shortcutsJson != null ? shortcutsJson : "[]");
            int count = Math.min(shortcuts.length(),
                    ShortcutManagerCompat.getMaxShortcutCountPerActivity(context));

            List<ShortcutInfoCompat> infos = new ArrayList<>();
            for (int i = 0; i < count; i++) {
                JSONObject shortcut = shortcuts.getJSONObject(i);
                String id = shortcut.optString("id");
                String name = shortcut.optString("name");
                if (id.isEmpty() || name.isEmpty()) continue;

                // The share sheet launches the SEND intent itself (carrying
                // EXTRA_SHORTCUT_ID); this intent only backs the launcher
                // long-press entry, where the shortcut simply opens the app.
                Intent launchIntent = new Intent(Intent.ACTION_MAIN)
                        .setClass(context, StatusQtActivity.class)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

                ShortcutInfoCompat.Builder builder = new ShortcutInfoCompat.Builder(context, id)
                        .setShortLabel(name)
                        .setRank(i)
                        .setIntent(launchIntent)
                        .setCategories(Collections.singleton(SHARE_CATEGORY))
                        .setPerson(new Person.Builder().setName(name).build());

                String iconPath = shortcut.optString("iconPath");
                if (!iconPath.isEmpty()) {
                    Bitmap bitmap = BitmapFactory.decodeFile(iconPath);
                    if (bitmap != null) {
                        builder.setIcon(IconCompat.createWithBitmap(bitmap));
                    }
                }
                infos.add(builder.build());
            }

            ShortcutManagerCompat.setDynamicShortcuts(context, infos);
        } catch (Exception e) {
            Log.w(TAG, "failed to publish share shortcuts", e);
        }
    }

    /**
     * Removes every published shortcut — logout hygiene: chat names and
     * avatars live on OS surfaces outside the app and must not linger for a
     * logged-out profile. Also drops any system-cached copies. Called from Qt
     * via JNI.
     */
    public static void clear(Context context) {
        try {
            List<ShortcutInfoCompat> existing = ShortcutManagerCompat.getShortcuts(context,
                    ShortcutManagerCompat.FLAG_MATCH_DYNAMIC
                            | ShortcutManagerCompat.FLAG_MATCH_CACHED);
            List<String> ids = new ArrayList<>();
            for (ShortcutInfoCompat shortcut : existing) {
                ids.add(shortcut.getId());
            }
            if (!ids.isEmpty()) {
                ShortcutManagerCompat.removeLongLivedShortcuts(context, ids);
            }
            ShortcutManagerCompat.removeAllDynamicShortcuts(context);
        } catch (Exception e) {
            Log.w(TAG, "failed to clear share shortcuts", e);
        }
    }
}
