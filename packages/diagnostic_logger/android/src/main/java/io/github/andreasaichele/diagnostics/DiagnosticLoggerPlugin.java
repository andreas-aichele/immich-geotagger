package io.github.andreasaichele.diagnostics;

import android.app.*;
import android.content.*;
import android.os.*;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.*;
import org.json.*;
import java.io.*;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.concurrent.*;

/** Registered automatically in every Flutter engine, including libre_location's
 * headless engine. Only this native writer owns and rotates the five files. */
public final class DiagnosticLoggerPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private static final ExecutorService worker = Executors.newSingleThreadExecutor();
    private static final Handler main = new Handler(Looper.getMainLooper());
    private static RotatingLogStore store;
    private static Context app;
    private static boolean initialized;
    private MethodChannel channel;
    private static final List<String> LEVELS = Arrays.asList("ERROR", "WARN", "INFO", "DEBUG", "TRACE");

    public static synchronized void initialize(Context context) {
        if (initialized) return;
        app = context.getApplicationContext();
        store = new RotatingLogStore(new File(app.getNoBackupFilesDir(), "diagnostic-logs"), 5);
        initialized = true;
        Thread.UncaughtExceptionHandler previous = Thread.getDefaultUncaughtExceptionHandler();
        Thread.setDefaultUncaughtExceptionHandler((thread, error) -> {
            // Write synchronously before Android terminates us. Preserve Android's handler.
            try { write("ERROR", "android", "Uncaught " + error.getClass().getName() + "\n" + safeStack(error)); }
            catch (Exception ignored) { }
            finally { if (previous != null) previous.uncaughtException(thread, error); }
        });
        worker.execute(() -> {
            try {
                write("INFO", "android", "Process started");
                if (Build.VERSION.SDK_INT >= 30) {
                    ActivityManager manager = (ActivityManager) app.getSystemService(Context.ACTIVITY_SERVICE);
                    long last = prefs().getLong("lastExit", 0);
                    long newest = last;
                    for (ApplicationExitInfo exit : manager.getHistoricalProcessExitReasons(app.getPackageName(), 0, 8)) {
                        if (exit.getTimestamp() > last) {
                            write("WARN", "android", "Previous process exit: timestamp=" + exit.getTimestamp()
                                + " reason=" + exit.getReason() + " status=" + exit.getStatus()
                                + " importance=" + exit.getImportance());
                            newest = Math.max(newest, exit.getTimestamp());
                        }
                    }
                    prefs().edit().putLong("lastExit", newest).commit();
                }
            } catch (Exception ignored) { }
        });
    }
    private static SharedPreferences prefs() { return app.getSharedPreferences("diagnostic_logging", Context.MODE_PRIVATE); }
    private static long fileLimit() { return prefs().getInt("sizeMb", 10) * 1024L * 1024L / 5; }
    private static String safeStack(Throwable error) {
        StringBuilder result = new StringBuilder();
        // Exception messages and causes may contain API bodies, keys or metadata.
        for (StackTraceElement frame : error.getStackTrace()) result.append(frame).append('\n');
        return result.toString();
    }
    private static void write(String level, String source, String message) throws IOException {
        store.locked(() -> {
            if (!prefs().getBoolean("enabled", true)) return null;
            int priority = LEVELS.indexOf(level);
            int threshold = LEVELS.indexOf(prefs().getString("level", "INFO"));
            if (priority < 0 || priority > threshold) return null;
            String stamp = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.ROOT) {{ setTimeZone(TimeZone.getTimeZone("UTC")); }}.format(new Date());
            String safe = LogSanitizer.sanitize(message);
            // Persist the warning before a coordinate-bearing record reaches disk.
            if (level.equals("TRACE") && !prefs().getBoolean("containsTrace", false)
                && !prefs().edit().putBoolean("containsTrace", true).commit()) {
                throw new IOException("TRACE marker could not be saved");
            }
            store.append(stamp + " " + level + " [" + LogSanitizer.sanitize(source) + "] " + safe, fileLimit());
            return null;
        });
    }
    public static void lifecycle(String event) {
        worker.execute(() -> { try { write("INFO", "android", event); } catch (Exception ignored) { } });
    }
    @Override public void onAttachedToEngine(FlutterPluginBinding binding) {
        initialize(binding.getApplicationContext());
        channel = new MethodChannel(binding.getBinaryMessenger(), "immich_geotagger/diagnostics");
        channel.setMethodCallHandler(this);
    }
    @Override public void onDetachedFromEngine(FlutterPluginBinding binding) { channel.setMethodCallHandler(null); }
    private static Map<String, Object> configuration() {
        Map<String, Object> config = new HashMap<>();
        config.put("enabled", prefs().getBoolean("enabled", true));
        config.put("level", prefs().getString("level", "INFO"));
        config.put("sizeMb", prefs().getInt("sizeMb", 10));
        config.put("developerMode", prefs().getBoolean("developerMode", false));
        config.put("containsTrace", prefs().getBoolean("containsTrace", false));
        return config;
    }
    @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        worker.execute(() -> {
            try {
                Object value;
                switch (call.method) {
                    case "write":
                        write(call.argument("level"), call.argument("source"), call.argument("message"));
                        value = null; break;
                    case "configuration": value = configuration(); break;
                    case "configure":
                        value = store.locked(() -> {
                            SharedPreferences.Editor edit = prefs().edit();
                            Boolean enabled = call.argument("enabled");
                            String level = call.argument("level");
                            Integer size = call.argument("sizeMb");
                            Boolean developer = call.argument("developerMode");
                            if (enabled != null) edit.putBoolean("enabled", enabled);
                            if (level != null) {
                                if (!LEVELS.contains(level)) throw new IOException("Invalid log level");
                                edit.putString("level", level);
                            }
                            if (size != null) {
                                if (size != 5 && size != 10 && size != 20) throw new IOException("Invalid log size");
                                edit.putInt("sizeMb", size);
                            }
                            if (developer != null) edit.putBoolean("developerMode", developer);
                            if (!edit.commit()) throw new IOException("Settings could not be saved");
                            store.trim(fileLimit());
                            return configuration();
                        }); break;
                    case "clear":
                        store.locked(() -> { store.clear(); prefs().edit().putBoolean("containsTrace", false).commit(); return null; });
                        File[] exports = new File(app.getCacheDir(), "log-exports").listFiles();
                        if (exports != null) for (File old : exports) old.delete();
                        value = null; break;
                    case "export":
                        value = store.locked(() -> {
                            File directory = new File(app.getCacheDir(), "log-exports");
                            directory.mkdirs();
                            // Keep at most one previous export for consumers of the share sheet.
                            File[] oldFiles = directory.listFiles();
                            if (oldFiles != null) for (File old : oldFiles) old.delete();
                            File target = new File(directory, "immich-geotagger-logs-" + System.currentTimeMillis() + ".zip");
                            JSONObject diagnostics = new JSONObject(configuration());
                            try {
                                android.content.pm.PackageInfo info = app.getPackageManager().getPackageInfo(app.getPackageName(), 0);
                                diagnostics.put("appVersion", info.versionName);
                                diagnostics.put("buildNumber", Build.VERSION.SDK_INT >= 28 ? info.getLongVersionCode() : info.versionCode);
                                diagnostics.put("androidVersion", Build.VERSION.RELEASE);
                                diagnostics.put("androidSdk", Build.VERSION.SDK_INT);
                                diagnostics.put("exportedAtUtc", System.currentTimeMillis());
                                PowerManager power = (PowerManager) app.getSystemService(Context.POWER_SERVICE);
                                diagnostics.put("powerSaveMode", power.isPowerSaveMode());
                                diagnostics.put("batteryOptimizationIgnored", power.isIgnoringBatteryOptimizations(app.getPackageName()));
                                diagnostics.put("locationPermission", app.checkSelfPermission("android.permission.ACCESS_FINE_LOCATION") == android.content.pm.PackageManager.PERMISSION_GRANTED);
                                diagnostics.put("mayContainCoordinates", prefs().getBoolean("containsTrace", false));
                            } catch (Exception ignored) { }
                            try { store.export(target, diagnostics.toString(2)); }
                            catch (Exception error) { target.delete(); throw new IOException("Export failed", error); }
                            return target.getAbsolutePath();
                        }); break;
                    default: main.post(result::notImplemented); return;
                }
                final Object response = value;
                main.post(() -> result.success(response));
            } catch (Exception error) {
                main.post(() -> result.error("diagnostics_failed", "Diagnostic operation failed", null));
            }
        });
    }
}
