package io.github.andreasaichele.diagnostics;

import java.io.*;
import java.nio.channels.FileLock;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.zip.*;

/** All writers, clear, configuration changes and exports share the same lock.
 * The OS lock also protects a future service running in a separate process. */
public final class RotatingLogStore {
    private final File directory;
    private final int count;
    public RotatingLogStore(File directory, int count) {
        this.directory = directory;
        this.count = count;
    }
    private File file(int index) {
        return new File(directory, index == 0 ? "app.log" : "app.log." + index);
    }
    public interface Operation<T> { T run() throws IOException; }
    public synchronized <T> T locked(Operation<T> operation) throws IOException {
        if (!directory.isDirectory() && !directory.mkdirs()) throw new IOException("Log directory unavailable");
        try (RandomAccessFile lock = new RandomAccessFile(new File(directory, ".lock"), "rw");
             FileLock held = lock.getChannel().lock()) {
            return operation.run();
        }
    }
    // Caller holds locked(). Limit is in bytes, including the current file.
    public void append(String line, long limit) throws IOException {
        byte[] bytes = (line + "\n").getBytes(StandardCharsets.UTF_8);
        if (bytes.length > limit) {
            // Do not split multibyte characters or retain unbounded exception data.
            bytes = "Log entry exceeded file limit\n".getBytes(StandardCharsets.UTF_8);
        }
        trim(limit);
        if (file(0).length() + bytes.length > limit) rotate();
        try (FileOutputStream output = new FileOutputStream(file(0), true)) {
            output.write(bytes);
            output.getFD().sync();
        }
    }
    public void trim(long limit) throws IOException {
        for (int i = 0; i < count; i++) if (file(i).length() > limit) delete(file(i));
    }
    private void rotate() throws IOException {
        delete(file(count - 1));
        for (int i = count - 2; i >= 0; i--) {
            if (file(i).exists() && !file(i).renameTo(file(i + 1))) throw new IOException("Log rotation failed");
        }
    }
    public void clear() throws IOException {
        for (int i = 0; i < count; i++) delete(file(i));
    }
    private void delete(File file) throws IOException {
        if (file.exists() && !file.delete()) throw new IOException("Log removal failed");
    }
    public void export(File destination, String diagnostics) throws IOException {
        try (ZipOutputStream zip = new ZipOutputStream(new FileOutputStream(destination))) {
            for (int i = 0; i < count; i++) {
                File source = file(i);
                if (!source.exists()) continue;
                zip.putNextEntry(new ZipEntry(source.getName()));
                try (FileInputStream input = new FileInputStream(source)) {
                    byte[] buffer = new byte[8192];
                    int read;
                    while ((read = input.read(buffer)) != -1) zip.write(buffer, 0, read);
                }
                zip.closeEntry();
            }
            zip.putNextEntry(new ZipEntry("diagnostics.json"));
            zip.write(diagnostics.getBytes(StandardCharsets.UTF_8));
            zip.closeEntry();
        }
    }
}
