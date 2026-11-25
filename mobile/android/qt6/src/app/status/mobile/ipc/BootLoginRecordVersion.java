package app.status.mobile.ipc;

import org.json.JSONObject;

/**
 * Whether the boot-login record was written by another app version (the app was updated
 * since). Such a record is still replayed; the UI refreshes it on its next open.
 */
public final class BootLoginRecordVersion {
    private BootLoginRecordVersion() {}

    public static boolean writtenByOtherVersion(String recordJson, long installedVersionCode) {
        if (recordJson == null || recordJson.isEmpty()) return false;
        final JSONObject record;
        try {
            record = new JSONObject(recordJson);
        } catch (Exception e) {
            return false;
        }
        return !record.has("versionCode") || record.optLong("versionCode") != installedVersionCode;
    }
}
