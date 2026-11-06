package app.status.mobile;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class ShareIntakeRulesTest {
    @Test
    public void explainsATextFileThatCarriesNoText() {
        assertTrue(ShareIntakeRules.explainsNothingShared(false, false, true));
    }

    @Test
    public void explainsAnImageShareWithNoImageLeft() {
        assertTrue(ShareIntakeRules.explainsNothingShared(false, true, false));
    }

    @Test
    public void staysQuietOnAnEmptyTextShare() {
        assertFalse(ShareIntakeRules.explainsNothingShared(false, false, false));
    }

    @Test
    public void staysQuietWhenSomethingIsShared() {
        assertFalse(ShareIntakeRules.explainsNothingShared(true, false, true));
        assertFalse(ShareIntakeRules.explainsNothingShared(true, true, true));
    }
}
