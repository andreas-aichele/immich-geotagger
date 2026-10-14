# Application diagnostics (Android)

Logging is active at INFO by default. In Settings → About the app, tap the
build number seven times (no more than three seconds between taps) to reveal
Developer options. The unlocked state survives restarts. Hiding the options
restores enabled INFO logging.

Options: enable/disable logging, ERROR/WARN/INFO/DEBUG/TRACE, total log storage
of 5/10/20 MiB (10 by default), share a ZIP, save a ZIP, and delete logs.
Changing to a smaller budget immediately removes oversized retained files.
Deletion also removes temporary ZIP exports. Logging continues afterwards.

The Android plugin is registered in both the UI engine and libre_location's
headless engine. A single native worker writes five files, each limited to
one fifth of the text-log allocation. Text logs use 80% of the selected total;
20% is reserved for up to two system crash reports and a 16 KiB exit summary.
At the 10 MiB default this is about 8 MiB of text and 2 MiB of crash diagnostics. A synchronized store
and OS file lock cover writing, rotation, configuration, deletion and snapshot
export. Each write closes and syncs the file. Logs live in private no-backup
storage, survive app restarts, and disappear on uninstall or clearing app data.
The ZIP contains app.log, up to four rotated files, diagnostics.json, and
process-exits.json when Android exit information has been collected.
All sources share these files and have app/flutter/tracking/immich/sync/android
labels. No external logging service is used.

INFO includes startup, tracking start/stop, synchronization counts and native
memory pressure. WARN includes API failures and available previous process exit
reason codes on Android 11+. DEBUG includes GPS accuracy, API latency/status
and unmatched-photo reasons. TRACE adds GPS coordinates and timestamps.
Flutter framework and uncaught asynchronous errors, handled tracking/sync
failures, and native Java/Kotlin uncaught exceptions record their type and
stack frames. Exception messages, causes, API bodies, asset IDs and EXIF are
excluded. Native redaction also strips URLs and common credential fields.
Export metadata includes app/build/Android versions, logging settings, battery
mode and location permission. The ordinary structured metadata excludes connection credentials and device IDs.

TRACE requires confirmation. A persisted flag marks potentially sensitive logs
until deletion, even after switching back to INFO; exporting then shows a
coordinate warning. Available raw crash reports require a separate choice at
export: “Logs only” or “Include reports”. System reports can contain file paths,
device details and sensitive memory, including credentials or locations. The
ordinary export never attaches them automatically. Reports remain private until
that explicit choice. Review a ZIP before sending it to someone else. Files are
shared only after the user explicitly selects an export action.

## Limitations

An abrupt kill, native signal crash, ANR or loss of power can prevent a final
entry. The next start records available Android exit information (reason,
status, importance, timestamp, sampled memory), plus available ANR traces on
Android 11+ and native tombstone protobufs on Android 12+. The two newest reports
are retained; missing reports are retried on later launches. Oversized reports
are skipped completely rather than exporting invalid truncated protobufs.
Unavailable/oversized/expired reports are identified in process-exits.json.
Deleting logs also deletes raw reports and their metadata, and records a cutoff
so previous Android history is not imported again. The existing
platform error handlers are preserved. Plugin-internal GPS provider decisions
are not captured by this logger; the app records callbacks, permissions,
capture failures and tracking operations at its own integration boundary.
Diagnostic logging is Android-only for now. Other platforms keep working with
no-op logging and do not show the diagnostic controls. The log viewer is deferred.

## Validation

`flutter analyze` and `flutter test` cover Dart integration and the bridge.
`flutter build apk --debug` checks Android registration and compilation.
`cd android && ./gradlew :diagnostic_logger:testDebugUnitTest` checks rotation,
byte limits, concurrent writes, snapshot ZIP contents, shrinking and deletion.
These checks also run in Flutter CI. Device checks should cover UI and headless
tracking, killing/reopening the app, seven-tap unlock persistence, TRACE
confirmation, sharing/saving, and deletion while tracking.

## Cold service restart

GeotaggerApplication completes FlutterLoader initialization on the main thread
before Android creates services or receivers. This works around libre_location
0.4.3 looking up Flutter callback information before loading the native runtime
when restarted without an Activity.

The Dart dispatcher installs libre_location/headless before sending initialized.
It handles onLocationUpdate and the nested position in onHeartbeat. A boot-only
heartbeat is acknowledged without inserting a location. Method replies wait
for location persistence; the plugin then decrements its in-flight counter, so
it cannot destroy the engine while a save is still running. Failures return an
error reply, are logged, and do not prevent later events from being handled.

A real-device test remains necessary: start tracking, background the UI, induce
a process crash using adb shell am crash io.github.andreasaichele.immichgeotagger,
and wait for Android's foreground-service restart/backoff. Do not use Force stop;
that intentionally inhibits automatic restart. Check logs for process startup,
Flutter runtime readiness, headless dispatcher readiness and fresh saved points
before opening the UI. A shell-induced Java crash is not a reproduction of the
original native SIGABRT; native-crash recovery still needs device verification.
