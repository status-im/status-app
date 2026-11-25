package app.status.mobile.ipc;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class BootLoginTriggerTest {
    private static final String BOOT_COMPLETED = "android.intent.action.BOOT_COMPLETED";
    private static final String MY_PACKAGE_REPLACED = "android.intent.action.MY_PACKAGE_REPLACED";

    @Test
    public void bootStartsTheBootLoginWhenARecordIsStored() {
        assertTrue(BootLoginTrigger.startsBootLogin(BOOT_COMPLETED, true));
    }

    @Test
    public void appUpdateStartsTheBootLoginWhenARecordIsStored() {
        assertTrue(BootLoginTrigger.startsBootLogin(MY_PACKAGE_REPLACED, true));
    }

    @Test
    public void nothingStartsWithoutARecord() {
        assertFalse(BootLoginTrigger.startsBootLogin(BOOT_COMPLETED, false));
        assertFalse(BootLoginTrigger.startsBootLogin(MY_PACKAGE_REPLACED, false));
    }

    @Test
    public void otherActionsStartNothing() {
        assertFalse(BootLoginTrigger.startsBootLogin("android.intent.action.PACKAGE_REPLACED", true));
        assertFalse(BootLoginTrigger.startsBootLogin(null, true));
    }
}
