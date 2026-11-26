package app.status.mobile.ipc;

/**
 * Carries "the status-go service died during the login" from the dying UI process to the one
 * the frontend restart starts. Android first creates the restart activity in the old process,
 * which is killed right after, so the mark is persisted with the writer's pid and only another
 * process takes it, once. Times are milliseconds since boot.
 */
public final class LoginInterruptedMarker {
    static final long MAX_AGE_MS = 30_000L;

    public interface Store {
        void write(int writerPid, long writtenAt);
        /** 0 when nothing is stored. */
        int writerPid();
        long writtenAt();
        void clear();
    }

    private LoginInterruptedMarker() {}

    public static void mark(Store store, int writerPid, long now) {
        store.write(writerPid, now);
    }

    public static boolean take(Store store, int myPid, long now) {
        final int writer = store.writerPid();
        if (writer == 0 || writer == myPid) return false;
        final long age = now - store.writtenAt();
        store.clear();
        return age >= 0 && age <= MAX_AGE_MS;
    }
}
