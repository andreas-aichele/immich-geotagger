package io.github.andreasaichele.diagnostics;
import org.junit.Test;
import static org.junit.Assert.*;

public class LogSanitizerTest {
    @Test public void removesCredentialsAndUrlsAndPreventsForgedLines() {
        String result = LogSanitizer.sanitize("https://user:pass@private.example/api?token=secret x-api-key=abc Authorization: Bearer def password=ghi\nFAKE INFO");
        for (String secret : new String[]{"private.example", "secret", "abc", "def", "ghi", "\n"}) {
            assertFalse(result.contains(secret));
        }
        assertTrue(result.contains("[URL]"));
        assertTrue(result.contains("[REDACTED]"));
    }
    @Test public void limitsEntrySize() {
        assertEquals(16000, LogSanitizer.sanitize("x".repeat(20000)).length());
    }
}
