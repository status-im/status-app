package app.status.mobile;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.filters.SmallTest;

import org.junit.Test;
import org.junit.runner.RunWith;

@RunWith(AndroidJUnit4.class)
@SmallTest
public class ICalendarTextTest {

    // Apple Calendar export: TZID, folded description with escapes, nested
    // alarm, an all-day range (exclusive DTEND), a start-only event and one
    // crossing midnight in UTC.
    private static final String SAMPLE = ""
            + "BEGIN:VCALENDAR\r\n"
            + "VERSION:2.0\r\n"
            + "PRODID:-//Apple Inc.//iOS 26.0//EN\r\n"
            + "BEGIN:VEVENT\r\n"
            + "UID:abc\r\n"
            + "DTSTAMP:20261001T120000Z\r\n"
            + "DTSTART;TZID=Europe/Bucharest:20261005T090000\r\n"
            + "DTEND;TZID=Europe/Bucharest:20261005T093000\r\n"
            + "SUMMARY:Team sync\r\n"
            + "LOCATION:Meeting room 2\r\n"
            + "DESCRIPTION:Agenda in the thread\\nBring\r\n"
            + "  laptop\r\n"
            + "URL:https://example.org/meet\r\n"
            + "BEGIN:VALARM\r\n"
            + "TRIGGER:-PT10M\r\n"
            + "DESCRIPTION:Reminder\r\n"
            + "END:VALARM\r\n"
            + "END:VEVENT\r\n"
            + "BEGIN:VEVENT\r\n"
            + "DTSTART;VALUE=DATE:20261010\r\n"
            + "DTEND;VALUE=DATE:20261012\r\n"
            + "SUMMARY:Offsite\r\n"
            + "END:VEVENT\r\n"
            + "BEGIN:VEVENT\r\n"
            + "DTSTART:20261020T180000Z\r\n"
            + "SUMMARY:Call\r\n"
            + "END:VEVENT\r\n"
            + "BEGIN:VEVENT\r\n"
            + "DTSTART:20261231T230000Z\r\n"
            + "DTEND:20270101T010000Z\r\n"
            + "SUMMARY:New Year\r\n"
            + "END:VEVENT\r\n"
            + "END:VCALENDAR\r\n";

    private static final String EXPECTED = ""
            + "Team sync\n"
            + "5 Oct 2026, 09:00 – 09:30 Europe/Bucharest\n"
            + "Meeting room 2\n"
            + "Agenda in the thread\n"
            + "Bring laptop\n"
            + "https://example.org/meet\n"
            + "\n"
            + "Offsite\n"
            + "10 Oct 2026 – 11 Oct 2026\n"
            + "\n"
            + "Call\n"
            + "20 Oct 2026, 18:00 UTC\n"
            + "\n"
            + "New Year\n"
            + "31 Dec 2026, 23:00 – 1 Jan 2027, 01:00 UTC";

    @Test
    public void detectsOnlyLeadingBegin() {
        assertTrue(ICalendarText.isICalendar("\nbegin:vcalendar\nEND:VCALENDAR"));
        assertFalse(ICalendarText.isICalendar("see BEGIN:VCALENDAR below"));
    }

    @Test
    public void rendersReadableEvents() {
        assertEquals(EXPECTED, ICalendarText.format(SAMPLE));
    }

    @Test
    public void calendarWithoutEventsFallsBackToRawText() {
        String raw = "BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR";
        assertEquals(raw, ICalendarText.format(raw));
    }

    @Test
    public void singleDayAllDayRangeIsOneDate() {
        String one = "BEGIN:VCALENDAR\nBEGIN:VEVENT\nDTSTART;VALUE=DATE:20261010\n"
                + "DTEND;VALUE=DATE:20261011\nSUMMARY:Day\nEND:VEVENT\nEND:VCALENDAR";
        assertEquals("Day\n10 Oct 2026", ICalendarText.format(one));
    }
}
