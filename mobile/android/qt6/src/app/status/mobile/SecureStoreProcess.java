package app.status.mobile;

/** Which process the secure store runs in, and what that means for its preferences cache. */
final class SecureStoreProcess {
    private static final String SERVICE_PROCESS_SUFFIX = ":statusgo";

    private SecureStoreProcess() {}

    /**
     * SharedPreferences keeps one in-memory map per process and commits that whole map. The
     * UI process writes the store while the :statusgo process reads and deletes the boot-login
     * record, so a :statusgo commit from a stale map could bring back an entry the UI removed
     * (e.g. the record after a sign-out). The :statusgo process therefore reloads the file
     * before every access when it changed on disk.
     */
    static boolean reloadsBeforeEveryAccess(String processName) {
        return processName != null && processName.endsWith(SERVICE_PROCESS_SUFFIX);
    }
}
