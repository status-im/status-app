package app.status.mobile.ipc;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class BootLoginRecordVersionTest {
    private static final String RECORD_42 = "{\"version\":1,\"keyUid\":\"0xkeyuid\",\"versionCode\":42}";

    @Test
    public void aRecordFromAnOlderVersionIsFromAnotherVersion() {
        assertTrue(BootLoginRecordVersion.writtenByOtherVersion(RECORD_42, 43L));
    }

    @Test
    public void aRecordFromThisVersionIsNot() {
        assertFalse(BootLoginRecordVersion.writtenByOtherVersion(RECORD_42, 42L));
    }

    @Test
    public void aRecordWithoutAVersionCodeIsFromAnotherVersion() {
        assertTrue(BootLoginRecordVersion.writtenByOtherVersion("{\"keyUid\":\"0xkeyuid\"}", 42L));
    }

    @Test
    public void noReadableRecordIsNot() {
        assertFalse(BootLoginRecordVersion.writtenByOtherVersion(null, 42L));
        assertFalse(BootLoginRecordVersion.writtenByOtherVersion("", 42L));
        assertFalse(BootLoginRecordVersion.writtenByOtherVersion("not json", 42L));
    }
}
