package app.status.mobile;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class OpenedFileRulesTest {
    @Test
    public void keepsANameThatHasAnExtension() {
        assertEquals("report.pdf", OpenedFileRules.displayName("report.pdf", "pdf"));
    }

    @Test
    public void addsTheExtensionOfTheTypeToANameWithout() {
        assertEquals("attachment.pdf", OpenedFileRules.displayName("attachment", "pdf"));
    }

    @Test
    public void keepsANameWithoutExtensionWhenTheTypeHasNone() {
        assertEquals("attachment", OpenedFileRules.displayName("attachment", null));
    }

    @Test
    public void dropsDirectoriesFromTheProviderName() {
        assertEquals("prefs.xml", OpenedFileRules.displayName("../../shared_prefs/prefs.xml", "xml"));
        assertEquals("x.txt", OpenedFileRules.displayName("a\\b\\x.txt", "txt"));
    }

    @Test
    public void namesAFileWithNoUsableName() {
        assertEquals("file.pdf", OpenedFileRules.displayName(null, "pdf"));
        assertEquals("file.pdf", OpenedFileRules.displayName("  ", "pdf"));
        assertEquals("file.pdf", OpenedFileRules.displayName("..", "pdf"));
        assertEquals("file", OpenedFileRules.displayName("dir/", null));
    }

    @Test
    public void aFileInsideTheCopiesDirectoryIsACopy() {
        assertTrue(OpenedFileRules.isInside("/data/cache/opened-files/u/x.pdf", "/data/cache/opened-files"));
    }

    @Test
    public void theCopiesDirectoryItselfIsNoCopy() {
        assertFalse(OpenedFileRules.isInside("/data/cache/opened-files", "/data/cache/opened-files"));
        assertFalse(OpenedFileRules.isInside("/data/cache/opened-files/", "/data/cache/opened-files"));
    }

    @Test
    public void aSiblingWithTheSamePrefixIsNoCopy() {
        assertFalse(OpenedFileRules.isInside("/data/cache/opened-files-old/x.pdf", "/data/cache/opened-files"));
        assertFalse(OpenedFileRules.isInside("/data/files/x.pdf", "/data/cache/opened-files"));
    }

    @Test
    public void aCopyIsNamedByTheProviderTypeFirst() {
        assertEquals("application/pdf", OpenedFileRules.nameType("application/pdf", "text/plain"));
        assertEquals("text/plain", OpenedFileRules.nameType("", "text/plain"));
        assertEquals("text/plain", OpenedFileRules.nameType(null, "text/plain"));
        assertEquals("", OpenedFileRules.nameType(null, null));
    }

    @Test
    public void nothingIsInsideAMissingDirectory() {
        assertFalse(OpenedFileRules.isInside("/x.pdf", ""));
        assertFalse(OpenedFileRules.isInside(null, "/data/cache/opened-files"));
    }
}
