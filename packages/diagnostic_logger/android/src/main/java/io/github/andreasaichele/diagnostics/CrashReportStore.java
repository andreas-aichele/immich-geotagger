package io.github.andreasaichele.diagnostics;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.zip.*;

/** Private, bounded raw system reports. Caller holds RotatingLogStore.locked().
 * Raw reports are never merged into app.log and require explicit export consent. */
final class CrashReportStore {
    static final int COUNT = 2;
    static final int SUMMARY_LIMIT = 16 * 1024;
    private final File directory;

    CrashReportStore(File directory) { this.directory = directory; }

    private List<File> files() {
        File[] found = directory.listFiles((dir, name) -> name.matches("exit-[0-9]+\\.(pb|txt)"));
        List<File> result = new ArrayList<>();
        if (found != null) Collections.addAll(result, found);
        result.sort(Comparator.comparingLong(CrashReportStore::timestamp).reversed());
        return result;
    }
    private static long timestamp(File file) {
        String name = file.getName();
        return Long.parseLong(name.substring(5, name.indexOf('.')));
    }
    File report(long timestamp) {
        for (File file : files()) if (timestamp(file) == timestamp) return file;
        return null;
    }
    int count() { return files().size(); }
    void trim(long perReportLimit) throws IOException {
        int kept = 0;
        for (File file : files()) {
            if (file.length() == 0 || file.length() > perReportLimit || kept >= COUNT) remove(file);
            else kept++;
        }
        File[] pending = directory.listFiles((dir, name) -> name.startsWith("exit-") && name.endsWith(".tmp"));
        if (pending != null) for (File file : pending) remove(file);
    }
    String save(long timestamp, boolean nativeCrash, InputStream input, long limit) throws IOException {
        if (report(timestamp) != null) return "saved";
        if (input == null) return "unavailable";
        String extension = nativeCrash ? ".pb" : ".txt";
        File target = new File(directory, "exit-" + timestamp + extension);
        File pending = new File(directory, target.getName() + ".tmp");
        long size = 0;
        try {
            try (FileOutputStream out = new FileOutputStream(pending)) {
                byte[] buffer = new byte[8192];
                int read;
                while ((read = input.read(buffer)) != -1) {
                    size += read;
                    if (size > limit) return "too_large";
                    out.write(buffer, 0, read);
                }
                out.getFD().sync();
            }
            if (size == 0) return "unavailable";
            if (!pending.renameTo(target)) throw new IOException("Could not save crash report");
            trim(limit);
            return target.exists() ? "saved" : "not_retained";
        } finally { remove(pending); }
    }
    void summary(String json) throws IOException {
        byte[] bytes = json.getBytes(StandardCharsets.UTF_8);
        if (bytes.length > SUMMARY_LIMIT) throw new IOException("Exit summary exceeded limit");
        try (FileOutputStream out = new FileOutputStream(new File(directory, "process-exits.json"))) {
            out.write(bytes);
            out.getFD().sync();
        }
    }
    void clear() throws IOException {
        for (File file : files()) remove(file);
        remove(new File(directory, "process-exits.json"));
        File[] pending = directory.listFiles((dir, name) -> name.startsWith("exit-") && name.endsWith(".tmp"));
        if (pending != null) for (File file : pending) remove(file);
    }
    void export(ZipOutputStream zip, boolean includeRaw) throws IOException {
        File summary = new File(directory, "process-exits.json");
        if (summary.exists()) add(zip, summary, "process-exits.json");
        if (includeRaw) for (File file : files()) add(zip, file, "crash-reports/" + file.getName());
    }
    private static void add(ZipOutputStream zip, File file, String name) throws IOException {
        zip.putNextEntry(new ZipEntry(name));
        try (FileInputStream input = new FileInputStream(file)) {
            byte[] buffer = new byte[8192];
            int read;
            while ((read = input.read(buffer)) != -1) zip.write(buffer, 0, read);
        }
        zip.closeEntry();
    }
    private static void remove(File file) throws IOException {
        if (file.exists() && !file.delete()) throw new IOException("Could not remove crash report");
    }
}
