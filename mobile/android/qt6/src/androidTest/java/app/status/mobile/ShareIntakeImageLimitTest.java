package app.status.mobile;

import static org.junit.Assert.assertEquals;

import android.content.Context;
import android.net.Uri;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.filters.SmallTest;
import androidx.test.platform.app.InstrumentationRegistry;

import org.junit.After;
import org.junit.Test;
import org.junit.runner.RunWith;

import java.io.File;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;

/**
 * Share intake stops at one image over the composer's 30-image limit: the
 * composer keeps 30 and the extra one makes it show the limit warning, while
 * a 300-photo share is never copied (or transcoded) in full.
 */
@RunWith(AndroidJUnit4.class)
@SmallTest
public class ShareIntakeImageLimitTest {

    private static final Context CTX =
            InstrumentationRegistry.getInstrumentation().getTargetContext();
    private static final String AUTHORITY =
            InstrumentationRegistry.getInstrumentation().getContext().getPackageName()
                    + ".sharetest";

    private String[] copied = new String[0];

    @After
    public void tearDown() {
        for (String path : copied) new File(path).delete();
    }

    private static String[] copyToCache(List<Uri> uris) throws Exception {
        Method m = StatusQtActivity.class.getDeclaredMethod(
                "copySharedImagesToCache", Context.class, List.class);
        m.setAccessible(true);
        return (String[]) m.invoke(null, CTX, uris);
    }

    private static Uri stream(String kind, int i) {
        return Uri.parse("content://" + AUTHORITY + "/" + kind + "/" + i);
    }

    @Test
    public void copiesAtMost31ImagesAndSkipsVideosWithoutCountingThem() throws Exception {
        // Mixed photo/video picks arrive as one */* share; videos are dropped
        // and must not use up the image slots.
        List<Uri> shared = new ArrayList<>();
        for (int i = 0; i < 40; i++) {
            shared.add(stream(ShareTestProvider.VIDEO, i));
            shared.add(stream(ShareTestProvider.IMAGE, i));
        }

        copied = copyToCache(shared);

        assertEquals(31, copied.length);
    }
}
