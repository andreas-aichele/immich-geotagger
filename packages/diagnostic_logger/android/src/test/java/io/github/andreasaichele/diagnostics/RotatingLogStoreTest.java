package io.github.andreasaichele.diagnostics;

import org.junit.Test;
import org.junit.Rule;
import org.junit.rules.TemporaryFolder;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.*;
import java.util.concurrent.*;
import java.util.zip.*;
import static org.junit.Assert.*;

public class RotatingLogStoreTest {
    @Rule public TemporaryFolder temp = new TemporaryFolder();

    @Test public void rotationKeepsNewestFiveFilesWithinBudget() throws Exception {
        File directory = temp.newFolder();
        RotatingLogStore store = new RotatingLogStore(directory, 5);
        for (int i = 0; i < 20; i++) {
            final String line = "entry-" + i + "-" + "x".repeat(70);
            store.locked(() -> { store.append(line, 100); return null; });
        }
        File[] logs = directory.listFiles((dir, name) -> name.startsWith("app.log"));
        assertEquals(5, logs.length);
        assertTrue(Arrays.stream(logs).mapToLong(File::length).sum() <= 500);
        assertTrue(Files.readString(new File(directory, "app.log").toPath()).contains("entry-19"));
        assertTrue(Files.readString(new File(directory, "app.log.4").toPath()).contains("entry-15"));
    }

    @Test public void concurrentWritesAndExportProduceCompleteSnapshot() throws Exception {
        File directory = temp.newFolder();
        RotatingLogStore store = new RotatingLogStore(directory, 5);
        ExecutorService workers = Executors.newFixedThreadPool(4);
        List<Future<?>> tasks = new ArrayList<>();
        for (int i = 0; i < 100; i++) {
            final int id = i;
            tasks.add(workers.submit(() -> {
                try { store.locked(() -> { store.append("entry-" + id, 10000); return null; }); }
                catch (IOException e) { throw new RuntimeException(e); }
            }));
        }
        for (Future<?> task : tasks) task.get();
        workers.shutdown();
        File destination = new File(temp.getRoot(), "logs.zip");
        store.locked(() -> { store.export(destination, "{\"level\":\"INFO\"}"); return null; });
        try (ZipFile zip = new ZipFile(destination)) {
            assertEquals(2, zip.size());
            String contents = new String(zip.getInputStream(zip.getEntry("app.log")).readAllBytes(), StandardCharsets.UTF_8);
            assertEquals(100, contents.lines().distinct().count());
            assertNotNull(zip.getEntry("diagnostics.json"));
        }
    }

    @Test public void trimClearAndOversizedUnicodeEntryStayBounded() throws Exception {
        File directory = temp.newFolder();
        RotatingLogStore store = new RotatingLogStore(directory, 5);
        store.locked(() -> { store.append("ä".repeat(1000), 100); return null; });
        assertTrue(new File(directory, "app.log").length() <= 100);
        store.locked(() -> { store.trim(10); return null; });
        assertFalse(new File(directory, "app.log").exists());
        store.locked(() -> { store.append("new", 100); store.clear(); return null; });
        assertEquals(0, directory.listFiles((dir, name) -> name.startsWith("app.log")).length);
    }
}
