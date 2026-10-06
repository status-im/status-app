package app.status.mobile.ipc;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

import org.junit.Test;

public class SignalTypeResolverTest {
    private static final long INTERVAL_MS = 60_000;

    private int parses;
    private String parsedType = "node.login";
    private boolean parseThrows;
    private long now = 1_000;
    private final List<String> warnings = new ArrayList<>();

    private final SignalTypeResolver resolver = new SignalTypeResolver(
            utf8 -> {
                parses++;
                if (parseThrows) throw new IllegalStateException("bad json");
                return parsedType;
            },
            warnings::add, () -> now, INTERVAL_MS);

    private static ByteBuffer utf8(String s) {
        return ByteBuffer.wrap(s.getBytes(StandardCharsets.UTF_8));
    }

    @Test
    public void fastPathDoesNotParse() {
        assertEquals("community.found",
                resolver.resolve(utf8("{\"type\":\"community.found\",\"event\":{}}")));
        assertEquals(0, parses);
        assertEquals(0, warnings.size());
    }

    @Test
    public void fallsBackToOneFullParseWhenTypeIsNotTheFirstKey() {
        assertEquals("node.login",
                resolver.resolve(utf8("{\"event\":{\"error\":\"\"},\"type\":\"node.login\"}")));
        assertEquals(1, parses);
        assertEquals(1, warnings.size());
    }

    @Test
    public void warningIsRateLimited() {
        final ByteBuffer odd = utf8("{\"event\":{},\"type\":\"node.login\"}");
        resolver.resolve(odd);
        now += 1_000;
        resolver.resolve(odd);
        resolver.resolve(odd);
        assertEquals(3, parses);
        assertEquals(1, warnings.size());

        now += INTERVAL_MS;
        resolver.resolve(odd);
        assertEquals(2, warnings.size());
        assertTrue(warnings.get(1), warnings.get(1).contains("suppressed=2"));
    }

    @Test
    public void unparsableSignalYieldsUnknownType() {
        parseThrows = true;
        assertEquals("", resolver.resolve(utf8("not json")));
        assertEquals(1, parses);
        assertEquals(1, warnings.size());
    }

    @Test
    public void fallbackDoesNotConsumeTheBuffer() {
        final ByteBuffer odd = utf8("{\"event\":{},\"type\":\"x\"}");
        resolver.resolve(odd);
        assertEquals(0, odd.position());
    }
}
