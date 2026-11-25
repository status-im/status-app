package app.status.mobile.ipc;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class BootLoginTriggerTest {
    private static final String BOOT_COMPLETED = "android.intent.action.BOOT_COMPLETED";
    private static final String MY_PACKAGE_REPLACED = "android.intent.action.MY_PACKAGE_REPLACED";

    private int recordChecks;

    private BootLogin.Condition recordStored(boolean stored) {
        return () -> {
            recordChecks++;
            return stored;
        };
    }

    @Test
    public void bootStartsTheBootLoginWhenARecordIsStored() {
        assertTrue(BootLoginTrigger.startsBootLogin(BOOT_COMPLETED, recordStored(true)));
    }

    @Test
    public void appUpdateStartsTheBootLoginWhenARecordIsStored() {
        assertTrue(BootLoginTrigger.startsBootLogin(MY_PACKAGE_REPLACED, recordStored(true)));
    }

    @Test
    public void nothingStartsWithoutARecord() {
        assertFalse(BootLoginTrigger.startsBootLogin(BOOT_COMPLETED, recordStored(false)));
        assertFalse(BootLoginTrigger.startsBootLogin(MY_PACKAGE_REPLACED, recordStored(false)));
    }

    @Test
    public void otherActionsStartNothing() {
        assertFalse(BootLoginTrigger.startsBootLogin("android.intent.action.PACKAGE_REPLACED", recordStored(true)));
        assertFalse(BootLoginTrigger.startsBootLogin(null, recordStored(true)));
    }

    // The record check removes a record when the feature is off: only a trigger runs it
    @Test
    public void otherActionsNeverCheckTheRecord() {
        BootLoginTrigger.startsBootLogin("android.intent.action.PACKAGE_REPLACED", recordStored(true));
        BootLoginTrigger.startsBootLogin(null, recordStored(true));

        assertEquals(0, recordChecks);
    }
}
