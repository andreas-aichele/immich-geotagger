package io.github.andreasaichele.diagnostics;

import org.junit.Test;
import org.junit.Rule;
import org.junit.rules.TemporaryFolder;
import java.io.*;
import java.util.*;
import java.util.zip.*;
import static org.junit.Assert.*;

public class CrashReportStoreTest {
    @Rule public TemporaryFolder temp = new TemporaryFolder();
    private static ByteArrayInputStream bytes(int size) { return new ByteArrayInputStream(new byte[size]); }

    @Test public void retainsNewestTwoIncludingOutOfOrderHistoricalExits() throws Exception {
        File directory = temp.newFolder();
        CrashReportStore store = new CrashReportStore(directory);
        assertEquals("saved", store.save(30, true, bytes(30), 100));
        assertEquals("saved", store.save(20, false, bytes(20), 100));
        assertEquals("not_retained", store.save(10, true, bytes(10), 100));
        assertEquals("saved", store.save(40, true, bytes(40), 100));
        assertEquals(2, store.count());
        assertNotNull(store.report(30));
        assertNotNull(store.report(40));
        assertNull(store.report(20));
    }

    @Test public void skipsMissingEmptyAndOversizedReportsWithoutPartialProtobuf() throws Exception {
        File directory = temp.newFolder();
        CrashReportStore store = new CrashReportStore(directory);
        assertEquals("unavailable", store.save(1, true, null, 100));
        assertEquals("unavailable", store.save(2, true, bytes(0), 100));
        assertEquals("too_large", store.save(3, true, bytes(101), 100));
        assertEquals(0, directory.listFiles().length);
        assertEquals("saved", store.save(4, true, bytes(100), 100));
        assertEquals(100, store.report(4).length());
    }

    @Test public void failedReadCleansTemporaryReportAndKeepsPreviousData() throws Exception {
        File directory = temp.newFolder();
        CrashReportStore store = new CrashReportStore(directory);
        store.save(1, true, bytes(40), 100);
        try {
            store.save(2, true, new InputStream() {
                @Override public int read() throws IOException { throw new IOException("system trace expired"); }
            }, 100);
            fail("Expected I/O failure");
        } catch (IOException expected) { }
        assertEquals(1, directory.listFiles().length);
        assertNotNull(store.report(1));
    }

    @Test public void ordinaryExportExcludesRawReportsAndOptInExportPreservesBytes() throws Exception {
        File directory = temp.newFolder();
        RotatingLogStore store = new RotatingLogStore(directory, 5);
        byte[] report = new byte[]{0, 1, -1, 3, 4};
        store.locked(() -> {
            store.append("ordinary log", 100);
            store.crashReports.save(123, true, new ByteArrayInputStream(report), 100);
            store.crashReports.summary("[{\"reason\":5,\"traceStatus\":\"saved\"}]");
            return null;
        });
        File basic = new File(temp.getRoot(), "basic.zip");
        File full = new File(temp.getRoot(), "full.zip");
        store.locked(() -> { store.export(basic, "{}", false); store.export(full, "{}", true); return null; });
        try (ZipFile zip = new ZipFile(basic)) {
            assertNotNull(zip.getEntry("process-exits.json"));
            assertNull(zip.getEntry("crash-reports/exit-123.pb"));
        }
        try (ZipFile zip = new ZipFile(full)) {
            assertNotNull(zip.getEntry("app.log"));
            try (InputStream input = zip.getInputStream(zip.getEntry("crash-reports/exit-123.pb"))) {
                ByteArrayOutputStream out = new ByteArrayOutputStream();
                byte[] buffer = new byte[64]; int read;
                while ((read = input.read(buffer)) != -1) out.write(buffer, 0, read);
                assertArrayEquals(report, out.toByteArray());
            }
        }
    }

    @Test public void shrinkingBudgetAndClearingRemoveAllCrashData() throws Exception {
        File directory = temp.newFolder();
        CrashReportStore store = new CrashReportStore(directory);
        store.save(1, true, bytes(40), 100);
        store.save(2, false, bytes(20), 100);
        store.summary("[]");
        new File(directory, "exit-3.pb.tmp").createNewFile();
        store.trim(25);
        assertNull(store.report(1));
        assertNotNull(store.report(2));
        store.clear();
        assertEquals(0, directory.listFiles().length);
    }
}
