package app.status.mobile.ipc;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class LoginInterruptedMarkerTest {
    private static final int DYING_UI = 30472;
    private static final int NEW_UI = 30702;

    private static final class MemoryStore implements LoginInterruptedMarker.Store {
        int pid;
        long at;

        @Override public void write(int writerPid, long writtenAt) { pid = writerPid; at = writtenAt; }
        @Override public int writerPid() { return pid; }
        @Override public long writtenAt() { return at; }
        @Override public void clear() { pid = 0; at = 0; }
    }

    private final MemoryStore store = new MemoryStore();

    @Test
    public void theRestartedUiTakesTheMark() {
        LoginInterruptedMarker.mark(store, DYING_UI, 10_000L);

        assertTrue(LoginInterruptedMarker.take(store, NEW_UI, 11_000L));
    }

    // Android first creates the restart activity in the old process, which then dies
    @Test
    public void theDyingUiNeverTakesTheMarkAndLeavesItForTheRestartedOne() {
        LoginInterruptedMarker.mark(store, DYING_UI, 10_000L);

        assertFalse(LoginInterruptedMarker.take(store, DYING_UI, 10_020L));
        assertTrue(LoginInterruptedMarker.take(store, NEW_UI, 11_000L));
    }

    @Test
    public void theMarkIsTakenOnce() {
        LoginInterruptedMarker.mark(store, DYING_UI, 10_000L);
        LoginInterruptedMarker.take(store, NEW_UI, 11_000L);

        assertFalse(LoginInterruptedMarker.take(store, NEW_UI, 11_500L));
        assertFalse(LoginInterruptedMarker.take(store, 31000, 12_000L));
    }

    @Test
    public void nothingToTakeWithoutAMark() {
        assertFalse(LoginInterruptedMarker.take(store, NEW_UI, 11_000L));
    }

    @Test
    public void aMarkOlderThanThirtySecondsIsIgnored() {
        LoginInterruptedMarker.mark(store, DYING_UI, 10_000L);

        assertFalse(LoginInterruptedMarker.take(store, NEW_UI, 40_001L));
    }

    @Test
    public void aMarkThirtySecondsOldIsStillTaken() {
        LoginInterruptedMarker.mark(store, DYING_UI, 10_000L);

        assertTrue(LoginInterruptedMarker.take(store, NEW_UI, 40_000L));
    }

    // The clock counts from boot: a mark written before a phone restart reads as from the future
    @Test
    public void aMarkFromBeforeAPhoneRestartIsIgnored() {
        LoginInterruptedMarker.mark(store, DYING_UI, 900_000L);

        assertFalse(LoginInterruptedMarker.take(store, NEW_UI, 5_000L));
        assertFalse(LoginInterruptedMarker.take(store, NEW_UI, 5_001L));
    }
}
