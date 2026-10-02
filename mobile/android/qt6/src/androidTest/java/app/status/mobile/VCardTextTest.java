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
public class VCardTextTest {

    // Apple Contacts export: groups, folded base64 photo, escapes, plus a
    // vCard 2.1 card with bare type words.
    private static final String SAMPLE = ""
            + "BEGIN:VCARD\r\n"
            + "VERSION:3.0\r\n"
            + "PRODID:-//Apple Inc.//iOS 26.0//EN\r\n"
            + "N:Doe;Jane;;Dr.;\r\n"
            + "FN:Dr. Jane Doe\r\n"
            + "ORG:Acme Corp;R&D\r\n"
            + "TITLE:Engineer\r\n"
            + "item1.EMAIL;type=INTERNET;type=pref:jane@acme.com\r\n"
            + "item1.X-ABLabel:_$!<Other>!$_\r\n"
            + "TEL;type=CELL;type=VOICE;type=pref:+1 555 0100\r\n"
            + "TEL;type=WORK;type=VOICE:+1 555 0200\r\n"
            + "item2.ADR;type=HOME;type=pref:;;1 Main St;Springfield;IL;62701;USA\r\n"
            + "item2.X-ABADR:us\r\n"
            + "item3.URL;type=pref:https://acme.com\r\n"
            + "item3.X-ABLabel:_$!<HomePage>!$_\r\n"
            + "NOTE:Met at conf\\, 2026\\nFollow up\r\n"
            + "PHOTO;ENCODING=b;TYPE=JPEG:/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a\r\n"
            + " HBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIy\r\n"
            + "END:VCARD\r\n"
            + "BEGIN:VCARD\r\n"
            + "VERSION:2.1\r\n"
            + "N:Smith;Bob\r\n"
            + "TEL;CELL:+44 20 7946 0958\r\n"
            + "END:VCARD\r\n";

    private static final String EXPECTED = ""
            + "Dr. Jane Doe\n"
            + "Engineer\n"
            + "Acme Corp, R&D\n"
            + "+1 555 0100 (mobile)\n"
            + "+1 555 0200 (work)\n"
            + "jane@acme.com\n"
            + "https://acme.com\n"
            + "1 Main St, Springfield, IL, 62701, USA (home)\n"
            + "Met at conf, 2026\n"
            + "Follow up\n"
            + "\n"
            + "Bob Smith\n"
            + "+44 20 7946 0958 (mobile)";

    @Test
    public void detectsOnlyLeadingBegin() {
        assertTrue(VCardText.isVCard("\n begin:vcard\nEND:VCARD"));
        assertFalse(VCardText.isVCard("see BEGIN:VCARD in the attachment"));
    }

    @Test
    public void rendersReadableCards() {
        assertEquals(EXPECTED, VCardText.format(SAMPLE));
    }

    @Test
    public void unreadableCardFallsBackToRawText() {
        String raw = "BEGIN:VCARD\nVERSION:3.0\nEND:VCARD";
        assertEquals(raw, VCardText.format(raw));
    }
}
