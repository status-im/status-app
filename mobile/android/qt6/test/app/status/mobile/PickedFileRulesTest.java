package app.status.mobile;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class PickedFileRulesTest {
    @Test
    public void aBareUuidIsALegacyCopy() {
        assertTrue(PickedFileRules.isLegacyCopyName("793a9d0b-d1ef-43a9-8791-253422b66cf2"));
    }

    @Test
    public void otherCacheEntriesAreNot() {
        assertFalse(PickedFileRules.isLegacyCopyName(null));
        assertFalse(PickedFileRules.isLegacyCopyName(""));
        assertFalse(PickedFileRules.isLegacyCopyName("share-intake"));
        assertFalse(PickedFileRules.isLegacyCopyName("statusq_oriented_793a9d0b-d1ef-43a9-8791-253422b66cf2.jpg"));
        assertFalse(PickedFileRules.isLegacyCopyName("793a9d0b-d1ef-43a9-8791-253422b66cf2.jpg"));
        assertFalse(PickedFileRules.isLegacyCopyName("{793a9d0b-d1ef-43a9-8791-253422b66cf2}"));
        assertFalse(PickedFileRules.isLegacyCopyName("793A9D0B-D1EF-43A9-8791-253422B66CF2"));
        assertFalse(PickedFileRules.isLegacyCopyName("793a9d0bd1ef43a98791253422b66cf2"));
    }
}
