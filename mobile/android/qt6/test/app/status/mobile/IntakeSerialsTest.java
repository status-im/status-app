package app.status.mobile;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class IntakeSerialsTest {
    @Test
    public void aFileOpenedWhileAShareIsCopyingKeepsTheShareWhenLoggedIn() {
        IntakeSerials serials = new IntakeSerials();
        IntakeSerials.Ticket share = serials.nextShare();
        IntakeSerials.Ticket file = serials.next();
        assertFalse(serials.isStale(share, true));
        assertFalse(serials.isStale(file, true));
    }

    @Test
    public void aShareCopyingWhileAFileIsReadKeepsTheFileWhenLoggedIn() {
        IntakeSerials serials = new IntakeSerials();
        IntakeSerials.Ticket file = serials.next();
        serials.nextShare();
        assertFalse(serials.isStale(file, true));
    }

    @Test
    public void aLaterShareReplacesAnEarlierOneWhenLoggedIn() {
        IntakeSerials serials = new IntakeSerials();
        IntakeSerials.Ticket first = serials.nextShare();
        IntakeSerials.Ticket second = serials.nextShare();
        assertTrue(serials.isStale(first, true));
        assertFalse(serials.isStale(second, true));
    }

    @Test
    public void beforeLoginTheNewestIntakeOfAnyKindWins() {
        IntakeSerials serials = new IntakeSerials();
        IntakeSerials.Ticket share = serials.nextShare();
        IntakeSerials.Ticket url = serials.next();
        assertTrue(serials.isStale(share, false));
        assertFalse(serials.isStale(url, false));
    }
}
